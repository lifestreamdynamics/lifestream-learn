import { createHash } from 'node:crypto';
import { env } from '@/config/env';
import { getMetrics } from '@/observability/metrics';

/**
 * Byte-exact Node equivalent of `infra/scripts/sign-hls-url.sh` and the
 * `secure_link_md5` directive in `infra/nginx/secure_link.conf.inc`.
 *
 * Signing scheme:
 *   hash = base64url(md5_raw(`${expires}${uri} ${secret}`))
 *
 * `expires` is a unix timestamp (seconds). `uri` must be an absolute path
 * beginning with `/` (it's what nginx sees as `$uri`). `secret` must match
 * the value nginx is configured with (`$secure_link_secret`).
 *
 * base64url here means standard base64 with `+ → -`, `/ → _`, trailing `=`
 * stripped — the exact transform the bash reference applies.
 *
 * TTL assumption: the signed URL expiry is computed from Node's wall clock
 * and validated by nginx with its own wall clock. Hosts must be clock-synced
 * within the TTL margin (~60s).
 */
export function computeHash(expires: number, uri: string, secret: string): string {
  const input = `${expires}${uri} ${secret}`;
  const raw = createHash('md5').update(input, 'utf8').digest();
  return raw
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * Produce a signed playback URL for the given path under `/hls/...`.
 *
 * @param uriPath  Absolute URI path beginning with `/` (e.g. `/hls/<id>/master.m3u8`).
 *                 This is the value nginx matches against `$uri`, so do NOT include
 *                 the hostname or query string.
 * @param ttlSec   How long the URL stays valid, in seconds. Defaults to the
 *                 operator-configured `HLS_SIGNING_TTL_SECONDS`.
 */
export function signPlaybackUrl(
  uriPath: string,
  ttlSec: number = env.HLS_SIGNING_TTL_SECONDS,
): { url: string; expiresAt: Date } {
  if (!uriPath.startsWith('/')) {
    throw new Error('uriPath must be absolute and start with /');
  }
  const nowSec = Math.floor(Date.now() / 1000);
  const expires = nowSec + ttlSec;
  const md5 = computeHash(expires, uriPath, env.HLS_SIGNING_SECRET);
  const base = env.HLS_BASE_URL.replace(/\/$/, '');
  // HLS_BASE_URL may already include `/hls`; strip it if so to avoid a double
  // prefix, since the signed path starts with `/hls/...`.
  const origin = base.replace(/\/hls$/, '');
  getMetrics().playbackSignedUrlsTotal.inc();
  return {
    url: `${origin}${uriPath}?md5=${md5}&expires=${expires}`,
    expiresAt: new Date(expires * 1000),
  };
}
