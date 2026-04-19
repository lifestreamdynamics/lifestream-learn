/**
 * @openapi
 * tags:
 *   name: Feed
 *   description: Learner's personalised video feed.
 */
import type { Request, Response } from 'express';
import { feedQuerySchema } from '@/validators/feed.validators';
import { feedService } from '@/services/feed.service';
import { UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/feed:
 *   get:
 *     tags: [Feed]
 *     summary: Paginated feed of READY videos from courses the caller is enrolled in.
 *     description: |
 *       Ordered by enrollment recency (most recent first), then by the
 *       video's `orderIndex` ascending. Cursor is opaque (base64); pass the
 *       `nextCursor` field back verbatim.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: query, name: cursor, schema: { type: string } }
 *       - { in: query, name: limit, schema: { type: integer, minimum: 1, maximum: 50 } }
 *     responses:
 *       200:
 *         description: Paginated feed.
 *       400: { description: Invalid cursor. }
 *       401: { description: Unauthenticated. }
 */
export async function getFeed(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const query = feedQuerySchema.parse(req.query);
  const result = await feedService.getFeed(req.user.id, query);
  res.status(200).json(result);
}
