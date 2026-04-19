/**
 * @openapi
 * tags:
 *   name: Courses
 *   description: Course CRUD, publish, and collaborator management.
 */
import type { Request, Response } from 'express';
import {
  addCollaboratorBodySchema,
  collaboratorParamsSchema,
  courseIdParamsSchema,
  createCourseBodySchema,
  listCoursesQuerySchema,
  updateCourseBodySchema,
} from '@/validators/course.validators';
import { courseService } from '@/services/course.service';
import { UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/courses:
 *   post:
 *     tags: [Courses]
 *     summary: Create a course (COURSE_DESIGNER or ADMIN).
 *     description: |
 *       `slug` is auto-generated from `title` when omitted
 *       (`slugify(title)-<6-char-random>`). `description` is required.
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [title, description]
 *             properties:
 *               title: { type: string, minLength: 1, maxLength: 200 }
 *               description: { type: string, minLength: 1, maxLength: 2000 }
 *               coverImageUrl: { type: string, format: uri }
 *               slug: { type: string, pattern: '^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$' }
 *     responses:
 *       201: { description: Created. }
 *       400: { description: Validation error. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not a designer/admin. }
 *       409: { description: Slug already taken. }
 */
export async function create(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = createCourseBodySchema.parse(req.body);
  const course = await courseService.createCourse(req.user.id, req.user.role, body);
  res.status(201).json(course);
}

/**
 * @openapi
 * /api/courses:
 *   get:
 *     tags: [Courses]
 *     summary: List courses (paginated, opaque cursor).
 *     description: |
 *       Unauthenticated callers always see `published=true` and cannot use the
 *       `owned`/`enrolled` filters. Cursor is an opaque base64 token returned
 *       in `nextCursor`; pass it back verbatim to fetch the next page.
 *     parameters:
 *       - { in: query, name: cursor, schema: { type: string } }
 *       - { in: query, name: limit, schema: { type: integer, minimum: 1, maximum: 50 } }
 *       - { in: query, name: owned, schema: { type: boolean } }
 *       - { in: query, name: enrolled, schema: { type: boolean } }
 *       - { in: query, name: published, schema: { type: boolean } }
 *     responses:
 *       200:
 *         description: Paginated list.
 *       400: { description: Invalid cursor. }
 *       403: { description: owned/enrolled requested without auth. }
 */
export async function list(req: Request, res: Response): Promise<void> {
  const query = listCoursesQuerySchema.parse(req.query);
  const userId = req.user?.id ?? null;
  const role = req.user?.role ?? null;
  const result = await courseService.listCourses(userId, role, query);
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/courses/{id}:
 *   get:
 *     tags: [Courses]
 *     summary: Fetch a course with its video summary.
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Course with videos. }
 *       404: { description: Not found, or not published for non-privileged caller. }
 */
export async function getById(req: Request, res: Response): Promise<void> {
  const { id } = courseIdParamsSchema.parse(req.params);
  const userId = req.user?.id ?? null;
  const role = req.user?.role ?? null;
  const course = await courseService.getCourseById(id, userId, role);
  res.status(200).json(course);
}

/**
 * @openapi
 * /api/courses/{id}:
 *   patch:
 *     tags: [Courses]
 *     summary: Partial update (owner or admin). Cannot transfer ownership.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title: { type: string }
 *               description: { type: string }
 *               coverImageUrl: { type: string, format: uri, nullable: true }
 *               slug: { type: string }
 *     responses:
 *       200: { description: Updated. }
 *       400: { description: Validation error. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not owner/admin. }
 *       404: { description: Not found. }
 *       409: { description: Slug already taken. }
 */
export async function update(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id } = courseIdParamsSchema.parse(req.params);
  const patch = updateCourseBodySchema.parse(req.body);
  const course = await courseService.updateCourse(id, req.user.id, req.user.role, patch);
  res.status(200).json(course);
}

/**
 * @openapi
 * /api/courses/{id}/publish:
 *   post:
 *     tags: [Courses]
 *     summary: Publish a course (owner or admin).
 *     description: Requires at least one video with `status=READY`.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Published (idempotent if already published). }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not owner/admin. }
 *       404: { description: Not found. }
 *       409: { description: No READY video attached. }
 */
export async function publish(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id } = courseIdParamsSchema.parse(req.params);
  const course = await courseService.publishCourse(id, req.user.id, req.user.role);
  res.status(200).json(course);
}

/**
 * @openapi
 * /api/courses/{id}/collaborators:
 *   post:
 *     tags: [Courses]
 *     summary: Add a collaborator (owner or admin). Idempotent.
 *     description: |
 *       Target user must have role `COURSE_DESIGNER` or `ADMIN`.
 *       Returns 201 when a new row is created, 200 when the collaborator
 *       already existed.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [userId]
 *             properties:
 *               userId: { type: string, format: uuid }
 *     responses:
 *       201: { description: New collaborator row. }
 *       200: { description: Already a collaborator. }
 *       400: { description: Target user is not a course designer. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not owner/admin. }
 *       404: { description: Course not found. }
 */
export async function addCollaborator(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id } = courseIdParamsSchema.parse(req.params);
  const body = addCollaboratorBodySchema.parse(req.body);
  const { collaborator, created } = await courseService.addCollaborator(
    id,
    req.user.id,
    req.user.role,
    body.userId,
  );
  res.status(created ? 201 : 200).json(collaborator);
}

/**
 * @openapi
 * /api/courses/{id}/collaborators/{userId}:
 *   delete:
 *     tags: [Courses]
 *     summary: Remove a collaborator (owner or admin). Idempotent.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *       - { in: path, name: userId, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       204: { description: Removed (or already absent). }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not owner/admin. }
 *       404: { description: Course not found. }
 */
export async function removeCollaborator(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id, userId } = collaboratorParamsSchema.parse(req.params);
  await courseService.removeCollaborator(id, req.user.id, req.user.role, userId);
  res.status(204).send();
}
