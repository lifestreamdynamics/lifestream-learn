import '@tests/unit/setup';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { computeHash, signPlaybackUrl } from '@/utils/hls-signer';

const SCRIPT = path.resolve(__dirname, '..', '..', '..', '..', 'infra/scripts/sign-hls-url.sh');

describe('hls-signer', () => {
  describe('computeHash — byte-exact match to infra/scripts/sign-hls-url.sh', () => {
    const cases = [
      { videoId: 'abc', expires: 1700000000, secret: 'test_secret_do_not_use' },
      { videoId: 'xyz', expires: 1700003600, secret: 'other_secret_value_123' },
      { videoId: 'd1', expires: 2000000000, secret: 'long_shared_secret_123456789' },
    ];

    for (const { videoId, expires, secret } of cases) {
      it(`matches bash for videoId=${videoId}`, () => {
        // The bash signer takes the raw videoId plus a TTL; to pin
        // `expires` deterministically we pass TTL=0 and NOW_OVERRIDE=expires.
        const bashOut = execFileSync(SCRIPT, [videoId, '0'], {
          encoding: 'utf8',
          env: { ...process.env, SECURE_LINK_SECRET: secret, NOW_OVERRIDE: String(expires) },
        }).trim();

        // Shape: /hls/<sig>/<expires>/<videoId>/master.m3u8
        const m = bashOut.match(
          /^\/hls\/([A-Za-z0-9_-]+)\/(\d+)\/([^/]+)\/master\.m3u8$/,
        );
        expect(m).not.toBeNull();
        const [, bashSig, bashExpires, bashVideoId] = m!;

        expect(Number(bashExpires)).toBe(expires);
        expect(bashVideoId).toBe(videoId);
        // The JS signer computes the hash over the logical prefix
        // `/hls/<videoId>/` (trailing slash), which is what nginx
        // reconstructs and validates against.
        expect(computeHash(expires, `/hls/${videoId}/`, secret)).toBe(bashSig);
      });
    }
  });

  describe('signPlaybackUrl', () => {
    it('produces a URL with path-embedded sig + expires', () => {
      const { url, expiresAt } = signPlaybackUrl('abc', 60);
      expect(url).toMatch(
        /^http:\/\/[^/]+\/hls\/[A-Za-z0-9_-]+\/\d+\/abc\/master\.m3u8$/,
      );
      expect(url).not.toContain('?');
      expect(expiresAt).toBeInstanceOf(Date);
      const now = Math.floor(Date.now() / 1000);
      const expiresSec = Math.floor(expiresAt.getTime() / 1000);
      expect(expiresSec - now).toBeGreaterThanOrEqual(59);
      expect(expiresSec - now).toBeLessThanOrEqual(61);
    });

    it('the path-captured {expires} matches the returned expiresAt', () => {
      // Regression guard: the nginx regex captures {expires} from the path
      // and re-computes the hash using it. If the URL and `expiresAt` ever
      // drift, signatures will validate on the JS side and fail on the
      // nginx side — a nightmare to debug. Keep them in lockstep.
      const { url, expiresAt } = signPlaybackUrl('abc', 60);
      const pathExpires = Number(url.match(/\/hls\/[^/]+\/(\d+)\//)![1]);
      expect(pathExpires).toBe(Math.floor(expiresAt.getTime() / 1000));
    });

    it('rejects an empty videoId', () => {
      expect(() => signPlaybackUrl('')).toThrow(/non-empty/i);
    });

    it('rejects a videoId containing a slash', () => {
      expect(() => signPlaybackUrl('a/b')).toThrow(/slash/i);
    });

    it('strips a trailing /hls from HLS_BASE_URL to avoid double-prefixing', () => {
      // HLS_BASE_URL in test env is http://localhost:8080/hls; the signer
      // must strip that trailing `/hls` so we don't emit /hls/hls/...
      const { url } = signPlaybackUrl('xyz');
      expect(url).not.toMatch(/\/hls\/hls\//);
      expect(url).toMatch(/\/hls\/[A-Za-z0-9_-]+\/\d+\/xyz\/master\.m3u8$/);
    });

    it('one signature is shared by every URL under the same /hls/{videoId}/ prefix', () => {
      // Documentation test — illustrates the core invariant that makes
      // relative-URL HLS playback work:
      //   sig(prefix="/hls/abc/") = hash(expires, "/hls/abc/", secret)
      // and nginx reconstructs that same prefix from the captured
      // {videoId} on every request. So master, variant, and segment URLs
      // all validate against the same hash.
      const { url } = signPlaybackUrl('abc', 60);
      const captured = url.match(/\/hls\/([A-Za-z0-9_-]+)\/(\d+)\/(abc)\//);
      expect(captured).not.toBeNull();
      const [, sigInPath, expiresInPath, videoIdInPath] = captured!;
      // Rebuild the nginx-side expression and re-hash.
      const rehashed = computeHash(
        Number(expiresInPath),
        `/hls/${videoIdInPath}/`,
        // Mirror the env var the real signer reads from.
        process.env.HLS_SIGNING_SECRET ?? '',
      );
      expect(rehashed).toBe(sigInPath);
    });
  });
});
