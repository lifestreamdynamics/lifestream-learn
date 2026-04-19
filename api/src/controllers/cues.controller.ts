/**
 * @openapi
 * tags:
 *   name: Cues
 *   description: In-video interactive cues (MCQ, BLANKS, MATCHING). VOICE is reserved; backend rejects it with 501.
 */
import type { Request, Response } from 'express';
import {
  createCueBodySchema,
  cueIdParamsSchema,
  updateCueBodySchema,
  videoIdForCuesParamsSchema,
} from '@/validators/cue.validators';
import { cueService } from '@/services/cue.service';
import { UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/videos/{id}/cues:
 *   post:
 *     tags: [Cues]
 *     summary: Create a cue on a video.
 *     description: |
 *       The payload shape is discriminated by `type`. See
 *       `IMPLEMENTATION_PLAN.md` §4 for canonical per-type shapes.
 *       `VOICE` is reserved — the server responds 501.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [atMs, type, payload]
 *             properties:
 *               atMs: { type: integer, minimum: 0 }
 *               pause: { type: boolean, default: true }
 *               type:
 *                 type: string
 *                 enum: [MCQ, BLANKS, MATCHING, VOICE]
 *               payload: { type: object }
 *               orderIndex: { type: integer, minimum: 0 }
 *     responses:
 *       201: { description: Cue created. }
 *       400: { description: Validation error. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not authorized. }
 *       404: { description: Video not found. }
 *       501: { description: Cue type not yet supported (VOICE). }
 */
export async function createOnVideo(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id: videoId } = videoIdForCuesParamsSchema.parse(req.params);
  const body = createCueBodySchema.parse(req.body);
  const cue = await cueService.createCue(videoId, req.user.id, req.user.role, body);
  res.status(201).json(cue);
}

/**
 * @openapi
 * /api/videos/{id}/cues:
 *   get:
 *     tags: [Cues]
 *     summary: List cues for a video.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200: { description: Cues ordered by atMs ascending. }
 *       401: { description: Unauthenticated. }
 *       403: { description: No access to the underlying video. }
 *       404: { description: Video not found. }
 */
export async function listForVideo(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id: videoId } = videoIdForCuesParamsSchema.parse(req.params);
  const cues = await cueService.listCuesForVideo(videoId, req.user.id, req.user.role);
  res.status(200).json(cues);
}

/**
 * @openapi
 * /api/cues/{id}:
 *   patch:
 *     tags: [Cues]
 *     summary: Update a cue (atMs, pause, payload, orderIndex).
 *     description: |
 *       `type` cannot change — changing it would orphan existing attempts' scoreJson.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               atMs: { type: integer, minimum: 0 }
 *               pause: { type: boolean }
 *               payload: { type: object }
 *               orderIndex: { type: integer, minimum: 0 }
 *     responses:
 *       200: { description: Updated cue. }
 *       400: { description: Validation error (including attempts to change type). }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not authorized. }
 *       404: { description: Cue not found. }
 */
export async function updateById(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id } = cueIdParamsSchema.parse(req.params);
  const patch = updateCueBodySchema.parse(req.body);
  const cue = await cueService.updateCue(id, req.user.id, req.user.role, patch);
  res.status(200).json(cue);
}

/**
 * @openapi
 * /api/cues/{id}:
 *   delete:
 *     tags: [Cues]
 *     summary: Delete a cue. Cascades to Attempt rows on the cue.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       204: { description: Deleted. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not authorized. }
 *       404: { description: Cue not found. }
 */
export async function deleteById(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id } = cueIdParamsSchema.parse(req.params);
  await cueService.deleteCue(id, req.user.id, req.user.role);
  res.status(204).send();
}
