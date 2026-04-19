import { Router } from 'express';
import * as enrollmentsController from '@/controllers/enrollments.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';

export const enrollmentsRouter: Router = Router();

enrollmentsRouter.post('/', authenticate, asyncHandler(enrollmentsController.create));
enrollmentsRouter.get('/', authenticate, asyncHandler(enrollmentsController.listOwn));
enrollmentsRouter.patch(
  '/:courseId/progress',
  authenticate,
  asyncHandler(enrollmentsController.updateProgress),
);
