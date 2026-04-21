import bcrypt from 'bcrypt';
import type { PrismaClient, User } from '@prisma/client';
import { UnauthorizedError } from '@/utils/errors';

const COST = 12;

export const hashPassword = (plain: string): Promise<string> => bcrypt.hash(plain, COST);
export const verifyPassword = (plain: string, hash: string): Promise<boolean> =>
  bcrypt.compare(plain, hash);

/**
 * Re-auth gate for destructive operations (change password, delete account,
 * disable MFA, delete passkey). Centralises the constant-shape error so the
 * account-enumeration invariant can't drift: every failure — no user,
 * soft-deleted, wrong password — surfaces the same `Current password is
 * incorrect` message so timing and response shape are indistinguishable.
 *
 * Returns the verified `User` row so callers don't have to re-fetch it.
 */
export async function requireCurrentPassword(
  prisma: PrismaClient,
  userId: string,
  currentPassword: string,
): Promise<User> {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user || user.deletedAt != null) {
    throw new UnauthorizedError('Current password is incorrect');
  }
  const ok = await verifyPassword(currentPassword, user.passwordHash);
  if (!ok) {
    throw new UnauthorizedError('Current password is incorrect');
  }
  return user;
}
