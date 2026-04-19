import type { RequestHandler } from 'express';
import { UnauthorizedError } from '@/utils/errors';
import { verifyAccessToken } from '@/utils/jwt';

export const authenticate: RequestHandler = (req, _res, next) => {
  const header = req.get('authorization');
  if (!header?.toLowerCase().startsWith('bearer ')) {
    return next(new UnauthorizedError('Missing bearer token'));
  }
  try {
    const claims = verifyAccessToken(header.slice(7).trim());
    req.user = { id: claims.sub, role: claims.role, email: claims.email };
    next();
  } catch (err) {
    next(err);
  }
};
