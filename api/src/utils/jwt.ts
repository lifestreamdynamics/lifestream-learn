import jwt, { type SignOptions } from 'jsonwebtoken';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import type { Role } from '@prisma/client';
import { env } from '@/config/env';
import { UnauthorizedError } from '@/utils/errors';

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
});

const RefreshClaimsSchema = z.object({
  sub: z.string().min(1),
  type: z.literal('refresh'),
  jti: z.string().min(1),
});

export type AccessTokenClaims = z.infer<typeof AccessClaimsSchema> & { role: Role };
export type RefreshTokenClaims = z.infer<typeof RefreshClaimsSchema>;

export function signAccessToken(user: { id: string; role: Role; email: string }): string {
  return jwt.sign(
    { sub: user.id, role: user.role, email: user.email, type: 'access' },
    env.JWT_ACCESS_SECRET,
    {
      expiresIn: env.JWT_ACCESS_TTL as SignOptions['expiresIn'],
      audience: JWT_AUDIENCE,
    },
  );
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

export function verifyAccessToken(token: string): AccessTokenClaims {
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, { audience: JWT_AUDIENCE });
    return AccessClaimsSchema.parse(decoded) as AccessTokenClaims;
  } catch {
    throw new UnauthorizedError('Invalid or expired token');
  }
}

export function verifyRefreshToken(token: string): RefreshTokenClaims {
  try {
    const decoded = jwt.verify(token, env.JWT_REFRESH_SECRET, { audience: JWT_AUDIENCE });
    return RefreshClaimsSchema.parse(decoded);
  } catch {
    throw new UnauthorizedError('Invalid or expired token');
  }
}
