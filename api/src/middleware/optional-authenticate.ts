import type { RequestHandler } from 'express';
import { verifyAccessToken } from '@/utils/jwt';

/**
 * Authenticate the request if a Bearer token is present and valid; otherwise
 * pass through with `req.user` unset. Used on endpoints (e.g. public course
 * list/get) that serve different content to authed vs unauthed callers but
 * must not reject unauthed traffic.
 *
 * A MALFORMED token is still rejected (401) — sending garbage is a bug, not
 * an anonymous visit. A MISSING token is the pass-through case.
 */
export const optionalAuthenticate: RequestHandler = (req, _res, next) => {
  const header = req.get('authorization');
  if (!header) {
    return next();
  }
  if (!header.toLowerCase().startsWith('bearer ')) {
    return next();
  }
  try {
    const claims = verifyAccessToken(header.slice(7).trim());
    req.user = { id: claims.sub, role: claims.role, email: claims.email };
    next();
  } catch (err) {
    next(err);
  }
};
