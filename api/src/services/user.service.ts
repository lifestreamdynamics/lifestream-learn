import { randomUUID } from 'node:crypto';
import type { Prisma, PrismaClient } from '@prisma/client';
import sharp from 'sharp';
import { prisma as defaultPrisma } from '@/config/prisma';
import { NotFoundError, ValidationError } from '@/utils/errors';
import type { ObjectStore, ObjectStreamResult } from '@/services/object-store';
import { objectStore as defaultObjectStore } from '@/services/object-store';
import { uploadBytes } from '@/utils/object-store-utils';
import { env } from '@/config/env';
import type { PublicUser } from '@/services/auth.service';
import { hashPassword, requireCurrentPassword } from '@/utils/password';
import {
  sessionService as defaultSessionService,
  type SessionService,
} from '@/services/session.service';

/**
 * Slice P5 — account-deletion recovery window. After soft-delete the row
 * stays in the DB with `deletedAt`/`deletionPurgeAt` set; the operator
 * has 30 days to restore it before a (future) ops cron hard-purges. The
 * window is centralised here so tests and the deletion endpoint stay in
 * sync.
 */
export const ACCOUNT_DELETION_GRACE_DAYS = 30;

/**
 * Slice P5 — minimum length for a password chosen via POST /api/me/password.
 * Matches the signup rule in `auth.validators.ts`; exported here so the
 * service boundary can be tested directly.
 */
export const PASSWORD_MIN_LENGTH = 12;

/**
 * The "private" user view returned by `/api/me` endpoints. Same shape as
 * `PublicUser` today — we may diverge later (e.g. to include MFA state
 * or deletion flags), so the alias keeps the call-sites decoupled from
 * auth's public view.
 */
export type PrivateUser = PublicUser;

export interface UpdateMeInput {
  displayName?: string;
  useGravatar?: boolean;
  preferences?: Record<string, unknown>;
}

export interface AvatarUploadInput {
  userId: string;
  bytes: Buffer;
  contentType: 'image/jpeg' | 'image/png' | 'image/webp';
}

export interface ChangePasswordInput {
  currentPassword: string;
  newPassword: string;
}

export interface DeleteAccountInput {
  currentPassword: string;
}

export interface AvatarUploadResult {
  avatarKey: string;
  /**
   * Relative display URL pointing at the media-serving route. Clients
   * absolute-ify against the API base URL. The indirection keeps the
   * storage layout private and gives us a single seam to front with a
   * CDN later without touching every client call-site.
   */
  avatarUrl: string;
}

/**
 * Public path for the caller's own avatar. Kept as a module constant so
 * the controller, service return shape, and client-side expectations
 * all agree on a single source of truth.
 */
export const OWN_AVATAR_URL = '/api/me/avatar';

// Hard caps on avatar bytes (mirrors the multipart guard). Kept as a
// module constant so the service boundary can be tested without
// round-tripping through the controller's content-length check.
export const AVATAR_MAX_BYTES = 2 * 1024 * 1024;

const CONTENT_TYPE_TO_EXT: Record<AvatarUploadInput['contentType'], string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

/**
 * Strip all metadata (including EXIF GPS coordinates) from an image buffer
 * and re-encode it in the same format. The `.rotate()` call bakes EXIF
 * orientation into pixel data before the metadata is discarded so the image
 * does not visibly rotate. Sharp omits all metadata by default; we never call
 * `.withMetadata()`, which is the desired behaviour.
 *
 * Throws [ValidationError] for any payload that sharp cannot decode (truncated,
 * malformed, or unsupported format), so callers receive a 400 rather than a 500.
 */
async function stripImageMetadata(
  bytes: Buffer,
  contentType: AvatarUploadInput['contentType'],
): Promise<Buffer> {
  try {
    const pipeline = sharp(bytes, { failOn: 'truncated' }).rotate();
    let out: Buffer;
    if (contentType === 'image/jpeg') {
      out = await pipeline.jpeg({ quality: 85, mozjpeg: true }).toBuffer();
    } else if (contentType === 'image/png') {
      out = await pipeline.png().toBuffer();
    } else {
      out = await pipeline.webp({ quality: 85 }).toBuffer();
    }
    return out;
  } catch {
    throw new ValidationError('Avatar image could not be processed');
  }
}

function toPrivate(u: {
  id: string;
  email: string;
  role: PrivateUser['role'];
  displayName: string;
  createdAt: Date;
  avatarKey: string | null;
  useGravatar: boolean;
  preferences: Prisma.JsonValue | null;
}): PrivateUser {
  return {
    id: u.id,
    email: u.email,
    role: u.role,
    displayName: u.displayName,
    createdAt: u.createdAt,
    avatarKey: u.avatarKey,
    useGravatar: u.useGravatar,
    preferences: u.preferences ?? null,
  };
}

export interface UserService {
  /**
   * Apply a profile patch to the caller's own user row. Email + role
   * are deliberately not accepted here — email changes need a verify
   * flow (later slice) and role changes are admin-only.
   */
  updateMe(userId: string, patch: UpdateMeInput): Promise<PrivateUser>;
  /**
   * Upload a new avatar. Writes to `S3_UPLOAD_BUCKET` under
   * `avatars/<userId>/<uuid>.<ext>`, persists the key, and deletes any
   * previous avatar best-effort. Returns the new key + the relative
   * display URL clients should compose against the API base URL.
   */
  uploadAvatar(input: AvatarUploadInput): Promise<AvatarUploadResult>;
  /**
   * Fetch the stored avatar bytes for a user as a stream. Returns
   * `null` when the user exists but has no avatarKey — the controller
   * maps that to 204 so the client cleanly falls through to Gravatar
   * / initials. Throws [NotFoundError] when the user itself doesn't
   * exist (deliberately 404, not 403, to avoid account enumeration).
   */
  getAvatar(userId: string): Promise<ObjectStreamResult | null>;
  /**
   * Slice P5 — change the caller's password. Requires current-password
   * re-verification. On success: hashes + writes the new password and
   * bumps `passwordChangedAt`, which implicitly revokes every refresh
   * token minted before this call.
   */
  changePassword(userId: string, input: ChangePasswordInput): Promise<void>;
  /**
   * Slice P5 — soft-delete the caller's account. Requires current-password
   * re-verification (a stolen access token alone must not nuke the
   * account). Sets `deletedAt = now()`, `deletionPurgeAt = now() + 30d`,
   * and bumps `passwordChangedAt` so existing refresh tokens stop working
   * on the next refresh. No rows are removed; hard-purge is a deferred
   * ops cron.
   */
  softDeleteAccount(userId: string, input: DeleteAccountInput): Promise<void>;
}

export function createUserService(
  prisma: PrismaClient = defaultPrisma,
  objectStore: ObjectStore = defaultObjectStore,
  sessions: SessionService = defaultSessionService,
): UserService {
  return {
    async updateMe(userId, patch) {
      // Build a Prisma data object that only includes the keys the caller
      // actually set — this preserves nulls vs. "field absent" and lets
      // us short-circuit the no-op case below.
      const data: Prisma.UserUpdateInput = {};
      if (patch.displayName !== undefined) data.displayName = patch.displayName;
      if (patch.useGravatar !== undefined) data.useGravatar = patch.useGravatar;
      if (patch.preferences !== undefined) {
        data.preferences = patch.preferences as Prisma.InputJsonValue;
      }

      if (Object.keys(data).length === 0) {
        // Nothing to update. Return the current row rather than bouncing
        // a 400 — idempotent PATCH semantics.
        const current = await prisma.user.findUnique({ where: { id: userId } });
        if (!current) throw new NotFoundError('User not found');
        return toPrivate(current);
      }

      // Prisma throws P2025 when the row doesn't exist; the global
      // error handler maps that to 404. The authenticated user should
      // always exist at this point, so we rely on the global handler.
      const updated = await prisma.user.update({
        where: { id: userId },
        data,
      });
      return toPrivate(updated);
    },

    async uploadAvatar({ userId, bytes, contentType }) {
      if (bytes.byteLength === 0) {
        throw new ValidationError('Avatar file is empty');
      }
      // Cap incoming bytes before handing to sharp (defense-in-depth;
      // the route middleware already enforces this at the HTTP layer).
      if (bytes.byteLength > AVATAR_MAX_BYTES) {
        throw new ValidationError('Avatar exceeds 2 MB limit');
      }
      const ext = CONTENT_TYPE_TO_EXT[contentType];
      if (!ext) {
        throw new ValidationError('Unsupported avatar content type');
      }

      // Strip EXIF (including GPS coordinates) and re-encode. Runs before
      // the upload so no raw metadata ever reaches object storage.
      const sanitized = await stripImageMetadata(bytes, contentType);

      // Also cap the re-encoded output — pathological inputs can inflate
      // after re-encoding, and we must not persist oversized objects.
      if (sanitized.byteLength > AVATAR_MAX_BYTES) {
        throw new ValidationError('Avatar exceeds 2 MB limit after processing');
      }

      const key = `avatars/${userId}/${randomUUID()}.${ext}`;

      // Upload before we persist the key — so if the upload fails we
      // don't end up with a User row pointing at a non-existent object.
      await uploadBytes(objectStore, env.S3_UPLOAD_BUCKET, key, sanitized, contentType);

      const previousKey = await prisma.user
        .findUnique({ where: { id: userId }, select: { avatarKey: true } })
        .then((u) => u?.avatarKey ?? null);

      const updated = await prisma.user.update({
        where: { id: userId },
        data: { avatarKey: key },
      });

      if (previousKey && previousKey !== key) {
        // Best-effort cleanup. We've already committed the new key, so a
        // failure here is cosmetic (orphaned object, garbage-collectable
        // later). Never let it fail the request.
        objectStore
          .deleteObject(env.S3_UPLOAD_BUCKET, previousKey)
          .catch(() => {
            // Swallow — see comment above.
          });
      }

      // `updated.avatarKey` is guaranteed non-null — we just wrote it
      // above — but Prisma's return type is `string | null`, so fall
      // back to the locally-generated key to keep TS + eslint happy
      // without a bang.
      return {
        avatarKey: updated.avatarKey ?? key,
        avatarUrl: OWN_AVATAR_URL,
      };
    },

    async getAvatar(userId) {
      const row = await prisma.user.findUnique({
        where: { id: userId },
        select: { avatarKey: true },
      });
      if (!row) throw new NotFoundError('User not found');
      if (!row.avatarKey) return null;
      return objectStore.getObjectStream(env.S3_UPLOAD_BUCKET, row.avatarKey);
    },

    async changePassword(userId, { currentPassword, newPassword }) {
      // `requireCurrentPassword` handles the missing-user / soft-deleted /
      // wrong-password cases uniformly so the constant-shape error
      // invariant stays single-source across every destructive path.
      await requireCurrentPassword(prisma, userId, currentPassword);

      // Length + "must differ" checks. Both live in the service (not only
      // the Zod validator) so the service boundary holds the invariant
      // on its own — unit tests don't need to go through the HTTP layer
      // to prove them.
      if (newPassword.length < PASSWORD_MIN_LENGTH) {
        throw new ValidationError(
          `New password must be at least ${PASSWORD_MIN_LENGTH} characters`,
        );
      }
      if (newPassword === currentPassword) {
        throw new ValidationError('New password must differ from current');
      }

      const passwordHash = await hashPassword(newPassword);
      await prisma.user.update({
        where: { id: userId },
        // Bump `passwordChangedAt` in the same write so
        // `authService.refresh` can cheaply reject any refresh token
        // whose `iat` is strictly before this timestamp — standard
        // "password change invalidates sessions" without a Session table.
        data: { passwordHash, passwordChangedAt: new Date() },
      });
      // Slice P6 — belt-and-braces: `passwordChangedAt` already blocks
      // the next refresh, but flipping every Session row to revoked
      // gives the user a truthful "0 active sessions" view immediately
      // after the change, without waiting for refresh attempts to cull
      // them. Also pushes each jti into the Redis revocation set so
      // already-queued refresh calls 401 fast.
      await sessions.revokeAllForUser(userId);
    },

    async softDeleteAccount(userId, { currentPassword }) {
      // A stolen access token alone must not delete the account; a
      // second-delete attempt on an already-deleted row is idempotent
      // but surfaces as "wrong password" so the flow stays constant-shape.
      // `requireCurrentPassword` centralises that invariant.
      await requireCurrentPassword(prisma, userId, currentPassword);

      const now = new Date();
      const purgeAt = new Date(
        now.getTime() + ACCOUNT_DELETION_GRACE_DAYS * 24 * 60 * 60 * 1000,
      );

      await prisma.user.update({
        where: { id: userId },
        data: {
          deletedAt: now,
          deletionPurgeAt: purgeAt,
          // Bumping `passwordChangedAt` here means the next refresh
          // attempt from any lingering client is rejected even before
          // the `deletedAt` check — belt and braces, and keeps the
          // refresh-time check single-purpose.
          passwordChangedAt: now,
        },
      });
      // Slice P6 — revoke every Session row for the deleted user so
      // the sessions list reads empty immediately and the Redis
      // revocation set short-circuits any concurrent refresh.
      await sessions.revokeAllForUser(userId);
    },
  };
}

export const userService = createUserService();
