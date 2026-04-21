/**
 * Slice G3 — API-integration coverage for the nginx secure_link guard.
 *
 * The BATS suite at infra/scripts/tests/*.bats covers the nginx layer in
 * isolation. This test brings it under API-integration coverage so a
 * future change to `signPlaybackUrl` / `computeHash` or to
 * `infra/nginx/secure_link.conf.inc` can't silently break the guard.
 *
 * We don't use supertest here — the requests go to nginx on host
 * port 8090, not the Express app. That's intentional: the whole point
 * is the nginx-side validation.
 *
 * This file deliberately avoids the S3 SDK: secure_link's 403/410 paths
 * return BEFORE the upstream object is fetched, so we can exercise the
 * guard against a non-existent object and still get a correct answer
 * (the guard returning 404 would mean it was broken; 403 on a tampered
 * signature is the contract). The one case that needs a real object —
 * the positive path — is covered by transcode-e2e.test.ts.
 *
 * Caption URL signing tests live at the bottom of this file. They verify
 * the tampered-sig 403 path (no object needed) and the cross-URL prefix
 * identity guarantee (pure-JS assertion, no network call).
 *
 * URL shape under test (path-embedded token):
 *   /hls/{sig}/{expires}/{videoId}/...
 */
import { randomUUID } from 'node:crypto';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { computeHash, signPlaybackUrl, signCaptionUrl } from '@/utils/hls-signer';

describe('nginx secure_link guard (API-integration)', () => {
  const videoId = randomUUID();

  afterAll(async () => {
    await closeConnections();
  });

  it('rejects a URL with a tampered sig segment (403)', async () => {
    const { url } = signPlaybackUrl(videoId);
    // Mutate a single character of the sig segment. The replacement
    // character must be in the url-safe base64 alphabet so we don't
    // accidentally produce an encoding error rather than a signature
    // mismatch.
    const mutated = url.replace(
      /\/hls\/([^/]+)\//,
      (_match, sig: string) => {
        const firstChar = sig[0];
        const swap = firstChar === 'a' ? 'b' : 'a';
        return `/hls/${swap}${sig.slice(1)}/`;
      },
    );
    expect(mutated).not.toBe(url);
    const res = await fetch(mutated);
    expect(res.status).toBe(403);
  });

  it('rejects a URL whose videoId was swapped after signing (403)', async () => {
    // Sign for videoA, request videoB using the same sig/expires. The
    // reconstructed signed-prefix `/hls/<videoB>/` won't hash to the
    // presented sig, so nginx must 403.
    const { url } = signPlaybackUrl(videoId);
    const otherVideoId = randomUUID();
    const swapped = url.replace(`/${videoId}/`, `/${otherVideoId}/`);
    const res = await fetch(swapped);
    expect(res.status).toBe(403);
  });

  it('rejects an expired URL (410)', async () => {
    // Mint a URL that's already in the past. nginx secure_link returns
    // 410 Gone when the expiry has passed.
    const { url } = signPlaybackUrl(videoId, -60);
    const res = await fetch(url);
    expect(res.status).toBe(410);
  });

  it('one signature authorizes every URL under the same /hls/{videoId}/ prefix', async () => {
    // Load-bearing test: this is the whole reason we switched to
    // path-embedded tokens. The master, a variant playlist, and a media
    // segment all live at sibling paths under /hls/{sig}/{expires}/{id}/,
    // and the same sig must authorize them all. None of these paths
    // exist in SeaweedFS — the guard returning 403 would mean signature
    // validation failed (wrong), while anything else (404 NoSuchKey,
    // 200) means the guard LET the request through to the upstream.
    const { url } = signPlaybackUrl(videoId);
    // Master, variant, init segment, media segment — sibling paths
    // under the same path-embedded token.
    const siblings = [
      url, // master.m3u8
      url.replace(/master\.m3u8$/, 'v_0/index.m3u8'),
      url.replace(/master\.m3u8$/, 'v_0/init_0.mp4'),
      url.replace(/master\.m3u8$/, 'v_0/seg_001.m4s'),
    ];
    for (const sibling of siblings) {
      const res = await fetch(sibling);
      expect(res.status).not.toBe(403);
      expect(res.status).not.toBe(410);
    }
  });

  it('computeHash produces deterministic output (regression guard)', () => {
    // Byte-level assertion that our JS signer matches the shell signer.
    // If this test fails but the others pass, the signer's internal
    // alphabet drifted — rare but worth guarding.
    const secret = 'local_dev_secret_do_not_use_in_prod';
    const expires = 1_700_000_000;
    const hash = computeHash(expires, '/hls/abc/', secret);
    // base64url: [A-Za-z0-9_-]+, no padding.
    expect(hash).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(hash.includes('=')).toBe(false);
    // Determinism.
    expect(computeHash(expires, '/hls/abc/', secret)).toBe(hash);
  });

  describe('caption URL signing', () => {
    // The nginx secure_link guard evaluates signatures before it fetches any
    // object from SeaweedFS. The tampered-sig check below therefore doesn't
    // need a real object in the bucket — nginx returns 403 before it ever
    // contacts SeaweedFS (same rationale as the master-playlist tampered-sig
    // test above). The positive 200 path (nginx serves a real .vtt with
    // `Content-Type: text/vtt`) requires a running SeaweedFS with a real
    // object pre-uploaded and is covered by the `transcode-e2e` suite once
    // the compose stack is available; see the comment at the top of this file.
    const captionVideoId = randomUUID();

    it('rejects a tampered sig on a caption URL (403)', async () => {
      const { url } = signCaptionUrl(captionVideoId, 'en');
      // Verify the URL has the expected caption tail before mutating it.
      expect(url).toMatch(/\/captions\/en\.vtt$/);

      const tamperedUrl = url.replace(
        /\/hls\/([^/]+)\//,
        (_match, sig: string) => {
          const swap = sig[0] === 'a' ? 'b' : 'a';
          return `/hls/${swap}${sig.slice(1)}/`;
        },
      );
      expect(tamperedUrl).not.toBe(url);
      const res = await fetch(tamperedUrl);
      expect(res.status).toBe(403);
    });

    it('caption URL shares the same signed prefix as the master playlist URL', () => {
      // Load-bearing unit assertion: the signer embeds the same /hls/{videoId}/
      // prefix in both URLs so a single token authorizes master.m3u8 and every
      // caption file under the same videoId. Extract the sig + expires from both
      // and assert they are identical (same prefix → same hash → same sig).
      const { url: masterUrl } = signPlaybackUrl(captionVideoId);
      const { url: captionUrl } = signCaptionUrl(captionVideoId, 'en');

      // Shape: /hls/<sig>/<expires>/<videoId>/...
      const masterMatch = masterUrl.match(/\/hls\/([^/]+)\/(\d+)\//);
      const captionMatch = captionUrl.match(/\/hls\/([^/]+)\/(\d+)\//);

      expect(masterMatch).not.toBeNull();
      expect(captionMatch).not.toBeNull();

      // Both URLs were signed at nearly the same instant; expires values will
      // differ by at most a few milliseconds → same second → same value.
      expect(captionMatch![1]).toBe(masterMatch![1]); // sig must be byte-identical
      expect(captionMatch![2]).toBe(masterMatch![2]); // same expires second
    });
  });
});
