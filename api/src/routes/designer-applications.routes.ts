import { Router } from 'express';
import * as designerApplicationsController from '@/controllers/designer-applications.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';

/**
 * Public learner-facing endpoint for submitting a designer application.
 * Admin endpoints live under `adminRouter` at `/api/admin/designer-applications`.
 */
export const designerApplicationsRouter: Router = Router();

designerApplicationsRouter.post(
  '/',
  authenticate,
  asyncHandler(designerApplicationsController.apply),
);
