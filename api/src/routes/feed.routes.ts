import { Router } from 'express';
import * as feedController from '@/controllers/feed.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';

export const feedRouter: Router = Router();

feedRouter.get('/', authenticate, asyncHandler(feedController.getFeed));
