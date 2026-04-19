import jwt, { type SignOptions } from 'jsonwebtoken';
import { randomUUID } from 'node:crypto';
import type { Role } from '@prisma/client';
import { env } from '@/config/env';
import { UnauthorizedError } from '@/utils/errors';

export interface AccessTokenClaims {
  sub: string;
  role: Role;
  email: string;
  type: 'access';
}

export interface RefreshTokenClaims {
  sub: string;
  type: 'refresh';
  jti: string;
}

export function signAccessToken(user: { id: string; role: Role; email: string }): string {
  return jwt.sign(
    { sub: user.id, role: user.role, email: user.email, type: 'access' },
    env.JWT_ACCESS_SECRET,
    { expiresIn: env.JWT_ACCESS_TTL as SignOptions['expiresIn'] },
  );
}

export function signRefreshToken(user: { id: string }): string {
  return jwt.sign(
    { sub: user.id, type: 'refresh', jti: randomUUID() },
    env.JWT_REFRESH_SECRET,
    { expiresIn: env.JWT_REFRESH_TTL as SignOptions['expiresIn'] },
  );
}

export function verifyAccessToken(token: string): AccessTokenClaims {
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as AccessTokenClaims;
    if (decoded.type !== 'access') throw new Error('wrong token type');
    return decoded;
  } catch {
    throw new UnauthorizedError('Invalid or expired token');
  }
}

export function verifyRefreshToken(token: string): RefreshTokenClaims {
  try {
    const decoded = jwt.verify(token, env.JWT_REFRESH_SECRET) as RefreshTokenClaims;
    if (decoded.type !== 'refresh') throw new Error('wrong token type');
    return decoded;
  } catch {
    throw new UnauthorizedError('Invalid or expired token');
  }
}
