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
    req.user = {
      id: claims.sub,
      role: claims.role,
      email: claims.email,
      // Slice P6 — optional: tokens minted before P6 won't have a `sid`.
      // Controllers that depend on it must fall back gracefully (the
      // sessions controller treats a missing sid as "no current session
      // to flag", which degrades to every tile showing an action menu).
      sid: claims.sid,
    };
    next();
  } catch (err) {
    next(err);
  }
};
