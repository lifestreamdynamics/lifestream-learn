import '@tests/unit/setup';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { computeHash, signPlaybackUrl } from '@/utils/hls-signer';

const SCRIPT = path.resolve(__dirname, '..', '..', '..', '..', 'infra/scripts/sign-hls-url.sh');

describe('hls-signer', () => {
  describe('computeHash — byte-exact match to infra/scripts/sign-hls-url.sh', () => {
    const cases = [
      { uri: '/hls/abc/master.m3u8', expires: 1700000000, secret: 'test_secret_do_not_use' },
      { uri: '/hls/xyz/v_0/seg_001.m4s', expires: 1700003600, secret: 'other_secret_value_123' },
      { uri: '/hls/d1/d2/index.m3u8', expires: 2000000000, secret: 'long_shared_secret_123456789' },
    ];

    for (const { uri, expires, secret } of cases) {
      it(`matches bash for uri=${uri}`, () => {
        const bashOut = execFileSync(SCRIPT, [uri, '0'], {
          encoding: 'utf8',
          env: { ...process.env, SECURE_LINK_SECRET: secret, NOW_OVERRIDE: String(expires) },
        }).trim();

        const m = bashOut.match(/\?md5=([^&]+)&expires=(\d+)/);
        expect(m).not.toBeNull();
        const bashMd5 = m![1];
        const bashExpires = Number(m![2]);

        expect(bashExpires).toBe(expires);
        expect(computeHash(expires, uri, secret)).toBe(bashMd5);
      });
    }
  });

  describe('signPlaybackUrl', () => {
    it('produces a URL with md5 and expires query params', () => {
      const { url, expiresAt } = signPlaybackUrl('/hls/abc/master.m3u8', 60);
      expect(url).toMatch(/^http:\/\/[^?]+\?md5=[A-Za-z0-9_-]+&expires=\d+$/);
      expect(expiresAt).toBeInstanceOf(Date);
      const now = Math.floor(Date.now() / 1000);
      const expiresSec = Math.floor(expiresAt.getTime() / 1000);
      expect(expiresSec - now).toBeGreaterThanOrEqual(59);
      expect(expiresSec - now).toBeLessThanOrEqual(61);
    });

    it('rejects a relative path', () => {
      expect(() => signPlaybackUrl('hls/abc/master.m3u8')).toThrow(/absolute/i);
    });

    it('strips a trailing /hls from HLS_BASE_URL to avoid double-prefixing', () => {
      const { url } = signPlaybackUrl('/hls/xyz/master.m3u8');
      // HLS_BASE_URL in test env is http://localhost:8080/hls; should not produce
      // http://localhost:8080/hls/hls/xyz/... (double hls).
      expect(url).not.toMatch(/\/hls\/hls\//);
      expect(url).toMatch(/\/hls\/xyz\/master\.m3u8\?/);
    });
  });
});
