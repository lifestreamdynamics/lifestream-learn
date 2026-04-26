/**
 * @openapi
 * tags:
 *   name: Me
 *   description: Profile endpoints for the authenticated caller.
 */
import type { Request, Response } from 'express';
import {
  patchMeBodySchema,
  changePasswordBodySchema,
  deleteAccountBodySchema,
} from '@/validators/me.validators';
import { userService, AVATAR_MAX_BYTES } from '@/services/user.service';
import type { AvatarUploadInput } from '@/services/user.service';
import { UnauthorizedError, ValidationError } from '@/utils/errors';
import { streamAvatar } from '@/controllers/utils/stream-avatar';

const AVATAR_CACHE_CONTROL = 'private, max-age=300';

const ALLOWED_AVATAR_CONTENT_TYPES: ReadonlySet<AvatarUploadInput['contentType']> = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
]);

/**
 * @openapi
 * /api/me:
 *   patch:
 *     tags: [Me]
 *     summary: Update the caller's own profile (display name, prefs, Gravatar opt-in).
 *     description: |
 *       Email and role are intentionally not editable through this endpoint.
 *       Unknown keys are rejected (strict body validation).
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               displayName: { type: string, minLength: 1, maxLength: 80 }
 *               useGravatar: { type: boolean }
 *               preferences: { type: object, additionalProperties: true }
 *     responses:
 *       200: { description: Updated private user. }
 *       400: { description: Validation error. }
 *       401: { description: Unauthenticated. }
 */
export async function patchMe(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = patchMeBodySchema.parse(req.body);
  const user = await userService.updateMe(req.user.id, body);
  res.status(200).json(user);
}

/**
 * @openapi
 * /api/me/avatar:
 *   post:
 *     tags: [Me]
 *     summary: Upload a new avatar image.
 *     description: |
 *       Accepts a raw image body (content-type must be `image/jpeg`,
 *       `image/png`, or `image/webp`). Max 2 MB. The server writes the
 *       object to the `avatars/<userId>/<uuid>.<ext>` prefix on the
 *       upload bucket and stores the key on the user row. Any previous
 *       avatar is deleted best-effort. EXIF metadata (including GPS
 *       coordinates) is stripped server-side via sharp before persistence.
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         image/jpeg: { schema: { type: string, format: binary } }
 *         image/png:  { schema: { type: string, format: binary } }
 *         image/webp: { schema: { type: string, format: binary } }
 *     responses:
 *       200: { description: Upload complete; returns `avatarKey` and `avatarUrl`. }
 *       400: { description: Missing or invalid payload. }
 *       401: { description: Unauthenticated. }
 *       413: { description: Payload too large (>2 MB). }
 *       415: { description: Unsupported content type. }
 */
export async function uploadAvatar(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');

  // The route mounts `express.raw(...)` with a content-type guard and a
  // size limit; we still re-validate here because (a) controller unit
  // tests inject `req.body` without the middleware and (b) defensive
  // depth is cheap.
  const contentTypeHeader = req.get('content-type') ?? '';
  // Strip any `; charset=...` suffix.
  const contentType = contentTypeHeader.split(';')[0]?.trim().toLowerCase();
  if (!contentType || !ALLOWED_AVATAR_CONTENT_TYPES.has(contentType as AvatarUploadInput['contentType'])) {
    // 415 rather than 400 — the request is syntactically valid, the
    // server just can't handle that media type.
    res.status(415).json({
      error: 'UNSUPPORTED_MEDIA_TYPE',
      message: 'Avatar must be image/jpeg, image/png, or image/webp',
    });
    return;
  }

  const bytes = req.body as unknown;
  if (!Buffer.isBuffer(bytes)) {
    throw new ValidationError('Avatar body must be a raw image payload');
  }
  if (bytes.byteLength === 0) {
    throw new ValidationError('Avatar file is empty');
  }
  if (bytes.byteLength > AVATAR_MAX_BYTES) {
    // 413 Payload Too Large — the client may retry with a smaller file.
    res.status(413).json({
      error: 'PAYLOAD_TOO_LARGE',
      message: 'Avatar exceeds 2 MB limit',
    });
    return;
  }

  const result = await userService.uploadAvatar({
    userId: req.user.id,
    bytes,
    contentType: contentType as AvatarUploadInput['contentType'],
  });
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/me/avatar:
 *   get:
 *     tags: [Me]
 *     summary: Fetch the caller's avatar bytes.
 *     description: |
 *       Streams the stored avatar image with its original content type.
 *       Returns 204 when the caller has no avatar set so the client can
 *       fall through to Gravatar or initials. Cache-Control is private
 *       with a short TTL; the avatarKey rotates on every upload so stale
 *       copies self-heal on refresh.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Avatar bytes. }
 *       204: { description: No avatar set. }
 *       401: { description: Unauthenticated. }
 */
export async function getOwnAvatar(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const result = await userService.getAvatar(req.user.id);
  await streamAvatar(res, result, AVATAR_CACHE_CONTROL);
}

/**
 * @openapi
 * /api/me/password:
 *   post:
 *     tags: [Me]
 *     summary: Change the caller's password.
 *     description: |
 *       Requires the current password (re-verification guards against a
 *       stolen access token). On success all refresh tokens minted before
 *       this call are implicitly revoked — the client should re-login.
 *       Rate-limited (5 attempts / 10 minutes per IP) to throttle brute
 *       force against the current-password check.
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [currentPassword, newPassword]
 *             properties:
 *               currentPassword: { type: string, minLength: 1, maxLength: 128 }
 *               newPassword: { type: string, minLength: 12, maxLength: 128 }
 *     responses:
 *       204: { description: Password updated. }
 *       400: { description: Validation error (too short / same as current). }
 *       401: { description: Unauthenticated or wrong current password. }
 *       429: { description: Rate limited. }
 */
export async function changePassword(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = changePasswordBodySchema.parse(req.body);
  await userService.changePassword(req.user.id, body);
  res.status(204).send();
}

/**
 * @openapi
 * /api/me:
 *   delete:
 *     tags: [Me]
 *     summary: Soft-delete the caller's account.
 *     description: |
 *       The single most destructive action in the API — requires
 *       current-password re-verification. Marks the account as deleted
 *       with a 30-day recovery window; no rows are removed (hard-purge
 *       is a deferred ops cron). After success the client should log out;
 *       existing refresh tokens are invalidated on next refresh, access
 *       tokens expire naturally (max 15 minutes).
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [currentPassword]
 *             properties:
 *               currentPassword: { type: string, minLength: 1, maxLength: 128 }
 *     responses:
 *       204: { description: Account soft-deleted. }
 *       400: { description: Validation error. }
 *       401: { description: Unauthenticated or wrong current password. }
 *       429: { description: Rate limited. }
 */
export async function deleteAccount(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = deleteAccountBodySchema.parse(req.body);
  await userService.softDeleteAccount(req.user.id, body);
  res.status(204).send();
}
