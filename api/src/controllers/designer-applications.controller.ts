/**
 * @openapi
 * tags:
 *   name: DesignerApplications
 *   description: Workflow for learners applying to become course designers.
 */
import type { Request, Response } from 'express';
import {
  createDesignerApplicationBodySchema,
  designerApplicationIdParamsSchema,
  listDesignerApplicationsQuerySchema,
  reviewDesignerApplicationBodySchema,
} from '@/validators/designer-application.validators';
import { designerApplicationService } from '@/services/designer-application.service';
import { UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/designer-applications:
 *   post:
 *     tags: [DesignerApplications]
 *     summary: Learner applies to become a course designer.
 *     description: |
 *       Only LEARNER may submit. If the learner has a previously REJECTED
 *       application, that row is resurrected to PENDING (the schema has
 *       `@unique userId`, so there's exactly one DesignerApplication per
 *       user). An existing PENDING application returns 409.
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               note: { type: string, maxLength: 2000 }
 *     responses:
 *       201: { description: Application submitted (PENDING). }
 *       400: { description: Validation error. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Only learners may apply. }
 *       409: { description: A pending/approved application already exists. }
 */
export async function apply(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = createDesignerApplicationBodySchema.parse(req.body ?? {});
  const app = await designerApplicationService.applyAsLearner(
    req.user.id,
    req.user.role,
    body.note,
  );
  res.status(201).json(app);
}

/**
 * @openapi
 * /api/admin/designer-applications:
 *   get:
 *     tags: [DesignerApplications]
 *     summary: Admin — list designer applications, optionally filtered by status.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: query, name: status, schema: { type: string, enum: [PENDING, APPROVED, REJECTED] } }
 *       - { in: query, name: cursor, schema: { type: string } }
 *       - { in: query, name: limit, schema: { type: integer, minimum: 1, maximum: 50 } }
 *     responses:
 *       200: { description: Paginated applications. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not an admin. }
 */
export async function adminList(req: Request, res: Response): Promise<void> {
  const query = listDesignerApplicationsQuerySchema.parse(req.query);
  const result = await designerApplicationService.list(query);
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/admin/designer-applications/{id}:
 *   patch:
 *     tags: [DesignerApplications]
 *     summary: Admin — approve or reject a designer application.
 *     description: |
 *       On APPROVED the user's role is atomically promoted to
 *       `COURSE_DESIGNER` (only if currently LEARNER — admins aren't
 *       downgraded). The application update and role change land in a single
 *       `$transaction`.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [status]
 *             properties:
 *               status: { type: string, enum: [APPROVED, REJECTED] }
 *               reviewerNote: { type: string, maxLength: 2000 }
 *     responses:
 *       200: { description: Reviewed application. }
 *       400: { description: Validation error. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not an admin. }
 *       404: { description: Application not found. }
 */
export async function adminReview(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id } = designerApplicationIdParamsSchema.parse(req.params);
  const body = reviewDesignerApplicationBodySchema.parse(req.body);
  const updated = await designerApplicationService.review(id, req.user.id, body);
  res.status(200).json(updated);
}
