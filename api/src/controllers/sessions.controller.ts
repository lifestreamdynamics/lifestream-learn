/**
 * @openapi
 * tags:
 *   name: Sessions
 *   description: Active-session management for the authenticated caller.
 */
import type { Request, Response } from 'express';
import { sessionService } from '@/services/session.service';
import { NotFoundError, UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/me/sessions:
 *   get:
 *     tags: [Sessions]
 *     summary: List the caller's active sessions.
 *     description: |
 *       Returns one entry per non-revoked `Session` row for the caller,
 *       newest first. `current: true` marks the row matching the
 *       caller's current access-token `sid` claim — the client renders
 *       that tile as "You're signed in here".
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Array of sessions. }
 *       401: { description: Unauthenticated. }
 */
export async function listSessions(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const sessions = await sessionService.listActiveForUser(
    req.user.id,
    req.user.sid,
  );
  res.status(200).json(sessions);
}

/**
 * @openapi
 * /api/me/sessions/{sessionId}:
 *   delete:
 *     tags: [Sessions]
 *     summary: Revoke a single session.
 *     description: |
 *       Flips `revokedAt = now()` on the session row and pushes the
 *       refresh `jti` into the Redis revocation set so any concurrent
 *       refresh attempt 401s immediately. Returns 404 when the session
 *       id doesn't exist or belongs to another user — the controller
 *       deliberately conflates these two cases so a caller can't probe
 *       for session ids across accounts.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       204: { description: Session revoked (or already was). }
 *       401: { description: Unauthenticated. }
 *       404: { description: Session not found. }
 */
export async function revokeSession(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const sessionId = req.params.sessionId;
  if (!sessionId) throw new NotFoundError('Session not found');
  const revoked = await sessionService.revokeSessionById(req.user.id, sessionId);
  if (!revoked) throw new NotFoundError('Session not found');
  res.status(204).send();
}

/**
 * @openapi
 * /api/me/sessions:
 *   delete:
 *     tags: [Sessions]
 *     summary: Sign out all other devices.
 *     description: |
 *       Revokes every non-revoked session for the caller except the one
 *       matching `req.user.sid`. Returns 204 even when there are no
 *       other sessions — idempotent. If the access token has no `sid`
 *       (minted before Slice P6), returns 401 to force re-login rather
 *       than nuking every session including the caller's own.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       204: { description: Other sessions revoked. }
 *       401: { description: Unauthenticated or token pre-dates P6. }
 */
export async function revokeAllOtherSessions(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  if (!req.user.sid) {
    // The token was minted before P6 shipped (or by a rogue signer
    // without a session row). Force the client to re-login rather
    // than treating every session as "other" — that would include
    // the caller's own and leave them stuck in a logout loop.
    throw new UnauthorizedError('Session identifier missing; please sign in again');
  }
  await sessionService.revokeAllOtherSessions(req.user.id, req.user.sid);
  res.status(204).send();
}
