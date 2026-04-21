import { createHash } from 'node:crypto';
import { env } from '@/config/env';
import { getMetrics } from '@/observability/metrics';

/**
 * Byte-exact Node equivalent of `infra/scripts/sign-hls-url.sh` and the
 * `secure_link_md5` directive in `infra/nginx/secure_link.conf.inc`.
 *
 * Signing scheme:
 *   hash = base64url(md5_raw(`${expires}${signedPrefix} ${secret}`))
 *
 * `signedPrefix` is the URL-path PREFIX the token authorizes — always
 * `/hls/<videoId>/` (trailing slash included). One signature covers
 * master playlist + every variant playlist + every segment under that
 * prefix because the token is embedded in the URL path, not the query
 * string — HLS players do NOT propagate the parent URL's query string to
 * child requests (RFC 3986 §5.3; confirmed for FFmpeg libavformat/hls.c
 * and ExoPlayer). See the comment block at the top of `signPlaybackUrl`
 * for the URL shape nginx consumes.
 *
 * `expires` is a unix timestamp (seconds). `secret` must match the value
 * nginx is configured with (`$secure_link_secret`). Hosts must be
 * clock-synced within the TTL margin (~60s).
 *
 * base64url here means standard base64 with `+ → -`, `/ → _`, trailing `=`
 * stripped — the exact transform the bash reference applies.
 */
export function computeHash(expires: number, signedPrefix: string, secret: string): string {
  const input = `${expires}${signedPrefix} ${secret}`;
  const raw = createHash('md5').update(input, 'utf8').digest();
  return raw
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * BCP-47 language tag regex covering the subset we accept for caption files.
 * Accepts:
 *   - 2–3 lowercase alpha language code (ISO 639): `en`, `zh`, `yue`
 *   - Optional 4-letter title-case script subtag: `zh-Hant`, `zh-Hans`
 *   - Optional 2-letter uppercase region or 3-digit region: `en-US`, `zh-CN`, `es-419`
 * Rejects uppercased language codes (`EN`), underscores (`en_US`), or
 * lowercase region codes (`en-us`).
 */
const BCP47_RE = /^[a-z]{2,3}(-[A-Z][a-z]{3})?(-[A-Z]{2}|-[0-9]{3})?$/;

/**
 * Shared private implementation for all three signed-URL helpers.
 *
 * Every helper signs the same prefix `/hls/{videoId}/` so that a single
 * token issued at call time authorises master.m3u8, poster.jpg, and every
 * caption file under that videoId in one round-trip — nginx reconstructs
 * the same prefix from the captured {videoId} on every request, regardless
 * of which tail the client is fetching. This is intentional: don't change
 * the prefix computation without updating the nginx `secure_link` config
 * and all three exported helpers simultaneously.
 */
function _buildSignedUrl(
  videoId: string,
  tail: string,
  ttlSec: number,
): { url: string; expiresAt: Date } {
  const nowSec = Math.floor(Date.now() / 1000);
  const expires = nowSec + ttlSec;
  const signedPrefix = `/hls/${videoId}/`;
  const sig = computeHash(expires, signedPrefix, env.HLS_SIGNING_SECRET);
  const base = env.HLS_BASE_URL.replace(/\/$/, '');
  // `HLS_BASE_URL` may already include a trailing `/hls`; strip it so we
  // don't emit `/hls/hls/...`. Both shapes (`http://host` and
  // `http://host/hls`) were accepted by the previous signer and callers
  // in operator env-files rely on that, so we keep the leniency.
  const origin = base.replace(/\/hls$/, '');
  return {
    url: `${origin}/hls/${sig}/${expires}/${videoId}/${tail}`,
    expiresAt: new Date(expires * 1000),
  };
}

/**
 * Produce a signed master-playlist URL for the given video.
 *
 * The returned URL embeds the signature and expiry in the PATH
 * (not the query string) so every relative URL inside the playlist —
 * variant playlists, init segments, media segments — resolves against a
 * path that still carries the token. That's the only portable way to get
 * one signature to authorize the entire HLS tree on standards-compliant
 * players (fvp, ExoPlayer, hls.js, ffplay, VLC all drop parent query
 * strings on child requests).
 *
 * URL shape:
 *   {origin}/hls/{sig}/{expires}/{videoId}/master.m3u8
 *
 * where `sig` is computed over the prefix `/hls/{videoId}/` so any
 * request whose path begins with `/hls/{sig}/{expires}/{videoId}/`
 * validates against the same hash. Nginx strips the `{sig}/{expires}`
 * prefix via an internal rewrite before `secure_link` runs (see
 * `infra/nginx/local.conf`).
 */
export function signPlaybackUrl(
  videoId: string,
  ttlSec: number = env.HLS_SIGNING_TTL_SECONDS,
): { url: string; expiresAt: Date } {
  if (!videoId || videoId.includes('/')) {
    // Tight guard: we embed the videoId into the URL path without further
    // escaping, so a `/` in the value would let a caller reshape the URL.
    // Treat any slash as a programming error rather than sanitising.
    throw new Error('videoId must be a non-empty slug without slashes');
  }
  getMetrics().playbackSignedUrlsTotal.inc();
  return _buildSignedUrl(videoId, 'master.m3u8', ttlSec);
}

/**
 * Produce a signed URL for a video's poster JPEG. The poster lives at
 * the same prefix the master playlist does (`vod/{videoId}/poster.jpg`)
 * so a single signature authorizes both — the nginx regex at
 * `infra/nginx/local.conf:93` captures any path segment after the video
 * id, so `poster.jpg` validates under the same signed prefix.
 *
 * Returned as its own helper (rather than reusing `signPlaybackUrl`) so
 * callers don't end up generating a playback URL just to edit the tail
 * — and so the TTL can be tuned independently if we ever want longer-
 * lived poster URLs for pre-render caches.
 */
export function signPosterUrl(
  videoId: string,
  ttlSec: number = env.HLS_SIGNING_TTL_SECONDS,
): { url: string; expiresAt: Date } {
  if (!videoId || videoId.includes('/')) {
    throw new Error('videoId must be a non-empty slug without slashes');
  }
  return _buildSignedUrl(videoId, 'poster.jpg', ttlSec);
}

/**
 * Produce a signed URL for a video's WebVTT caption file for the given
 * BCP-47 language tag. The caption lives at `captions/{language}.vtt`
 * under the same `/hls/{videoId}/` prefix so the token issued here is
 * byte-identical to the one in `signPlaybackUrl` / `signPosterUrl` for
 * the same (videoId, expires) pair — one signature authorises master
 * playlist, poster, and all caption tracks simultaneously.
 *
 * URL shape:
 *   {origin}/hls/{sig}/{expires}/{videoId}/captions/{language}.vtt
 *
 * `language` must be a valid BCP-47 subtag (e.g. `en`, `zh-CN`, `pt-BR`,
 * `zh-Hant`). Uppercased language codes (`EN`), underscores (`en_US`), or
 * lowercase region codes (`en-us`) are rejected as programmer errors.
 */
export function signCaptionUrl(
  videoId: string,
  language: string,
  ttlSec: number = env.HLS_SIGNING_TTL_SECONDS,
): { url: string; expiresAt: Date } {
  if (!videoId || videoId.includes('/')) {
    throw new Error('videoId must be a non-empty slug without slashes');
  }
  if (!language || !BCP47_RE.test(language)) {
    throw new Error(
      `language must be a valid BCP-47 tag (e.g. "en", "zh-CN", "pt-BR"); got: "${language}"`,
    );
  }
  return _buildSignedUrl(videoId, `captions/${language}.vtt`, ttlSec);
}
