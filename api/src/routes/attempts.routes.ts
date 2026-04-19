import { Router } from 'express';
import * as attemptsController from '@/controllers/attempts.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';

/**
 * Attempt routes. Role gating is done per-cue at the service layer (any
 * authenticated user with access to the cue's course may submit); learners
 * are the main users so we don't require a role here.
 */
export const attemptsRouter: Router = Router();

attemptsRouter.post('/', authenticate, asyncHandler(attemptsController.submit));
attemptsRouter.get('/', authenticate, asyncHandler(attemptsController.listOwn));
