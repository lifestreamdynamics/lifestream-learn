/**
 * @openapi
 * tags:
 *   name: Achievements
 *   description: |
 *     Learner-earned achievements. Evaluated pull-not-push: the grading
 *     hot path never writes to this table. Unlocks happen on
 *     `GET /api/me/progress`. `GET /api/me/achievements` returns the
 *     catalog split into `unlocked` and `locked` (plus an
 *     `unlockedAtByAchievementId` map so the client can sort or render
 *     dates without a second round-trip).
 */
import type { Request, Response } from 'express';
import { achievementService } from '@/services/achievement.service';
import { UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/me/achievements:
 *   get:
 *     tags: [Achievements]
 *     summary: List all achievements split into unlocked and locked for the caller.
 *     description: |
 *       Returns the static achievement catalog partitioned by the
 *       caller's unlocked set. `unlockedAtByAchievementId` maps slug to
 *       an ISO-8601 timestamp for unlocked entries only. Locked entries
 *       still include their `criteriaJson` so the client can render a
 *       progress hint ("3 more cues to go"); the server does NOT leak
 *       criteria the client couldn't already derive.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Achievements list. }
 *       401: { description: Unauthenticated. }
 */
export async function getAchievements(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const result = await achievementService.listForUser(req.user.id);
  res.status(200).json(result);
}
