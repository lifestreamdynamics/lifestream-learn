/**
 * @openapi
 * tags:
 *   name: Analytics
 *   description: Append-only analytics event ingestion and admin aggregates.
 */
import type { Request, Response } from 'express';
import {
  analyticsEventsBodySchema,
  courseIdParamsSchema,
} from '@/validators/analytics.validators';
import { analyticsService } from '@/services/analytics.service';
import { UnauthorizedError, ValidationError } from '@/utils/errors';

/**
 * @openapi
 * /api/events:
 *   post:
 *     tags: [Analytics]
 *     summary: Ingest a batch of analytics events (authenticated, any role).
 *     description: |
 *       Batch of 1..100 events. Unknown `eventType` values are accepted so
 *       the Flutter app can introduce new event kinds without a backend
 *       deploy. Each event is capped at 4KB serialized.
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: array
 *             minItems: 1
 *             maxItems: 100
 *             items:
 *               type: object
 *               required: [eventType, occurredAt]
 *               properties:
 *                 eventType: { type: string, maxLength: 64 }
 *                 occurredAt: { type: string, format: date-time }
 *                 videoId: { type: string, format: uuid }
 *                 cueId: { type: string, format: uuid }
 *                 payload: { type: object }
 *     responses:
 *       202: { description: Accepted (ingested). }
 *       400: { description: Validation error (includes per-event size cap). }
 *       401: { description: Unauthenticated. }
 */
export async function ingest(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  if (!Array.isArray(req.body)) {
    throw new ValidationError('Body must be an array of events');
  }
  const events = analyticsEventsBodySchema.parse(req.body);
  const { count } = await analyticsService.ingestEvents(req.user.id, events);
  res.status(202).json({ ingested: count });
}

/**
 * @openapi
 * /api/admin/analytics/courses/{id}:
 *   get:
 *     tags: [Analytics]
 *     summary: Admin — aggregate analytics for a course.
 *     description: |
 *       Returns `{ totalViews, completionRate, perCueTypeAccuracy }`.
 *       `completionRate` is currently an MVP approximation
 *       (distinct-video-complete-users / enrollments) — see
 *       `analytics.service.ts` for the precise definition.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Course analytics aggregate. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not an admin. }
 */
export async function getCourseAggregate(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id } = courseIdParamsSchema.parse(req.params);
  const result = await analyticsService.getCourseAggregate(id);
  res.status(200).json(result);
}
