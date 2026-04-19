import { Router } from 'express';
import { Role } from '@prisma/client';
import * as videosController from '@/controllers/videos.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';
import { requireRole } from '@/middleware/require-role';

export const videosRouter = Router();

videosRouter.post(
  '/',
  authenticate,
  requireRole(Role.ADMIN, Role.COURSE_DESIGNER),
  asyncHandler(videosController.create),
);
videosRouter.get('/:id', authenticate, asyncHandler(videosController.getById));
videosRouter.get('/:id/playback', authenticate, asyncHandler(videosController.getPlayback));
