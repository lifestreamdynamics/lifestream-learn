import { Router } from 'express';
import * as usersController from '@/controllers/users.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';

export const usersRouter: Router = Router();

// Authenticated cross-user avatar read. Deliberately open to every authed
// role — the uploaded avatar is an identity marker the user chose to
// present publicly, same posture as Gravatar. See the controller docstring.
usersRouter.get(
  '/:id/avatar',
  authenticate,
  asyncHandler(usersController.getUserAvatar),
);
