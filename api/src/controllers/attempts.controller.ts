/**
 * @openapi
 * tags:
 *   name: Attempts
 *   description: Submit a cue response and retrieve own attempts. Grading is server-side — the client is never trusted to mark itself correct.
 */
import type { Request, Response } from 'express';
import {
  listAttemptsQuerySchema,
  submitAttemptBodySchema,
} from '@/validators/cue.validators';
import { attemptService } from '@/services/attempt.service';
import { UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/attempts:
 *   post:
 *     tags: [Attempts]
 *     summary: Submit a response to a cue and receive the grading result.
 *     description: |
 *       The server never echoes the cue's secret fields (e.g. answerIndex,
 *       pairs) — only the grading outcome plus a per-type `scoreJson`.
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [cueId, response]
 *             properties:
 *               cueId: { type: string, format: uuid }
 *               response:
 *                 description: Response shape depends on the cue's type.
 *                 type: object
 *     responses:
 *       201: { description: Attempt persisted; grading result returned. }
 *       400: { description: Response payload did not match the cue type. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not enrolled / no access to the cue's course. }
 *       404: { description: Cue not found. }
 *       501: { description: Cue type not yet supported (VOICE). }
 */
export async function submit(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = submitAttemptBodySchema.parse(req.body);
  const result = await attemptService.submitAttempt(
    body.cueId,
    req.user.id,
    req.user.role,
    body.response,
  );
  res.status(201).json(result);
}

/**
 * @openapi
 * /api/attempts:
 *   get:
 *     tags: [Attempts]
 *     summary: List the caller's own attempts, newest first.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: query
 *         name: videoId
 *         schema: { type: string, format: uuid }
 *         required: false
 *         description: Filter to attempts on a specific video.
 *     responses:
 *       200: { description: Attempts ordered by submittedAt desc. }
 *       401: { description: Unauthenticated. }
 */
export async function listOwn(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { videoId } = listAttemptsQuerySchema.parse(req.query);
  const attempts = await attemptService.listOwnAttempts(req.user.id, videoId);
  res.status(200).json(attempts);
}
