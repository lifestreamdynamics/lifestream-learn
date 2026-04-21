import { redis } from '@/config/redis';
import { env } from '@/config/env';

// Refresh-token rotation store. On every successful refresh the old
// token's `jti` is written here with a TTL that outlives the refresh
// token itself, so a stolen-but-not-yet-expired refresh token can't be
// replayed after the legitimate user has already rotated it. Uses
// `SET NX` to make the revoke operation atomic — the first caller wins
// and subsequent replays fail, including under concurrent requests.
//
// The Redis client has `keyPrefix: 'learn:'` so the full key is
// `learn:refresh-revoked:<jti>`.

const PREFIX = 'refresh-revoked:';

// Parse JWT_REFRESH_TTL (e.g. "30d", "12h", "3600s") into seconds.
// Supports d/h/m/s suffixes and bare integers. Falls back to 30 days
// if the env value is malformed, which matches the historical default
// and errs on the side of "keep the revocation longer than we need to"
// rather than "let revocation expire early".
function parseRefreshTtlSeconds(ttl: string): number {
  const match = /^(\d+)([smhd])?$/.exec(ttl.trim());
  if (!match) return 30 * 24 * 60 * 60;
  const n = Number(match[1]);
  const unit = match[2] ?? 's';
  const multiplier = unit === 'd' ? 86400 : unit === 'h' ? 3600 : unit === 'm' ? 60 : 1;
  return n * multiplier;
}

// The TTL is sampled once at import time. JWT_REFRESH_TTL is a config
// constant for the process lifetime; changing it requires a restart,
// which is when the store re-reads env anyway.
const TTL_SECONDS = parseRefreshTtlSeconds(env.JWT_REFRESH_TTL);

/**
 * Atomically mark `jti` as revoked. Returns `true` if this call
 * performed the revocation (first-writer-wins), `false` if the jti
 * was already present in the store. Callers MUST gate further action
 * (like issuing a new token pair) on the `true` return — if multiple
 * concurrent requests race the same token, only one gets `true`.
 */
export async function tryRevokeRefreshJti(jti: string): Promise<boolean> {
  const result = await redis.set(`${PREFIX}${jti}`, '1', 'EX', TTL_SECONDS, 'NX');
  return result === 'OK';
}

// Exported for tests only — confirms a jti is in the revocation set.
// Production code should use `tryRevokeRefreshJti` and branch on its
// return value; a separate `isRevoked → revoke` sequence is racy.
export async function isRefreshJtiRevoked(jti: string): Promise<boolean> {
  const hit = await redis.get(`${PREFIX}${jti}`);
  return hit !== null;
}

// Exported for tests only. Lets unit tests inspect the TTL math
// without importing env directly.
export const _testing = { parseRefreshTtlSeconds };
