import type { RequestHandler } from 'express';
import type { Role } from '@prisma/client';
import { UnauthorizedError, ForbiddenError } from '@/utils/errors';

export function requireRole(...roles: Role[]): RequestHandler {
  return (req, _res, next) => {
    if (!req.user) return next(new UnauthorizedError('Not authenticated'));
    if (!roles.includes(req.user.role)) return next(new ForbiddenError('Insufficient role'));
    next();
  };
}
