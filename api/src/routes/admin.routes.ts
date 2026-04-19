import { Router } from 'express';
import { Role } from '@prisma/client';
import * as designerApplicationsController from '@/controllers/designer-applications.controller';
import * as analyticsController from '@/controllers/analytics.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';
import { requireRole } from '@/middleware/require-role';

/**
 * All admin-only endpoints share the `/api/admin` mount. Every sub-route is
 * gated by `authenticate` + `requireRole(ADMIN)` at the router level so
 * controllers/services don't have to re-check. Add new admin endpoints here.
 */
export const adminRouter: Router = Router();

adminRouter.use(authenticate, requireRole(Role.ADMIN));

adminRouter.get(
  '/designer-applications',
  asyncHandler(designerApplicationsController.adminList),
);
adminRouter.patch(
  '/designer-applications/:id',
  asyncHandler(designerApplicationsController.adminReview),
);

adminRouter.get(
  '/analytics/courses/:id',
  asyncHandler(analyticsController.getCourseAggregate),
);
