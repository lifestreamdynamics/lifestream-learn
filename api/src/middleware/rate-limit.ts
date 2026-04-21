import type { Request } from 'express';
import rateLimit from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { env } from '@/config/env';
import { redis } from '@/config/redis';

const makeStore = (prefix: string) =>
  new RedisStore({
    prefix,
    // rate-limit-redis v4 expects a variadic (...args: string[]) => Promise<...>
    // that forwards to an ioredis-compatible client. ioredis `call` accepts
    // (command: string, ...args: string[]); we cast to satisfy its overload
    // signature while preserving the rate-limit-redis contract.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    sendCommand: (...args: string[]) => redis.call(...(args as [string, ...string[]])) as Promise<any>,
  });

export const signupLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_SIGNUP_WINDOW_MS,
  limit: env.RATE_LIMIT_SIGNUP_MAX,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:signup:'),
  message: { error: 'RATE_LIMITED', message: 'Too many signup attempts' },
});

export const loginLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_LOGIN_WINDOW_MS,
  limit: env.RATE_LIMIT_LOGIN_MAX,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:login:'),
  message: { error: 'RATE_LIMITED', message: 'Too many login attempts' },
});

export const refreshLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_REFRESH_WINDOW_MS,
  limit: env.RATE_LIMIT_REFRESH_MAX,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:refresh:'),
  message: { error: 'RATE_LIMITED', message: 'Too many refresh attempts' },
});

export const tusdHookLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_TUSD_HOOK_WINDOW_MS,
  limit: env.RATE_LIMIT_TUSD_HOOK_MAX,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:hooks:tusd:'),
  message: { error: 'RATE_LIMITED', message: 'Too many tusd hook deliveries' },
});

/**
 * Slice P5 — per-IP limiter for `POST /api/me/password`. Conservative by
 * design: the endpoint already requires a valid access token AND the
 * current password, but bcrypt-on-every-call makes brute-force cheap to
 * throttle here rather than in the service. Values live inline (not env)
 * because they're a security invariant, not an operator-tunable knob.
 */
export const passwordChangeLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:me:password:'),
  message: {
    error: 'RATE_LIMITED',
    message: 'Too many password-change attempts',
  },
});

/**
 * Slice P5 — per-IP limiter for `DELETE /api/me`. Same reasoning as the
 * password-change limiter. Deletion is the single most destructive API
 * action; a tight cap here is cheap insurance on top of the access-token
 * + password re-verification requirements.
 */
export const deleteAccountLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:me:delete:'),
  message: {
    error: 'RATE_LIMITED',
    message: 'Too many account-deletion attempts',
  },
});

/**
 * Slice P6 — per-IP limiter for `POST /api/auth/logout`. Logout is
 * idempotent and returns 204 even on bogus tokens, so this isn't guarding
 * against credential brute-force; it's preventing a floor-of-a-million
 * garbage POSTs from turning the Postgres session table into a DoS
 * amplifier via the `refreshJti` lookup. Generous cap — a legitimate
 * client logs out maybe once a day; 30/5min absorbs retries without
 * breaking real users.
 */
export const logoutLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:logout:'),
  message: { error: 'RATE_LIMITED', message: 'Too many logout attempts' },
});

/**
 * Slice P7a — MFA enrolment start + confirm. Generous ceilings because
 * a user might abandon + restart enrolment several times; low enough
 * that an automated attacker can't spam start-enrol as a DoS vector
 * against `qrcode.toDataURL` (which is ~10ms of CPU per call).
 */
export const mfaEnrolLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:mfa:enrol:'),
  message: { error: 'RATE_LIMITED', message: 'Too many MFA enrolment attempts' },
});

/**
 * Slice P7a — profile-side MFA verify/disable. Used by the confirm-
 * enrol endpoint and the disable endpoint, both of which are authed.
 * A 5-minute window matches the P5 password-change limiter's cadence
 * while allowing a user to retry a mistyped code a few times.
 */
export const mfaVerifyLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:mfa:verify:'),
  message: { error: 'RATE_LIMITED', message: 'Too many MFA verification attempts' },
});

/**
 * Slice P7a — login-time TOTP step. Deliberately tighter than the
 * normal login limiter: an attacker who has cleared the password gate
 * is one step from full account takeover, so throttling online code
 * guessing here is the last line of defence before the TOTP's own
 * 1-in-1,000,000 odds per window.
 */
export const mfaLoginLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:mfa-login:'),
  message: { error: 'RATE_LIMITED', message: 'Too many MFA login attempts' },
});

/**
 * Slice P7a — backup-code login step. Tightest of all: backup codes
 * are one-use emergency-access tokens, and the legitimate call rate
 * is effectively zero. 5 attempts / 15 min gives an operator-in-
 * distress a couple of retries without handing an attacker a practical
 * brute-force window.
 */
export const mfaBackupLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:mfa-backup:'),
  message: { error: 'RATE_LIMITED', message: 'Too many backup-code attempts' },
});

/**
 * Slice P8 — per-USER limiter for `GET /api/me/export`. Export is a
 * one-shot-per-day operation (GDPR "right of access" is satisfied once
 * every 24h); the purpose here is:
 *   - bound the DB load a single user can impose by fanning out a full
 *     findMany over every major table,
 *   - discourage someone from scripting a polling loop that downloads
 *     their analytics events repeatedly to sidestep the retention cap.
 *
 * Keyed on the authenticated user id, NOT the IP: an attacker with a
 * valid access token from a proxy farm should not be able to amplify
 * throughput by rotating IPs. `authenticate` runs AHEAD of this limiter
 * (see me.routes) so `req.user.id` is populated when the keyGenerator
 * fires; if it isn't, we fall back to the IP so a misconfigured mount
 * order fails loudly with a 429 rather than silently skipping the cap.
 *
 * Window is 24h, limit is 1 — any second call within the window trips
 * 429 with a `Retry-After` header populated by express-rate-limit's
 * standardHeaders (draft-7).
 */
export const exportLimiter = rateLimit({
  windowMs: 24 * 60 * 60 * 1000,
  limit: 1,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:me:export:'),
  // Per-user key. req.user is set by the `authenticate` middleware
  // which runs before this limiter on the route. Fall back to the IP
  // so a missing id still throttles — never returns undefined, which
  // would throw inside rate-limit's store.
  keyGenerator: (req: Request): string => {
    const uid = req.user?.id;
    if (uid) return `u:${uid}`;
    // `ipKeyGenerator` is the recommended fallback per express-rate-limit
    // but `req.ip` is adequate when trust-proxy is configured correctly,
    // and the auth middleware ahead of us guarantees uid presence on the
    // happy path. Empty-string fallback is safe: a single bucket shared
    // across unauthed hits still 429s fast.
    return `ip:${req.ip ?? 'unknown'}`;
  },
  message: {
    error: 'RATE_LIMITED',
    message: 'You can export your data once per 24 hours',
  },
});
