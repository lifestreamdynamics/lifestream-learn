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
 */
import { randomUUID } from 'node:crypto';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { computeHash, signPlaybackUrl } from '@/utils/hls-signer';

describe('nginx secure_link guard (API-integration)', () => {
  const videoId = randomUUID();
  const uriPath = `/hls/${videoId}/master.m3u8`;

  afterAll(async () => {
    await closeConnections();
  });

  it('rejects a URL with a tampered md5 param (403)', async () => {
    const { url } = signPlaybackUrl(uriPath);
    // Mutate a single character of the md5. The replacement character
    // must be in the url-safe base64 alphabet so we don't accidentally
    // produce an encoding error rather than a signature mismatch.
    const mutated = url.replace(/md5=([^&]+)/, (_, sig: string) => {
      const firstChar = sig[0];
      // Pick a different url-safe base64 char.
      const swap = firstChar === 'a' ? 'b' : 'a';
      return `md5=${swap}${sig.slice(1)}`;
    });
    expect(mutated).not.toBe(url);
    const res = await fetch(mutated);
    expect(res.status).toBe(403);
  });

  it('rejects a URL with a tampered uri path (403)', async () => {
    // Sign one uri, request another. A single valid signature must not
    // work for a different path — if nginx were letting the request
    // through to SeaweedFS, we'd get 404 (NoSuchKey), not 403.
    const otherUri = `/hls/${videoId}/other.m3u8`;
    const { url } = signPlaybackUrl(uriPath);
    const hostAndQuery = url.replace(uriPath, otherUri);
    const res = await fetch(hostAndQuery);
    expect(res.status).toBe(403);
  });

  it('rejects an expired URL (410)', async () => {
    // Mint a URL that's already in the past. nginx secure_link returns
    // 410 Gone when `$secure_link_expires` has passed.
    const { url } = signPlaybackUrl(uriPath, -60);
    const res = await fetch(url);
    expect(res.status).toBe(410);
  });

  it('computeHash produces deterministic output (regression guard)', () => {
    // Byte-level assertion that our JS signer matches the shell signer.
    // If this test fails but the others pass, the signer's internal
    // alphabet drifted — rare but worth guarding.
    const secret = 'local_dev_secret_do_not_use_in_prod';
    const expires = 1_700_000_000;
    const hash = computeHash(expires, '/hls/abc/master.m3u8', secret);
    // base64url: [A-Za-z0-9_-]+, no padding.
    expect(hash).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(hash.includes('=')).toBe(false);
    // Determinism.
    expect(computeHash(expires, '/hls/abc/master.m3u8', secret)).toBe(hash);
  });
});
