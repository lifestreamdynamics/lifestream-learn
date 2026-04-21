import express, { Router } from 'express';
import * as achievementController from '@/controllers/achievement.controller';
import * as exportController from '@/controllers/export.controller';
import * as meController from '@/controllers/me.controller';
import * as mfaController from '@/controllers/mfa.controller';
import * as progressController from '@/controllers/progress.controller';
import * as sessionsController from '@/controllers/sessions.controller';
import { asyncHandler } from '@/middleware/async-handler';
import { authenticate } from '@/middleware/authenticate';
import {
  passwordChangeLimiter,
  deleteAccountLimiter,
  exportLimiter,
  mfaEnrolLimiter,
  mfaVerifyLimiter,
} from '@/middleware/rate-limit';
import { AVATAR_MAX_BYTES } from '@/services/user.service';

export const meRouter: Router = Router();

meRouter.patch('/', authenticate, asyncHandler(meController.patchMe));

// Slice P5 — destructive account operations. Both require an access
// token AND the current password; the rate limiters cap brute-force
// against the current-password check at 5 attempts / 10 min / IP.
meRouter.post(
  '/password',
  passwordChangeLimiter,
  authenticate,
  asyncHandler(meController.changePassword),
);
meRouter.delete(
  '/',
  deleteAccountLimiter,
  authenticate,
  asyncHandler(meController.deleteAccount),
);

// `express.raw()` is mounted per-route so the global `express.json()` in
// app.ts doesn't parse the binary body. `type: image/*` accepts our three
// allowed image types plus rejects everything else before the handler
// even runs — the 415 check in the controller is a defense-in-depth.
// `limit` is one byte above the hard cap so the handler can return a
// clean 413 rather than express emitting a boilerplate error.
meRouter.post(
  '/avatar',
  authenticate,
  express.raw({
    type: 'image/*',
    limit: AVATAR_MAX_BYTES + 1,
  }),
  asyncHandler(meController.uploadAvatar),
);

// Slice P2 — progress aggregation endpoints.
meRouter.get(
  '/progress',
  authenticate,
  asyncHandler(progressController.getOverall),
);
meRouter.get(
  '/progress/courses/:courseId',
  authenticate,
  asyncHandler(progressController.getCourse),
);
meRouter.get(
  '/progress/lessons/:videoId',
  authenticate,
  asyncHandler(progressController.getLesson),
);

// Slice P3 — achievements listing. Unlock *evaluation* happens on
// GET /api/me/progress (pull-not-push, see achievement.service.ts);
// this endpoint is a read of the current unlock set for the grid UI.
meRouter.get(
  '/achievements',
  authenticate,
  asyncHandler(achievementController.getAchievements),
);

// Slice P6 — active-session management. All three require a valid
// access token; `DELETE /sessions` additionally relies on the `sid`
// claim on the access token so the controller can exclude the caller's
// own row.
meRouter.get(
  '/sessions',
  authenticate,
  asyncHandler(sessionsController.listSessions),
);
meRouter.delete(
  '/sessions',
  authenticate,
  asyncHandler(sessionsController.revokeAllOtherSessions),
);
meRouter.delete(
  '/sessions/:sessionId',
  authenticate,
  asyncHandler(sessionsController.revokeSession),
);

// Slice P7a — MFA (TOTP).
// `GET /api/me/mfa` is unthrottled — read-only enumeration of the
// caller's own factor state drives the profile UI and shouldn't have
// a 429 in its way.
meRouter.get('/mfa', authenticate, asyncHandler(mfaController.listMethods));
// Enrol start + confirm share a rate-limit bucket family. The verify
// endpoint uses a tighter bucket to throttle online code guessing.
meRouter.post(
  '/mfa/totp/enrol',
  mfaEnrolLimiter,
  authenticate,
  asyncHandler(mfaController.startEnrol),
);
meRouter.post(
  '/mfa/totp/verify',
  mfaVerifyLimiter,
  authenticate,
  asyncHandler(mfaController.confirmEnrol),
);
// Disable requires password + current code; the verify limiter's
// 10/5min ceiling is the right fit here too.
meRouter.delete(
  '/mfa/totp',
  mfaVerifyLimiter,
  authenticate,
  asyncHandler(mfaController.disable),
);

// Slice P8 — GDPR personal-data export (JSON). Rate limit is PER USER
// (1 / 24h), not per IP — the limiter's keyGenerator reads req.user.id,
// so `authenticate` MUST run ahead of `exportLimiter` in the chain. The
// soft-deleted-user gate lives in the controller (returns 403).
meRouter.get(
  '/export',
  authenticate,
  exportLimiter,
  asyncHandler(exportController.exportMyData),
);

// Slice P7b — WebAuthn / passkeys.
// Register start + verify share the enrol limiter (same bucket family
// as TOTP enrol so one user can't side-step it by swapping kinds).
meRouter.post(
  '/mfa/webauthn/register/options',
  mfaEnrolLimiter,
  authenticate,
  asyncHandler(mfaController.startWebauthnRegistration),
);
meRouter.post(
  '/mfa/webauthn/register/verify',
  mfaVerifyLimiter,
  authenticate,
  asyncHandler(mfaController.verifyWebauthnRegistration),
);
// Listing is unthrottled — read-only enumeration of the caller's own
// factor state drives the profile UI and a tight 429 would show up
// as a broken passkeys list.
meRouter.get(
  '/mfa/webauthn',
  authenticate,
  asyncHandler(mfaController.listWebauthnCredentials),
);
// Delete requires current password; the verify limiter's 10/5min bucket
// keeps the bcrypt cost under control against a bruteforce.
meRouter.delete(
  '/mfa/webauthn/:credentialId',
  mfaVerifyLimiter,
  authenticate,
  asyncHandler(mfaController.deleteWebauthnCredential),
);
