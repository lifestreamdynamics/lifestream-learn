import { Router } from 'express';
import { Role } from '@prisma/client';
import * as cuesController from '@/controllers/cues.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';
import { requireRole } from '@/middleware/require-role';

/**
 * Cue routes split over two mount points:
 *
 *   - `videoCuesRouter` (mounted on `/api/videos/:id/cues` with
 *     `mergeParams: true`) — handles create + list, where the parent path
 *     already carries the videoId.
 *   - `cuesRouter` (mounted on `/api/cues`) — handles PATCH/DELETE by
 *     cue id. The cue owns the videoId, so the video is not in the URL.
 *
 * Rationale: the plan specified BOTH mount points, and using two routers
 * keeps param parsing obvious at each level (videoId vs cueId) without
 * threading params through the same handler under different shapes.
 *
 * Role gating:
 *   - POST requires COURSE_DESIGNER|ADMIN as fast-fail at the middleware
 *     layer; the service re-checks owner/collaborator/admin per course.
 *   - GET only requires authenticate — learners must be able to see cues to
 *     render them. The service enforces enrollment for learners.
 *   - PATCH/DELETE require authenticate only; the service enforces
 *     owner/collaborator/admin, so the role middleware would be redundant
 *     (a COURSE_DESIGNER who doesn't own the course still gets 403).
 */
export const videoCuesRouter: Router = Router({ mergeParams: true });

videoCuesRouter.post(
  '/',
  authenticate,
  requireRole(Role.ADMIN, Role.COURSE_DESIGNER),
  asyncHandler(cuesController.createOnVideo),
);
videoCuesRouter.get('/', authenticate, asyncHandler(cuesController.listForVideo));

export const cuesRouter: Router = Router();

cuesRouter.patch('/:id', authenticate, asyncHandler(cuesController.updateById));
cuesRouter.delete('/:id', authenticate, asyncHandler(cuesController.deleteById));
