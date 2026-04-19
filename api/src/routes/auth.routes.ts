import { Router } from 'express';
import * as authController from '@/controllers/auth.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';
import { signupLimiter, loginLimiter, refreshLimiter } from '@/middleware/rate-limit';

export const authRouter = Router();

authRouter.post('/signup', signupLimiter, asyncHandler(authController.signup));
authRouter.post('/login', loginLimiter, asyncHandler(authController.login));
authRouter.post('/refresh', refreshLimiter, asyncHandler(authController.refresh));
authRouter.get('/me', authenticate, asyncHandler(authController.me));
