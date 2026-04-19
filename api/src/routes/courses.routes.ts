import { Router } from 'express';
import { Role } from '@prisma/client';
import * as coursesController from '@/controllers/courses.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';
import { optionalAuthenticate } from '@/middleware/optional-authenticate';
import { requireRole } from '@/middleware/require-role';

/**
 * Courses routes.
 *
 * - `POST /` (create) and mutations require authenticate + the appropriate
 *   role. The service re-checks owner/collaborator/admin per course so the
 *   router-level role gate is just a fast-fail.
 * - `GET /` and `GET /:id` accept anonymous traffic via
 *   `optionalAuthenticate`. The service applies different visibility rules
 *   depending on whether `req.user` is set.
 */
export const coursesRouter: Router = Router();

coursesRouter.post(
  '/',
  authenticate,
  requireRole(Role.ADMIN, Role.COURSE_DESIGNER),
  asyncHandler(coursesController.create),
);
coursesRouter.get('/', optionalAuthenticate, asyncHandler(coursesController.list));
coursesRouter.get('/:id', optionalAuthenticate, asyncHandler(coursesController.getById));
coursesRouter.patch('/:id', authenticate, asyncHandler(coursesController.update));
coursesRouter.post('/:id/publish', authenticate, asyncHandler(coursesController.publish));
coursesRouter.post(
  '/:id/collaborators',
  authenticate,
  asyncHandler(coursesController.addCollaborator),
);
coursesRouter.delete(
  '/:id/collaborators/:userId',
  authenticate,
  asyncHandler(coursesController.removeCollaborator),
);
