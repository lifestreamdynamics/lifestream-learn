import jwt, { JsonWebTokenError, type SignOptions } from 'jsonwebtoken';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import type { Role } from '@prisma/client';
import { env } from '@/config/env';
import { UnauthorizedError } from '@/utils/errors';
import { getMetrics } from '@/observability/metrics';

// JWT audience claim. A token minted for learn-api must not be replayable
// against any sibling service (accounting-api, chatbot-api) if those ever
// share a secret by accident, and vice-versa. Verified strictly on decode.
export const JWT_AUDIENCE = 'learn-api';

// Zod schemas for decoded claims. `jwt.verify` returns `string | JwtPayload`
// with `sub` typed as `string | undefined` and arbitrary extra keys, so we
// re-validate before trusting. Prevents a malformed or tampered token from
// slipping past `as AccessTokenClaims` at runtime.
const RoleSchema = z.enum(['ADMIN', 'COURSE_DESIGNER', 'LEARNER']);

const AccessClaimsSchema = z.object({
  sub: z.string().min(1),
  role: RoleSchema,
  email: z.string().email(),
  type: z.literal('access'),
  // Slice P6 — session id, mirrors the `Session.id` row for this refresh
  // lineage. Enables the sessions controller to pinpoint "the current
  // session" for the `current: true` flag + the "sign out all others"
  // endpoint without the client passing its refresh token around.
  // Optional on parse so access tokens minted before this change still
  // validate; callers that rely on `sid` must fall back gracefully.
  sid: z.string().uuid().optional(),
});

const RefreshClaimsSchema = z.object({
  sub: z.string().min(1),
  type: z.literal('refresh'),
  jti: z.string().min(1),
  // `iat` is set automatically by jsonwebtoken on sign, expressed as
  // seconds since epoch. We expose it on the parsed claim so the refresh
  // handler can reject tokens issued before a user's `passwordChangedAt`
  // (Slice P5). Optional so old tokens minted before this schema change
  // still parse.
  iat: z.number().int().nonnegative().optional(),
});

export type AccessTokenClaims = z.infer<typeof AccessClaimsSchema> & { role: Role };
export type RefreshTokenClaims = z.infer<typeof RefreshClaimsSchema>;

export function signAccessToken(
  user: { id: string; role: Role; email: string },
  sessionId?: string,
): string {
  const payload: Record<string, unknown> = {
    sub: user.id,
    role: user.role,
    email: user.email,
    type: 'access',
  };
  if (sessionId) payload.sid = sessionId;
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_TTL as SignOptions['expiresIn'],
    audience: JWT_AUDIENCE,
  });
}

export function signRefreshToken(user: { id: string }): { token: string; jti: string } {
  const jti = randomUUID();
  const token = jwt.sign(
    { sub: user.id, type: 'refresh', jti },
    env.JWT_REFRESH_SECRET,
    {
      expiresIn: env.JWT_REFRESH_TTL as SignOptions['expiresIn'],
      audience: JWT_AUDIENCE,
    },
  );
  return { token, jti };
}

/**
 * Phase 8 / ADR 0007 — JWT dual-secret rotation.
 *
 * `verifyWithRotation` tries the current secret first. If (and only if)
 * the current attempt failed with a `JsonWebTokenError` whose message
 * contains `'invalid signature'`, AND the operator has set the matching
 * `*_PREVIOUS` env var, we retry once with the previous secret.
 *
 * Any other error from the current-secret attempt — `TokenExpiredError`,
 * `NotBeforeError`, malformed token, audience mismatch — bubbles unchanged.
 * Falling back on those would let an expired token "win" against a still-
 * valid previous secret, defeating the expiry semantics.
 *
 * On a successful previous-secret verify we increment
 * `learn_jwt_verify_with_previous_total{tokenType=...}` so the operator
 * can confirm the rotation window is no longer load-bearing before
 * unsetting `*_PREVIOUS` (see `.env.example` for the runbook).
 *
 * The error message is the same on every failure path — `'invalid token'` —
 * so an attacker probing the verify path can't tell whether the current
 * secret rejected, the previous secret was unset, or the previous secret
 * also rejected. The caller catches `UnauthorizedError` and renders the
 * 401 response.
 */
function verifyWithRotation(
  token: string,
  tokenType: 'access' | 'refresh',
): jwt.JwtPayload | string {
  const current =
    tokenType === 'access' ? env.JWT_ACCESS_SECRET : env.JWT_REFRESH_SECRET;
  const previous =
    tokenType === 'access'
      ? env.JWT_ACCESS_SECRET_PREVIOUS
      : env.JWT_REFRESH_SECRET_PREVIOUS;

  try {
    return jwt.verify(token, current, { audience: JWT_AUDIENCE });
  } catch (err) {
    // Only fall through on a true signature mismatch. Expiry, NotBefore,
    // audience, malformed-header, and Zod-validation errors must NOT
    // re-attempt with the previous secret — they're token-shape failures
    // that the previous secret can't fix, and falling through would let
    // an expired token verify against an old secret.
    const isInvalidSignature =
      err instanceof JsonWebTokenError &&
      typeof err.message === 'string' &&
      err.message.includes('invalid signature');
    if (!isInvalidSignature || !previous) throw err;

    const decoded = jwt.verify(token, previous, { audience: JWT_AUDIENCE });
    // Increment AFTER the previous-secret verify resolves successfully —
    // a thrown error here is genuine 401 territory and shouldn't pollute
    // the rotation metric. Wrapped in a try/catch so an unexpected metrics
    // failure (e.g. registry mis-init in a test fork) doesn't 500 the
    // request — we'd rather log auth correctly than break it on a counter.
    try {
      getMetrics().jwtVerifyWithPreviousTotal.inc({ tokenType });
    } catch {
      // Metrics failure is non-fatal; the auth decision is already made.
    }
    return decoded;
  }
}

export function verifyAccessToken(token: string): AccessTokenClaims {
  try {
    const decoded = verifyWithRotation(token, 'access');
    return AccessClaimsSchema.parse(decoded) as AccessTokenClaims;
  } catch {
    // Generic message — never leaks which secret rejected, never echoes
    // the underlying jsonwebtoken error string (which can contain claim
    // values like the audience).
    throw new UnauthorizedError('Invalid or expired token');
  }
}

export function verifyRefreshToken(token: string): RefreshTokenClaims {
  try {
    const decoded = verifyWithRotation(token, 'refresh');
    return RefreshClaimsSchema.parse(decoded);
  } catch {
    throw new UnauthorizedError('Invalid or expired token');
  }
}
