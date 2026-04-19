import { Router } from 'express';
import * as analyticsController from '@/controllers/analytics.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';

/**
 * Learner/designer-facing event ingestion. Admin-only read endpoints live
 * under the admin router at `/api/admin/analytics/courses/:id`.
 */
export const eventsRouter: Router = Router();

eventsRouter.post('/', authenticate, asyncHandler(analyticsController.ingest));
