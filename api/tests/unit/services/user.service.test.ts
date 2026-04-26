import '@tests/unit/setup';
import * as fs from 'node:fs';
import * as path from 'node:path';
import sharp from 'sharp';
import type { PrismaClient } from '@prisma/client';
import {
  createUserService,
  AVATAR_MAX_BYTES,
  ACCOUNT_DELETION_GRACE_DAYS,
} from '@/services/user.service';
import { NotFoundError, UnauthorizedError, ValidationError } from '@/utils/errors';
import { hashPassword } from '@/utils/password';
import type { ObjectStore } from '@/services/object-store';
import type { SessionService } from '@/services/session.service';

// ---------------------------------------------------------------------------
// Real image fixtures — tiny but decodable by sharp. These are pre-generated
// in tests/fixtures/avatars/ so test runs don't invoke sharp during setup.
// ---------------------------------------------------------------------------
const FIXTURES_DIR = path.resolve(__dirname, '../../fixtures/avatars');

function loadFixture(name: string): Buffer {
  return fs.readFileSync(path.join(FIXTURES_DIR, name));
}

// Loaded once at module level — synchronous reads of tiny files are fine in
// a test module initialiser and avoids a beforeAll async gate.
const JPEG_BYTES = loadFixture('plain.jpg');
const PNG_BYTES = loadFixture('plain.png');
const WEBP_BYTES = loadFixture('plain.webp');
const EXIF_JPEG_BYTES = loadFixture('with-exif.jpg');

// Slice P6 — user.service calls `sessions.revokeAllForUser(userId)`
// on password change + soft delete. Tests here mock the service and
// assert the call is made; session-level behaviour has its own suite.
function buildMockSessions(): jest.Mocked<SessionService> {
  return {
    createSession: jest.fn(),
    rotate: jest.fn(),
    listActiveForUser: jest.fn().mockResolvedValue([]),
    revokeSessionById: jest.fn().mockResolvedValue(true),
    revokeAllOtherSessions: jest.fn().mockResolvedValue(0),
    revokeAllForUser: jest.fn().mockResolvedValue(0),
    revokeSessionByJti: jest.fn().mockResolvedValue(true),
  };
}

type MockPrisma = {
  user: {
    findUnique: jest.Mock;
    update: jest.Mock;
  };
};

function buildMockPrisma(): MockPrisma {
  return {
    user: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
  };
}

function baseUserRow(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: USER_ID,
    email: 'u@example.local',
    role: 'LEARNER',
    displayName: 'U',
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
    passwordHash: '',
    avatarKey: null,
    useGravatar: false,
    preferences: null,
    passwordChangedAt: null,
    deletedAt: null,
    deletionPurgeAt: null,
    ...overrides,
  };
}

type MockObjectStore = {
  downloadToFile: jest.Mock;
  uploadFile: jest.Mock;
  uploadDirectory: jest.Mock;
  deleteObject: jest.Mock;
  putObject: jest.Mock;
  getObjectStream: jest.Mock;
};

function buildMockObjectStore(): MockObjectStore {
  return {
    downloadToFile: jest.fn().mockResolvedValue(undefined),
    uploadFile: jest.fn().mockResolvedValue(undefined),
    uploadDirectory: jest.fn().mockResolvedValue({ uploaded: 0 }),
    deleteObject: jest.fn().mockResolvedValue(undefined),
    // Optional fast-path our service detects at runtime.
    putObject: jest.fn().mockResolvedValue(undefined),
    getObjectStream: jest.fn(),
  };
}

const USER_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

function baseRow(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: USER_ID,
    email: 'u@example.local',
    role: 'LEARNER',
    displayName: 'Old Name',
    createdAt: new Date('2026-01-01T00:00:00Z'),
    avatarKey: null,
    useGravatar: false,
    preferences: null,
    ...overrides,
  };
}

describe('user.service', () => {
  describe('updateMe', () => {
    it('updates displayName and returns PrivateUser shape', async () => {
      const prisma = buildMockPrisma();
      prisma.user.update.mockResolvedValueOnce(
        baseRow({ displayName: 'New Name' }),
      );
      const svc = createUserService(prisma as unknown as PrismaClient);

      const res = await svc.updateMe(USER_ID, { displayName: 'New Name' });
      expect(res.displayName).toBe('New Name');
      expect(res.useGravatar).toBe(false);
      expect(res.preferences).toBeNull();
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: USER_ID },
        data: { displayName: 'New Name' },
      });
    });

    it('updates useGravatar + preferences in one call', async () => {
      const prisma = buildMockPrisma();
      prisma.user.update.mockResolvedValueOnce(
        baseRow({ useGravatar: true, preferences: { theme: 'dark' } }),
      );
      const svc = createUserService(prisma as unknown as PrismaClient);

      const res = await svc.updateMe(USER_ID, {
        useGravatar: true,
        preferences: { theme: 'dark' },
      });
      expect(res.useGravatar).toBe(true);
      expect(res.preferences).toEqual({ theme: 'dark' });
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: USER_ID },
        data: {
          useGravatar: true,
          preferences: { theme: 'dark' },
        },
      });
    });

    it('empty patch short-circuits to findUnique (idempotent no-op)', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(baseRow());
      const svc = createUserService(prisma as unknown as PrismaClient);

      const res = await svc.updateMe(USER_ID, {});
      expect(res.id).toBe(USER_ID);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('empty patch + missing user -> NotFoundError', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(null);
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(svc.updateMe(USER_ID, {})).rejects.toBeInstanceOf(
        NotFoundError,
      );
    });

    it('rejected fields: email/role/id/passwordHash never reach Prisma', async () => {
      // The Zod validator strips unknown keys before calling the service,
      // but callers with type-any can still smuggle keys in. We prove
      // the service ignores them explicitly — only the allow-listed keys
      // of UpdateMeInput are propagated.
      const prisma = buildMockPrisma();
      prisma.user.update.mockResolvedValueOnce(baseRow({ displayName: 'Z' }));
      const svc = createUserService(prisma as unknown as PrismaClient);

      await svc.updateMe(USER_ID, {
        displayName: 'Z',
        // Cast to any: these keys aren't part of UpdateMeInput, but a caller
        // with a loose type could try to smuggle them in. We prove the
        // service's internal allow-list drops them before reaching Prisma.
        ...(({ email: 'hack@example.local', role: 'ADMIN' }) as unknown as Record<string, unknown>),
      });
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: USER_ID },
        data: { displayName: 'Z' },
      });
    });
  });

  describe('uploadAvatar', () => {
    it('writes to object store, persists key, returns shape', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce({ avatarKey: null });
      prisma.user.update.mockResolvedValueOnce(
        baseRow({ avatarKey: 'avatars/xyz/abc.jpg' }),
      );
      const store = buildMockObjectStore();
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        store as unknown as ObjectStore,
      );

      const res = await svc.uploadAvatar({
        userId: USER_ID,
        bytes: JPEG_BYTES,
        contentType: 'image/jpeg',
      });
      expect(res.avatarKey).toMatch(/^avatars\/[^/]+\/[^/]+\.jpg$/);
      // Media-serving route shipped; avatarUrl now points at it so the
      // client doesn't need to reason about the storage key.
      expect(res.avatarUrl).toBe('/api/me/avatar');
      expect(store.putObject).toHaveBeenCalledTimes(1);
      expect(store.deleteObject).not.toHaveBeenCalled();
    });

    it('deletes previous avatar best-effort after new upload succeeds', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce({
        avatarKey: 'avatars/old/old.png',
      });
      prisma.user.update.mockResolvedValueOnce(
        baseRow({ avatarKey: 'avatars/new/new.png' }),
      );
      const store = buildMockObjectStore();
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        store as unknown as ObjectStore,
      );

      await svc.uploadAvatar({
        userId: USER_ID,
        bytes: PNG_BYTES,
        contentType: 'image/png',
      });
      // Deletion is fire-and-forget; wait a tick for the promise chain.
      await Promise.resolve();
      expect(store.deleteObject).toHaveBeenCalledWith(
        expect.any(String),
        'avatars/old/old.png',
      );
    });

    it('swallows deleteObject errors (best-effort cleanup)', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce({
        avatarKey: 'avatars/old/old.webp',
      });
      prisma.user.update.mockResolvedValueOnce(
        baseRow({ avatarKey: 'avatars/new/new.webp' }),
      );
      const store = buildMockObjectStore();
      store.deleteObject.mockRejectedValueOnce(new Error('boom'));
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        store as unknown as ObjectStore,
      );

      await expect(
        svc.uploadAvatar({
          userId: USER_ID,
          bytes: WEBP_BYTES,
          contentType: 'image/webp',
        }),
      ).resolves.toBeDefined();
    });

    it('empty bytes -> ValidationError', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        store as unknown as ObjectStore,
      );
      await expect(
        svc.uploadAvatar({
          userId: USER_ID,
          bytes: Buffer.alloc(0),
          contentType: 'image/png',
        }),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('oversize bytes -> ValidationError (belt + braces; route also caps)', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        store as unknown as ObjectStore,
      );
      await expect(
        svc.uploadAvatar({
          userId: USER_ID,
          bytes: Buffer.alloc(AVATAR_MAX_BYTES + 1),
          contentType: 'image/jpeg',
        }),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('strips EXIF from a JPEG that contains metadata', async () => {
      // Verify the fixture actually has EXIF before the test runs.
      const fixtureMeta = await sharp(EXIF_JPEG_BYTES).metadata();
      expect(fixtureMeta.exif).toBeDefined();

      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce({ avatarKey: null });
      prisma.user.update.mockResolvedValueOnce(
        baseRow({ avatarKey: 'avatars/xyz/abc.jpg' }),
      );
      const store = buildMockObjectStore();
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        store as unknown as ObjectStore,
      );

      await svc.uploadAvatar({
        userId: USER_ID,
        bytes: EXIF_JPEG_BYTES,
        contentType: 'image/jpeg',
      });

      // The object store should have been called with the sanitized bytes —
      // inspect the buffer captured by the mock's putObject call.
      expect(store.putObject).toHaveBeenCalledTimes(1);
      const capturedBytes: Buffer = store.putObject.mock.calls[0][2] as Buffer;
      const strippedMeta = await sharp(capturedBytes).metadata();
      // Sharp omits the `exif` key entirely when no EXIF is present.
      expect(strippedMeta.exif).toBeUndefined();
    });

    it('non-image buffer -> ValidationError (sharp cannot decode)', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        store as unknown as ObjectStore,
      );
      await expect(
        svc.uploadAvatar({
          userId: USER_ID,
          bytes: Buffer.from('not an image'),
          contentType: 'image/jpeg',
        }),
      ).rejects.toBeInstanceOf(ValidationError);
      // No upload should have occurred.
      expect(store.putObject).not.toHaveBeenCalled();
    });
  });

  describe('getAvatar', () => {
    it('returns the object stream when the user has an avatarKey', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce({
        avatarKey: 'avatars/u/abc.png',
      });
      const store = buildMockObjectStore();
      const { Readable } = await import('node:stream');
      const fakeStream = Readable.from([Buffer.from('png')]);
      store.getObjectStream.mockResolvedValueOnce({
        stream: fakeStream,
        contentType: 'image/png',
        contentLength: 3,
      });
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        store as unknown as ObjectStore,
      );

      const res = await svc.getAvatar(USER_ID);
      expect(res).not.toBeNull();
      expect(res?.contentType).toBe('image/png');
      expect(res?.contentLength).toBe(3);
      expect(res?.stream).toBe(fakeStream);
      // Confirm the right bucket+key is consulted — the service reads
      // `env.S3_UPLOAD_BUCKET` so we just assert the stored key flows through.
      expect(store.getObjectStream).toHaveBeenCalledWith(
        expect.any(String),
        'avatars/u/abc.png',
      );
    });

    it('returns null when the user exists but has no avatarKey', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce({ avatarKey: null });
      const store = buildMockObjectStore();
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        store as unknown as ObjectStore,
      );

      const res = await svc.getAvatar(USER_ID);
      expect(res).toBeNull();
      expect(store.getObjectStream).not.toHaveBeenCalled();
    });

    it('throws NotFoundError when the user does not exist', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(null);
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(svc.getAvatar(USER_ID)).rejects.toBeInstanceOf(
        NotFoundError,
      );
    });
  });

  // ---------- Slice P5 ----------
  describe('changePassword', () => {
    it('happy path: writes a new bcrypt hash and bumps passwordChangedAt', async () => {
      const prisma = buildMockPrisma();
      const existingHash = await hashPassword('CurrentPass1234');
      prisma.user.findUnique.mockResolvedValueOnce(
        baseUserRow({ passwordHash: existingHash }),
      );
      prisma.user.update.mockResolvedValueOnce(baseUserRow());
      const sessions = buildMockSessions();
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        undefined,
        sessions,
      );

      await svc.changePassword(USER_ID, {
        currentPassword: 'CurrentPass1234',
        newPassword: 'BrandNewPass5678',
      });

      expect(prisma.user.update).toHaveBeenCalledTimes(1);
      const call = prisma.user.update.mock.calls[0][0] as {
        where: { id: string };
        data: { passwordHash: string; passwordChangedAt: Date };
      };
      expect(call.where).toEqual({ id: USER_ID });
      // Hashing actually happened — a bcrypt hash has the `$2b$` (or
      // `$2a$`) prefix. Proves the service didn't pass through plaintext.
      expect(call.data.passwordHash).toMatch(/^\$2[aby]\$/);
      expect(call.data.passwordHash).not.toBe('BrandNewPass5678');
      // `passwordChangedAt` bumped to "now".
      expect(call.data.passwordChangedAt).toBeInstanceOf(Date);
      expect(
        Date.now() - call.data.passwordChangedAt.getTime(),
      ).toBeLessThan(5000);
      // Slice P6 — password change flips every Session row to revoked.
      expect(sessions.revokeAllForUser).toHaveBeenCalledWith(USER_ID);
    });

    it('wrong current password -> UnauthorizedError (no DB write)', async () => {
      const prisma = buildMockPrisma();
      const existingHash = await hashPassword('CurrentPass1234');
      prisma.user.findUnique.mockResolvedValueOnce(
        baseUserRow({ passwordHash: existingHash }),
      );
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(
        svc.changePassword(USER_ID, {
          currentPassword: 'WrongGuess1234',
          newPassword: 'BrandNewPass5678',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('new password < 12 chars -> ValidationError (no DB write)', async () => {
      const prisma = buildMockPrisma();
      const existingHash = await hashPassword('CurrentPass1234');
      prisma.user.findUnique.mockResolvedValueOnce(
        baseUserRow({ passwordHash: existingHash }),
      );
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(
        svc.changePassword(USER_ID, {
          currentPassword: 'CurrentPass1234',
          newPassword: 'short',
        }),
      ).rejects.toBeInstanceOf(ValidationError);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('new password equals current -> ValidationError', async () => {
      const prisma = buildMockPrisma();
      const existingHash = await hashPassword('CurrentPass1234');
      prisma.user.findUnique.mockResolvedValueOnce(
        baseUserRow({ passwordHash: existingHash }),
      );
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(
        svc.changePassword(USER_ID, {
          currentPassword: 'CurrentPass1234',
          newPassword: 'CurrentPass1234',
        }),
      ).rejects.toBeInstanceOf(ValidationError);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('missing user -> UnauthorizedError', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(null);
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(
        svc.changePassword(USER_ID, {
          currentPassword: 'CurrentPass1234',
          newPassword: 'BrandNewPass5678',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('already-deleted user -> UnauthorizedError (no DB write)', async () => {
      const prisma = buildMockPrisma();
      const existingHash = await hashPassword('CurrentPass1234');
      prisma.user.findUnique.mockResolvedValueOnce(
        baseUserRow({
          passwordHash: existingHash,
          deletedAt: new Date('2026-04-20T00:00:00Z'),
        }),
      );
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(
        svc.changePassword(USER_ID, {
          currentPassword: 'CurrentPass1234',
          newPassword: 'BrandNewPass5678',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });
  });

  describe('softDeleteAccount', () => {
    it('happy path: sets deletedAt + deletionPurgeAt + passwordChangedAt', async () => {
      const prisma = buildMockPrisma();
      const existingHash = await hashPassword('CurrentPass1234');
      prisma.user.findUnique.mockResolvedValueOnce(
        baseUserRow({ passwordHash: existingHash }),
      );
      prisma.user.update.mockResolvedValueOnce(baseUserRow());
      const sessions = buildMockSessions();
      const svc = createUserService(
        prisma as unknown as PrismaClient,
        undefined,
        sessions,
      );

      const before = Date.now();
      await svc.softDeleteAccount(USER_ID, {
        currentPassword: 'CurrentPass1234',
      });
      const after = Date.now();

      expect(prisma.user.update).toHaveBeenCalledTimes(1);
      const call = prisma.user.update.mock.calls[0][0] as {
        where: { id: string };
        data: {
          deletedAt: Date;
          deletionPurgeAt: Date;
          passwordChangedAt: Date;
        };
      };
      expect(call.where).toEqual({ id: USER_ID });

      // deletedAt ~= now
      expect(call.data.deletedAt).toBeInstanceOf(Date);
      expect(call.data.deletedAt.getTime()).toBeGreaterThanOrEqual(before);
      expect(call.data.deletedAt.getTime()).toBeLessThanOrEqual(after);

      // deletionPurgeAt = deletedAt + 30 days (± 1s tolerance for clock drift
      // between the two `new Date()` calls — the service constructs them
      // from separate `Date.now()` reads).
      const expectedPurge =
        call.data.deletedAt.getTime() +
        ACCOUNT_DELETION_GRACE_DAYS * 24 * 60 * 60 * 1000;
      expect(
        Math.abs(call.data.deletionPurgeAt.getTime() - expectedPurge),
      ).toBeLessThan(1000);

      // passwordChangedAt bumped too — ensures any lingering refresh
      // token fails on its next rotation (belt and braces over the
      // deletedAt check in auth.service).
      expect(call.data.passwordChangedAt).toBeInstanceOf(Date);
      // Slice P6 — every Session row for this user is revoked too, so
      // GET /api/me/sessions reads empty immediately after deletion.
      expect(sessions.revokeAllForUser).toHaveBeenCalledWith(USER_ID);
    });

    it('wrong current password -> UnauthorizedError (no DB write)', async () => {
      const prisma = buildMockPrisma();
      const existingHash = await hashPassword('CurrentPass1234');
      prisma.user.findUnique.mockResolvedValueOnce(
        baseUserRow({ passwordHash: existingHash }),
      );
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(
        svc.softDeleteAccount(USER_ID, { currentPassword: 'wrong-guess' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('already-deleted user -> UnauthorizedError (idempotent refusal)', async () => {
      const prisma = buildMockPrisma();
      const existingHash = await hashPassword('CurrentPass1234');
      prisma.user.findUnique.mockResolvedValueOnce(
        baseUserRow({
          passwordHash: existingHash,
          deletedAt: new Date('2026-04-20T00:00:00Z'),
        }),
      );
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(
        svc.softDeleteAccount(USER_ID, {
          currentPassword: 'CurrentPass1234',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('missing user -> UnauthorizedError', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(null);
      const svc = createUserService(prisma as unknown as PrismaClient);

      await expect(
        svc.softDeleteAccount(USER_ID, {
          currentPassword: 'CurrentPass1234',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });
  });
});
