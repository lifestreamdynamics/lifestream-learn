import express, { Router } from 'express';
import { Role } from '@prisma/client';
import * as videosController from '@/controllers/videos.controller';
import * as captionsController from '@/controllers/captions.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';
import { requireRole } from '@/middleware/require-role';
import { videoCuesRouter } from '@/routes/cues.routes';
import { CAPTION_MAX_BYTES } from '@/services/caption.service';

export const videosRouter = Router();

videosRouter.post(
  '/',
  authenticate,
  requireRole(Role.ADMIN, Role.COURSE_DESIGNER),
  asyncHandler(videosController.create),
);
videosRouter.get('/:id', authenticate, asyncHandler(videosController.getById));
videosRouter.get('/:id/playback', authenticate, asyncHandler(videosController.getPlayback));

// Nested cues router (mergeParams exposes :id from this mount). Handles
// POST/GET /api/videos/:id/cues. PATCH/DELETE live under /api/cues/:id.
videosRouter.use('/:id/cues', videoCuesRouter);

// Caption routes — course-level authorization lives in the service layer;
// no requireRole guard here (a course collaborator with LEARNER role must
// be able to upload captions, which a requireRole would block).
videosRouter.post(
  '/:id/captions',
  authenticate,
  express.raw({
    type: ['text/vtt', 'application/x-subrip'],
    limit: CAPTION_MAX_BYTES + 1,
  }),
  asyncHandler(captionsController.uploadCaption),
);
videosRouter.get(
  '/:id/captions',
  authenticate,
  asyncHandler(captionsController.listCaptions),
);
// DELETE with `:language` must be registered AFTER the plain GET to avoid
// ambiguity in Express's route matching.
videosRouter.delete(
  '/:id/captions/:language',
  authenticate,
  asyncHandler(captionsController.deleteCaption),
);
