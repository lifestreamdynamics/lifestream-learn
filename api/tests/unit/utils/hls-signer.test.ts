import '@tests/unit/setup';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { computeHash, signPlaybackUrl, signPosterUrl, signCaptionUrl } from '@/utils/hls-signer';

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

  describe('signPosterUrl', () => {
    it('produces a URL ending in /{videoId}/poster.jpg', () => {
      const { url } = signPosterUrl('abc', 60);
      expect(url).toMatch(/\/hls\/[A-Za-z0-9_-]+\/\d+\/abc\/poster\.jpg$/);
    });

    it('uses the same signature shape as the playback URL (covered by the same prefix)', () => {
      // Both helpers sign prefix=/hls/{videoId}/ with the same secret and
      // TTL, so a request to the poster path validates under the exact
      // same nginx secure_link rule the master playlist uses. This test
      // pins that invariant — if a future refactor diverges the shapes,
      // clients will silently stop getting posters.
      const playback = signPlaybackUrl('abc', 60);
      const poster = signPosterUrl('abc', 60);
      // Both URLs share the same origin and {sig}/{expires}/{videoId}/ prefix.
      const playbackPrefix = playback.url.replace(/master\.m3u8$/, '');
      const posterPrefix = poster.url.replace(/poster\.jpg$/, '');
      expect(playbackPrefix).toBe(posterPrefix);
    });

    it('rejects an empty videoId', () => {
      expect(() => signPosterUrl('')).toThrow(/non-empty/i);
    });

    it('rejects a videoId containing a slash', () => {
      expect(() => signPosterUrl('a/b')).toThrow(/slash/i);
    });
  });

  describe('signCaptionUrl', () => {
    it('produces a URL matching the expected path shape', () => {
      const { url, expiresAt } = signCaptionUrl('abc', 'en', 60);
      expect(url).toMatch(
        /^.+\/hls\/[A-Za-z0-9_-]+\/\d+\/abc\/captions\/en\.vtt$/,
      );
      expect(url).not.toContain('?');
      expect(expiresAt).toBeInstanceOf(Date);
    });

    it('embeds the language subtag in the tail', () => {
      const { url } = signCaptionUrl('vid123', 'zh-CN', 60);
      expect(url).toMatch(/\/captions\/zh-CN\.vtt$/);
    });

    it('all three helpers produce byte-identical sig+expires for the same videoId (frozen clock)', () => {
      // Cross-cutting invariant: a single nginx token issued at login-time
      // must authorise master.m3u8, poster.jpg, AND every caption track
      // because all three share the same signed prefix `/hls/{videoId}/`.
      // If any helper ever uses a different prefix or secret, that helper's
      // URLs will 403 mid-playback without a visible error on the API side.
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2030-01-01T00:00:00.000Z'));
      try {
        const playback = signPlaybackUrl('testvid', 3600);
        const poster = signPosterUrl('testvid', 3600);
        const caption = signCaptionUrl('testvid', 'en', 3600);

        // Extract the {sig}/{expires}/{videoId}/ common prefix from each URL.
        const prefixRe = /\/hls\/([A-Za-z0-9_-]+\/\d+\/testvid\/)/;
        const playbackPrefix = playback.url.match(prefixRe)![1];
        const posterPrefix = poster.url.match(prefixRe)![1];
        const captionPrefix = caption.url.match(prefixRe)![1];

        expect(posterPrefix).toBe(playbackPrefix);
        expect(captionPrefix).toBe(playbackPrefix);

        // expiresAt must also be identical
        expect(poster.expiresAt.getTime()).toBe(playback.expiresAt.getTime());
        expect(caption.expiresAt.getTime()).toBe(playback.expiresAt.getTime());
      } finally {
        jest.useRealTimers();
      }
    });

    it('rejects a videoId containing a slash', () => {
      expect(() => signCaptionUrl('a/b', 'en')).toThrow(/slash/i);
    });

    it('rejects an empty videoId', () => {
      expect(() => signCaptionUrl('', 'en')).toThrow(/non-empty/i);
    });

    describe('BCP-47 language validation — accepted values', () => {
      const valid = ['en', 'zh-CN', 'zh-Hant', 'pt-BR', 'yue', 'es-419'];
      it.each(valid)('accepts %s', (lang) => {
        expect(() => signCaptionUrl('vid', lang, 60)).not.toThrow();
      });
    });

    describe('BCP-47 language validation — rejected values', () => {
      const invalid = [
        ['EN', 'uppercased language code'],
        ['english', 'full word instead of subtag'],
        ['en_US', 'underscore separator'],
        ['en-us', 'lowercase region'],
        ['', 'empty string'],
        ['zh-hant', 'lowercase script'],
        ['zh-CN-extra-junk', 'too many subtags'],
      ];
      it.each(invalid)('rejects %s (%s)', (lang) => {
        expect(() => signCaptionUrl('vid', lang, 60)).toThrow(/BCP-47/i);
      });
    });
  });
});
