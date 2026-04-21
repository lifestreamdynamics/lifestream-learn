/**
 * @openapi
 * tags:
 *   name: Progress
 *   description: |
 *     Progress aggregation for the caller's own learning. All endpoints are
 *     authenticated and scoped to `req.user.id` — a user never sees another
 *     user's progress. Grade aggregation happens server-side; the client
 *     never re-derives letter grades.
 */
import type { Request, Response } from 'express';
import { progressService } from '@/services/progress.service';
import {
  progressCourseIdParamsSchema,
  progressVideoIdParamsSchema,
} from '@/validators/progress.validators';
import { UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/me/progress:
 *   get:
 *     tags: [Progress]
 *     summary: Overall progress dashboard for the caller.
 *     description: |
 *       Returns a summary card (GPA-style grade, counts, watch time) plus
 *       per-course summaries. A fresh user with no enrollments gets
 *       zeroes and an empty `perCourse` list — not an error.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Overall progress summary. }
 *       401: { description: Unauthenticated. }
 */
export async function getOverall(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const result = await progressService.getOverallProgress(req.user.id);
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/me/progress/courses/{courseId}:
 *   get:
 *     tags: [Progress]
 *     summary: Per-course progress detail (lesson breakdown + grade).
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: courseId, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Course progress detail. }
 *       400: { description: Validation error (invalid UUID). }
 *       401: { description: Unauthenticated. }
 *       404: { description: Course not found, or user not enrolled. }
 */
export async function getCourse(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { courseId } = progressCourseIdParamsSchema.parse(req.params);
  const result = await progressService.getCourseProgress(req.user.id, courseId);
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/me/progress/lessons/{videoId}:
 *   get:
 *     tags: [Progress]
 *     summary: Lesson review — per-cue outcomes + your answers.
 *     description: |
 *       Returns one entry per cue in the lesson. **Unattempted cues have
 *       `correctAnswerSummary: null`** — the server never pre-leaks
 *       answers. Already-attempted cues expose a human-readable summary
 *       derived from `cue.payload` (not the raw payload).
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: videoId, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Lesson review. }
 *       400: { description: Validation error (invalid UUID). }
 *       401: { description: Unauthenticated. }
 *       404: { description: Video not found, or user has no access. }
 */
export async function getLesson(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { videoId } = progressVideoIdParamsSchema.parse(req.params);
  const result = await progressService.getLessonReview(req.user.id, videoId);
  res.status(200).json(result);
}
