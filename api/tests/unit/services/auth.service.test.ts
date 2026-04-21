import '@tests/unit/setup';

jest.mock('@/services/refresh-token-store', () => ({
  tryRevokeRefreshJti: jest.fn().mockResolvedValue(true),
  isRefreshJtiRevoked: jest.fn().mockResolvedValue(false),
}));

import { Prisma } from '@prisma/client';
import { createAuthService } from '@/services/auth.service';
import { ConflictError, UnauthorizedError } from '@/utils/errors';
import { hashPassword } from '@/utils/password';
import { tryRevokeRefreshJti } from '@/services/refresh-token-store';
import {
  SessionInvalidError,
  type SessionService,
} from '@/services/session.service';

// Slice P6 — a minimal in-memory SessionService test double. The unit
// tests don't exercise Prisma; they just need `createSession` +
// `rotate` to return deterministic ids so the auth flow doesn't blow
// up. Tests that want to assert session behaviour directly belong in
// `session.service.test.ts`.
function buildSessionsMock(): jest.Mocked<SessionService> {
  const m: jest.Mocked<SessionService> = {
    createSession: jest
      .fn()
      .mockImplementation(async (_u: string, _j: string) => ({
        id: '00000000-0000-0000-0000-00000000aaaa',
      })),
    rotate: jest.fn().mockImplementation(async (_u: string) => ({
      id: '00000000-0000-0000-0000-00000000bbbb',
    })),
    listActiveForUser: jest.fn().mockResolvedValue([]),
    revokeSessionById: jest.fn().mockResolvedValue(true),
    revokeAllOtherSessions: jest.fn().mockResolvedValue(0),
    revokeAllForUser: jest.fn().mockResolvedValue(0),
    revokeSessionByJti: jest.fn().mockResolvedValue(true),
  };
  return m;
}

type MockPrisma = {
  user: {
    create: jest.Mock;
    findUnique: jest.Mock;
  };
};

function buildMockPrisma(): MockPrisma {
  return {
    user: { create: jest.fn(), findUnique: jest.fn() },
  };
}

const fakeUser = {
  id: '00000000-0000-0000-0000-000000000001',
  email: 'u@example.local',
  role: 'LEARNER' as const,
  displayName: 'U',
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
  passwordHash: '',
  // Slice P1 fields on the Prisma row. `toPublic()` copies these into
  // the PublicUser view.
  avatarKey: null,
  useGravatar: false,
  preferences: null,
  // Slice P5 — soft-delete + password-change bookkeeping fields. All
  // null on a fresh user; the refresh/login gates only engage when any
  // of them are populated.
  passwordChangedAt: null,
  deletedAt: null,
  deletionPurgeAt: null,
  // Slice P7a — MFA state. Off by default; tests that exercise the
  // MFA login gate flip this on and provide an mfaTotp mock.
  mfaEnabled: false,
  mfaBackupCodes: [] as string[],
};

describe('auth.service', () => {
  describe('signup', () => {
    it('creates a user and issues tokens', async () => {
      const prisma = buildMockPrisma();
      prisma.user.create.mockResolvedValue(fakeUser);
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      const result = await svc.signup({
        email: 'u@example.local',
        password: 'CorrectHorseBattery1',
        displayName: 'U',
      });

      expect(prisma.user.create).toHaveBeenCalledTimes(1);
      expect(result.user).toEqual({
        id: fakeUser.id,
        email: fakeUser.email,
        role: fakeUser.role,
        displayName: fakeUser.displayName,
        createdAt: fakeUser.createdAt,
        avatarKey: null,
        useGravatar: false,
        preferences: null,
      });
      expect(result.accessToken).toEqual(expect.any(String));
      expect(result.refreshToken).toEqual(expect.any(String));
    });

    it('maps Prisma P2002 to ConflictError', async () => {
      const prisma = buildMockPrisma();
      const err = Object.assign(new Error('unique'), {
        code: 'P2002',
        clientVersion: '7',
        meta: undefined,
      });
      Object.setPrototypeOf(err, Prisma.PrismaClientKnownRequestError.prototype);
      prisma.user.create.mockRejectedValue(err);
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(
        svc.signup({ email: 'x@example.local', password: 'password1234', displayName: 'X' }),
      ).rejects.toBeInstanceOf(ConflictError);
    });

    it('rethrows unexpected errors', async () => {
      const prisma = buildMockPrisma();
      prisma.user.create.mockRejectedValue(new Error('db down'));
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(
        svc.signup({ email: 'x@example.local', password: 'password1234', displayName: 'X' }),
      ).rejects.toThrow('db down');
    });
  });

  describe('login', () => {
    it('issues tokens on correct password', async () => {
      const prisma = buildMockPrisma();
      const passwordHash = await hashPassword('correctpassword123');
      prisma.user.findUnique.mockResolvedValue({ ...fakeUser, passwordHash });
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      const result = await svc.login({ email: fakeUser.email, password: 'correctpassword123' });
      // Slice P7a — login returns a discriminated union. Narrow with
      // the `mfaPending` tag before asserting on tokens/user. fakeUser
      // has `mfaEnabled === false/undefined`, so we always land on the
      // token branch here.
      if ('mfaPending' in result && result.mfaPending) {
        throw new Error('expected token response, got MFA challenge');
      }
      expect(result.user.id).toBe(fakeUser.id);
    });

    it('throws UnauthorizedError when user is missing', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(null);
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(
        svc.login({ email: 'nope@example.local', password: 'whatever' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('runs bcrypt even when user is missing (timing equivalence)', async () => {
      // When the user lookup misses we must still run bcrypt against a dummy
      // hash so an attacker cannot detect the miss by comparing latencies.
      const bcrypt = jest.requireActual('bcrypt') as typeof import('bcrypt');
      const compareSpy = jest.spyOn(bcrypt, 'compare');
      try {
        const prisma = buildMockPrisma();
        prisma.user.findUnique.mockResolvedValue(null);
        const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );
        await expect(
          svc.login({ email: 'nope@example.local', password: 'anything' }),
        ).rejects.toBeInstanceOf(UnauthorizedError);
        expect(compareSpy).toHaveBeenCalled();
      } finally {
        compareSpy.mockRestore();
      }
    });

    it('throws UnauthorizedError on wrong password', async () => {
      const prisma = buildMockPrisma();
      const passwordHash = await hashPassword('different');
      prisma.user.findUnique.mockResolvedValue({ ...fakeUser, passwordHash });
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(
        svc.login({ email: fakeUser.email, password: 'wrong' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('Slice P5: soft-deleted user -> UnauthorizedError("Invalid credentials") (no enumeration)', async () => {
      const prisma = buildMockPrisma();
      const passwordHash = await hashPassword('correctpassword123');
      prisma.user.findUnique.mockResolvedValue({
        ...fakeUser,
        passwordHash,
        deletedAt: new Date('2026-04-20T00:00:00Z'),
      });
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      // Same generic message as wrong-password — must not leak that the
      // account exists but is deleted.
      const err = await svc
        .login({ email: fakeUser.email, password: 'correctpassword123' })
        .catch((e: unknown) => e);
      expect(err).toBeInstanceOf(UnauthorizedError);
      expect((err as UnauthorizedError).message).toBe('Invalid credentials');
    });
  });

  describe('refresh', () => {
    beforeEach(() => {
      (tryRevokeRefreshJti as jest.Mock).mockReset().mockResolvedValue(true);
    });

    it('issues a new token pair when the revoke wins the race', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(fakeUser);
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      const tokens = await svc.refresh({ userId: fakeUser.id, oldJti: 'old-jti-1' });
      expect(tokens.accessToken).toEqual(expect.any(String));
      expect(tokens.refreshToken).toEqual(expect.any(String));
      expect(tryRevokeRefreshJti).toHaveBeenCalledWith('old-jti-1');
    });

    it('throws when user missing', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(null);
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(
        svc.refresh({ userId: 'missing', oldJti: 'j' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('rejects when the old jti was already revoked (replay loses the atomic race)', async () => {
      (tryRevokeRefreshJti as jest.Mock).mockResolvedValue(false);
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(fakeUser);
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(
        svc.refresh({ userId: fakeUser.id, oldJti: 'already-used' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
      // Guard runs before the user lookup so a confirmed replay doesn't
      // touch Prisma at all.
      expect(prisma.user.findUnique).not.toHaveBeenCalled();
    });

    it('Slice P5: refresh rejects when user is soft-deleted', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue({
        ...fakeUser,
        deletedAt: new Date('2026-04-20T00:00:00Z'),
      });
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(
        svc.refresh({ userId: fakeUser.id, oldJti: 'jti-x', oldIat: 1_700_000_000 }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('Slice P5: refresh rejects when iat predates passwordChangedAt', async () => {
      // passwordChangedAt = 1_700_000_100s; token iat = 1_700_000_000s (100s earlier).
      const passwordChangedAt = new Date(1_700_000_100 * 1000);
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue({
        ...fakeUser,
        passwordChangedAt,
      });
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(
        svc.refresh({ userId: fakeUser.id, oldJti: 'jti-y', oldIat: 1_700_000_000 }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('Slice P5: refresh rejects when iat equals passwordChangedAt (same-second window closed)', async () => {
      // Pathological but very easy to hit in tests and in production when a
      // user signs up and immediately changes their password. The check is
      // `<=` not `<` to close this sliver.
      const passwordChangedAt = new Date(1_700_000_000 * 1000 + 500); // .500s
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue({
        ...fakeUser,
        passwordChangedAt,
      });
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(
        svc.refresh({
          userId: fakeUser.id,
          oldJti: 'jti-same-sec',
          oldIat: 1_700_000_000,
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('Slice P5: refresh accepts when iat is strictly after passwordChangedAt', async () => {
      const passwordChangedAt = new Date(1_700_000_000 * 1000);
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue({
        ...fakeUser,
        passwordChangedAt,
      });
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      const tokens = await svc.refresh({
        userId: fakeUser.id,
        oldJti: 'jti-z',
        oldIat: 1_700_000_001,
      });
      expect(tokens.accessToken).toEqual(expect.any(String));
    });

    // ---------- Slice P6 — session lifecycle ----------

    it('Slice P6: signup mints a Session row (ctx flows through)', async () => {
      const prisma = buildMockPrisma();
      prisma.user.create.mockResolvedValue(fakeUser);
      const sessions = buildSessionsMock();
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        sessions,
      );

      await svc.signup({
        email: 'u@example.local',
        password: 'CorrectHorseBattery1',
        displayName: 'U',
        ctx: { userAgent: 'Mozilla/5.0 (Linux; Android 14)', ip: '1.2.3.4' },
      });

      expect(sessions.createSession).toHaveBeenCalledTimes(1);
      const [uid, jti, ctx] = sessions.createSession.mock.calls[0];
      expect(uid).toBe(fakeUser.id);
      expect(typeof jti).toBe('string');
      expect(ctx).toEqual({
        userAgent: 'Mozilla/5.0 (Linux; Android 14)',
        ip: '1.2.3.4',
      });
    });

    it('Slice P6: login mints a Session row and does NOT revoke others', async () => {
      const prisma = buildMockPrisma();
      const passwordHash = await hashPassword('correctpassword123');
      prisma.user.findUnique.mockResolvedValue({ ...fakeUser, passwordHash });
      const sessions = buildSessionsMock();
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        sessions,
      );

      await svc.login({
        email: fakeUser.email,
        password: 'correctpassword123',
        ctx: { userAgent: 'Mozilla/5.0', ip: '1.2.3.4' },
      });

      expect(sessions.createSession).toHaveBeenCalledTimes(1);
      expect(sessions.revokeAllForUser).not.toHaveBeenCalled();
    });

    it('Slice P6: refresh rotates the session row', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(fakeUser);
      const sessions = buildSessionsMock();
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        sessions,
      );

      await svc.refresh({ userId: fakeUser.id, oldJti: 'old-jti', ctx: {} });

      expect(sessions.rotate).toHaveBeenCalledTimes(1);
      const [uid, oldJti, newJti] = sessions.rotate.mock.calls[0];
      expect(uid).toBe(fakeUser.id);
      expect(oldJti).toBe('old-jti');
      expect(typeof newJti).toBe('string');
      expect(newJti).not.toBe(oldJti);
    });

    it('Slice P6: refresh rejects when session row is invalid', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(fakeUser);
      const sessions = buildSessionsMock();
      sessions.rotate.mockRejectedValueOnce(
        new SessionInvalidError('Session revoked'),
      );
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        sessions,
      );

      await expect(
        svc.refresh({ userId: fakeUser.id, oldJti: 'old-jti' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('findById', () => {
    it('returns public user on hit', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(fakeUser);
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      const u = await svc.findById(fakeUser.id);
      expect(u.email).toBe(fakeUser.email);
    });

    it('throws on miss', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(null);
      const svc = createAuthService(
        prisma as unknown as import('@prisma/client').PrismaClient,
        buildSessionsMock(),
      );

      await expect(svc.findById('missing')).rejects.toBeInstanceOf(UnauthorizedError);
    });
  });
});
