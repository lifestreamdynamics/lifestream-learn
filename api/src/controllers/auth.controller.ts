/**
 * @openapi
 * tags:
 *   name: Auth
 *   description: Authentication endpoints
 */
import type { Request, Response } from 'express';
import type { AuthenticationResponseJSON } from '@simplewebauthn/server';
import { signupSchema, loginSchema, refreshSchema } from '@/validators/auth.validators';
import {
  loginMfaTotpBodySchema,
  loginMfaBackupBodySchema,
  loginMfaWebauthnOptionsBodySchema,
  loginMfaWebauthnVerifyBodySchema,
} from '@/validators/mfa.validators';
import { authService } from '@/services/auth.service';
import { sessionService } from '@/services/session.service';
import { mfaTotpService } from '@/services/mfa-totp.service';
import { mfaWebauthnService } from '@/services/mfa-webauthn.service';
import { verifyRefreshToken } from '@/utils/jwt';
import { UnauthorizedError } from '@/utils/errors';
import type { RequestContext } from '@/services/session.service';

/**
 * Extract the { ip, userAgent } bag that the session service uses to
 * build a Session row. Kept local to the auth + logout controllers so
 * the rest of the codebase doesn't have to agree on header parsing.
 * `req.ip` respects the configured `trust proxy` so deploys behind
 * nginx/Cloudflare get the real client IP, not the proxy's.
 */
function extractContext(req: Request): RequestContext {
  return {
    userAgent: req.get('user-agent') ?? null,
    ip: req.ip ?? null,
  };
}

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
  const result = await authService.signup({ ...input, ctx: extractContext(req) });
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
  const result = await authService.login({ ...input, ctx: extractContext(req) });
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/auth/login/mfa/totp:
 *   post:
 *     tags: [Auth]
 *     summary: Complete an MFA-gated login with a 6-digit TOTP code.
 *     description: |
 *       Client must first call `POST /api/auth/login` and receive
 *       `{ mfaPending: true, mfaToken }`. POST that mfaToken + the
 *       current 6-digit code here to exchange for real access +
 *       refresh tokens. On success the server mints a Session row
 *       exactly as it does for a normal login.
 *
 *       Error shape is deliberately identical for "expired/bogus
 *       mfaToken" and "wrong code" — both 401 with a generic
 *       "Invalid MFA code" message — to prevent account enumeration.
 *     responses:
 *       200: { description: Full token pair + user. }
 *       401: { description: Invalid MFA code or token. }
 *       429: { description: Rate limited. }
 */
export async function loginMfaTotp(req: Request, res: Response): Promise<void> {
  const body = loginMfaTotpBodySchema.parse(req.body);
  const { userId } = mfaTotpService.verifyLoginPendingToken(body.mfaToken);
  const codeOk = await mfaTotpService.verify(userId, body.code);
  if (!codeOk) {
    throw new UnauthorizedError('Invalid MFA code');
  }
  const result = await authService.completeMfaLogin({
    userId,
    ctx: extractContext(req),
  });
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/auth/login/mfa/backup:
 *   post:
 *     tags: [Auth]
 *     summary: Complete an MFA-gated login with a backup code.
 *     description: |
 *       Second-step exchange using one of the 10 backup codes minted
 *       at TOTP enrolment. The matched code is burned server-side on
 *       success — the same string cannot be reused. Rate-limited more
 *       tightly than the TOTP step because a backup code is single-use
 *       and an attacker with one has committed to burning it.
 *     responses:
 *       200: { description: Full token pair + user. }
 *       401: { description: Invalid code or token. }
 *       429: { description: Rate limited. }
 */
export async function loginMfaBackup(req: Request, res: Response): Promise<void> {
  const body = loginMfaBackupBodySchema.parse(req.body);
  const { userId } = mfaTotpService.verifyLoginPendingToken(body.mfaToken);
  const codeOk = await mfaTotpService.verifyBackup(userId, body.code);
  if (!codeOk) {
    throw new UnauthorizedError('Invalid MFA code');
  }
  const result = await authService.completeMfaLogin({
    userId,
    ctx: extractContext(req),
  });
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/auth/login/mfa/webauthn/options:
 *   post:
 *     tags: [Auth]
 *     summary: Request WebAuthn assertion options for a pending MFA login.
 *     description: |
 *       Second-step entry for WebAuthn. The client POSTs its mfaToken (from
 *       the initial `/api/auth/login` response) and receives assertion
 *       options + a challenge token bound to this attempt. The client
 *       hands the options to its platform credential manager and posts the
 *       assertion back to `/api/auth/login/mfa/webauthn/verify` with the
 *       same challenge token.
 *     responses:
 *       200: { description: "Assertion options plus challenge token." }
 *       401: { description: "Invalid MFA token." }
 */
export async function loginMfaWebauthnOptions(
  req: Request,
  res: Response,
): Promise<void> {
  const body = loginMfaWebauthnOptionsBodySchema.parse(req.body);
  const { userId } = mfaTotpService.verifyLoginPendingToken(body.mfaToken);
  const result = await mfaWebauthnService.startAuthentication(userId);
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/auth/login/mfa/webauthn/verify:
 *   post:
 *     tags: [Auth]
 *     summary: Complete an MFA-gated login with a WebAuthn assertion.
 *     description: |
 *       Accepts the mfaToken (from `/api/auth/login`), the challengeToken
 *       (from `/options`), and the assertion response the platform
 *       credential manager produced. On success the server mints a full
 *       token pair + Session row exactly like the TOTP flow does.
 *     responses:
 *       200: { description: Full token pair + user. }
 *       401: { description: Invalid assertion or token. }
 *       429: { description: Rate limited. }
 */
export async function loginMfaWebauthnVerify(
  req: Request,
  res: Response,
): Promise<void> {
  const body = loginMfaWebauthnVerifyBodySchema.parse(req.body);
  const { userId } = mfaTotpService.verifyLoginPendingToken(body.mfaToken);
  const ok = await mfaWebauthnService.verifyAuthentication(userId, {
    challengeToken: body.challengeToken,
    assertionResponse:
      body.assertionResponse as unknown as AuthenticationResponseJSON,
  });
  if (!ok) {
    throw new UnauthorizedError('Invalid MFA assertion');
  }
  const result = await authService.completeMfaLogin({
    userId,
    ctx: extractContext(req),
  });
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
  const tokens = await authService.refresh({
    userId: claims.sub,
    oldJti: claims.jti,
    // Slice P5 — pass `iat` through so the service can reject tokens
    // minted before the user's last password change / account delete.
    oldIat: claims.iat,
    ctx: extractContext(req),
  });
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

/**
 * @openapi
 * /api/auth/logout:
 *   post:
 *     tags: [Auth]
 *     summary: Revoke a refresh token server-side.
 *     description: |
 *       Idempotent: always returns 204 whether or not the token was
 *       already revoked or recognisable. Verifies the refresh token's
 *       signature+audience, marks the matching `Session` row as revoked,
 *       and pushes the jti into the Redis revocation set so a concurrent
 *       refresh call fails fast. Clients should call this before
 *       clearing their local token store so a stolen device can't
 *       replay the refresh token after a user "logs out".
 */
export async function logout(req: Request, res: Response): Promise<void> {
  const { refreshToken } = refreshSchema.parse(req.body);
  try {
    const claims = verifyRefreshToken(refreshToken);
    // Best-effort dual revoke: the Session row is authoritative for
    // the sessions list; the Redis jti entry is the fast-path for the
    // refresh handler's atomic claim.
    await sessionService.revokeSessionByJti(claims.jti);
  } catch {
    // Even an unrecognisable / expired token lands at 204 — logout
    // is idempotent, and leaking "your token was already revoked"
    // doesn't help an attacker.
  }
  res.status(204).send();
}
