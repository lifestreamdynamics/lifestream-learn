import { Router } from 'express';
import * as authController from '@/controllers/auth.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';
import {
  signupLimiter,
  loginLimiter,
  refreshLimiter,
  logoutLimiter,
  mfaLoginLimiter,
  mfaBackupLimiter,
} from '@/middleware/rate-limit';

export const authRouter = Router();

authRouter.post('/signup', signupLimiter, asyncHandler(authController.signup));
authRouter.post('/login', loginLimiter, asyncHandler(authController.login));
// Slice P7a — MFA step-up completion. Both routes sit outside the
// `authenticate` gate: the pending `mfaToken` IS the credential, and
// asking for a bearer token at this step would invert the dependency
// order (the user hasn't received an access token yet). The limiters
// are tighter than the normal login limiter — see rate-limit.ts.
authRouter.post(
  '/login/mfa/totp',
  mfaLoginLimiter,
  asyncHandler(authController.loginMfaTotp),
);
authRouter.post(
  '/login/mfa/backup',
  mfaBackupLimiter,
  asyncHandler(authController.loginMfaBackup),
);
// Slice P7b — WebAuthn login step. `/options` is rate-limited with the
// same bucket as the TOTP step (both return a short-lived challenge);
// `/verify` uses the same login-MFA bucket to throttle online guessing.
authRouter.post(
  '/login/mfa/webauthn/options',
  mfaLoginLimiter,
  asyncHandler(authController.loginMfaWebauthnOptions),
);
authRouter.post(
  '/login/mfa/webauthn/verify',
  mfaLoginLimiter,
  asyncHandler(authController.loginMfaWebauthnVerify),
);
authRouter.post('/refresh', refreshLimiter, asyncHandler(authController.refresh));
// Slice P6 — logout revokes the refresh-token jti server-side so a stolen
// device can't replay it. The client should call this before clearing its
// local TokenStore. Unauthenticated (the refresh token itself is the
// credential), so it sits outside the `authenticate` gate.
authRouter.post('/logout', logoutLimiter, asyncHandler(authController.logout));
authRouter.get('/me', authenticate, asyncHandler(authController.me));
