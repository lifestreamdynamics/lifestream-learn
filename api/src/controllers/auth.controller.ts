/**
 * @openapi
 * tags:
 *   name: Auth
 *   description: Authentication endpoints
 */
import type { Request, Response } from 'express';
import { signupSchema, loginSchema, refreshSchema } from '@/validators/auth.validators';
import { authService } from '@/services/auth.service';
import { verifyRefreshToken } from '@/utils/jwt';
import { UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/auth/signup:
 *   post:
 *     tags: [Auth]
 *     summary: Register a new learner account.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password, displayName]
 *             properties:
 *               email: { type: string, format: email }
 *               password: { type: string, minLength: 12 }
 *               displayName: { type: string, minLength: 1, maxLength: 80 }
 *     responses:
 *       201: { description: Account created; returns user + tokens. }
 *       400: { description: Validation error. }
 *       409: { description: Email already registered. }
 */
export async function signup(req: Request, res: Response): Promise<void> {
  const input = signupSchema.parse(req.body);
  const result = await authService.signup(input);
  res.status(201).json(result);
}

/**
 * @openapi
 * /api/auth/login:
 *   post:
 *     tags: [Auth]
 *     summary: Log in with email + password.
 *     responses:
 *       200: { description: Authenticated; returns user + tokens. }
 *       401: { description: Invalid credentials. }
 */
export async function login(req: Request, res: Response): Promise<void> {
  const input = loginSchema.parse(req.body);
  const result = await authService.login(input);
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/auth/refresh:
 *   post:
 *     tags: [Auth]
 *     summary: Exchange a refresh token for a new access token.
 *     responses:
 *       200: { description: New token pair. }
 *       401: { description: Invalid or expired refresh token. }
 */
export async function refresh(req: Request, res: Response): Promise<void> {
  const { refreshToken } = refreshSchema.parse(req.body);
  const claims = verifyRefreshToken(refreshToken);
  const tokens = await authService.refresh({ userId: claims.sub, oldJti: claims.jti });
  res.status(200).json(tokens);
}

/**
 * @openapi
 * /api/auth/me:
 *   get:
 *     tags: [Auth]
 *     summary: Get the current authenticated user.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Current user. }
 *       401: { description: Unauthenticated. }
 */
export async function me(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const user = await authService.findById(req.user.id);
  res.status(200).json(user);
}
