/**
 * @openapi
 * tags:
 *   name: Users
 *   description: Cross-user read endpoints. Every route requires auth.
 */
import type { Request, Response } from 'express';
import { userService, OWN_AVATAR_URL } from '@/services/user.service';
import { UnauthorizedError } from '@/utils/errors';
import { streamAvatar } from '@/controllers/utils/stream-avatar';

const AVATAR_CACHE_CONTROL = 'public, max-age=300';

/**
 * @openapi
 * /api/users/{id}/avatar:
 *   get:
 *     tags: [Users]
 *     summary: Fetch another user's avatar bytes.
 *     description: |
 *       Any authenticated caller may fetch any user's avatar. The
 *       uploaded avatar is by construction an identity marker the user
 *       chose to represent themselves (same posture as Gravatar), so
 *       broadening read access here doesn't leak anything a future
 *       directory screen couldn't already show via displayName.
 *
 *       When the requested id matches the caller, we 302 to
 *       `/api/me/avatar` so both routes share one cache entry on the
 *       client and one audit trail on the server.
 *
 *       Returns 204 when the user exists but has no avatar; 404 when
 *       the user doesn't exist (deliberately 404, not 403, to avoid
 *       account enumeration).
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Avatar bytes. }
 *       204: { description: User exists but has no avatar set. }
 *       302: { description: Redirect when id equals the caller's id. }
 *       401: { description: Unauthenticated. }
 *       404: { description: User not found. }
 */
export async function getUserAvatar(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const targetId = req.params.id;
  if (!targetId) {
    res.status(400).json({ error: 'BAD_REQUEST', message: 'User id is required' });
    return;
  }
  if (targetId === req.user.id) {
    res.redirect(302, OWN_AVATAR_URL);
    return;
  }
  const result = await userService.getAvatar(targetId);
  await streamAvatar(res, result, AVATAR_CACHE_CONTROL);
}
