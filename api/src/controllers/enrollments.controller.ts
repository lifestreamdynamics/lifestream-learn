/**
 * @openapi
 * tags:
 *   name: Enrollments
 *   description: Learner enrollment in published courses and progress tracking.
 */
import type { Request, Response } from 'express';
import {
  createEnrollmentBodySchema,
  enrollmentCourseIdParamsSchema,
  updateEnrollmentProgressBodySchema,
} from '@/validators/enrollment.validators';
import { enrollmentService } from '@/services/enrollment.service';
import { UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/enrollments:
 *   post:
 *     tags: [Enrollments]
 *     summary: Enroll the caller in a published course (idempotent).
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [courseId]
 *             properties:
 *               courseId: { type: string, format: uuid }
 *     responses:
 *       201: { description: New enrollment created. }
 *       200: { description: Existing enrollment returned. }
 *       401: { description: Unauthenticated. }
 *       404: { description: Course not found. }
 *       409: { description: Course not yet published. }
 */
export async function create(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = createEnrollmentBodySchema.parse(req.body);
  const { enrollment, created } = await enrollmentService.createEnrollment(
    req.user.id,
    body.courseId,
  );
  res.status(created ? 201 : 200).json(enrollment);
}

/**
 * @openapi
 * /api/enrollments:
 *   get:
 *     tags: [Enrollments]
 *     summary: List the caller's own enrollments (newest first).
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Enrollment rows with course summary. }
 *       401: { description: Unauthenticated. }
 */
export async function listOwn(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const rows = await enrollmentService.listOwnEnrollments(req.user.id);
  res.status(200).json(rows);
}

/**
 * @openapi
 * /api/enrollments/{courseId}/progress:
 *   patch:
 *     tags: [Enrollments]
 *     summary: Update the caller's progress (lastVideoId + lastPosMs).
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: courseId, required: true, schema: { type: string, format: uuid } }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [lastVideoId, lastPosMs]
 *             properties:
 *               lastVideoId: { type: string, format: uuid }
 *               lastPosMs: { type: integer, minimum: 0 }
 *     responses:
 *       204: { description: Progress saved. }
 *       400: { description: Validation failed (e.g. videoId not in course). }
 *       401: { description: Unauthenticated. }
 *       404: { description: No enrollment for this course. }
 */
export async function updateProgress(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { courseId } = enrollmentCourseIdParamsSchema.parse(req.params);
  const body = updateEnrollmentProgressBodySchema.parse(req.body);
  await enrollmentService.updateProgress(req.user.id, courseId, body);
  res.status(204).send();
}
