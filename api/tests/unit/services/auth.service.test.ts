import '@tests/unit/setup';
import { Prisma } from '@prisma/client';
import { createAuthService } from '@/services/auth.service';
import { ConflictError, UnauthorizedError } from '@/utils/errors';
import { hashPassword } from '@/utils/password';

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
};

describe('auth.service', () => {
  describe('signup', () => {
    it('creates a user and issues tokens', async () => {
      const prisma = buildMockPrisma();
      prisma.user.create.mockResolvedValue(fakeUser);
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

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
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

      await expect(
        svc.signup({ email: 'x@example.local', password: 'password1234', displayName: 'X' }),
      ).rejects.toBeInstanceOf(ConflictError);
    });

    it('rethrows unexpected errors', async () => {
      const prisma = buildMockPrisma();
      prisma.user.create.mockRejectedValue(new Error('db down'));
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

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
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

      const result = await svc.login({ email: fakeUser.email, password: 'correctpassword123' });
      expect(result.user.id).toBe(fakeUser.id);
    });

    it('throws UnauthorizedError when user is missing', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(null);
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

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
        const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);
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
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

      await expect(
        svc.login({ email: fakeUser.email, password: 'wrong' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('refresh', () => {
    it('issues a new token pair', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(fakeUser);
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

      const tokens = await svc.refresh(fakeUser.id);
      expect(tokens.accessToken).toEqual(expect.any(String));
      expect(tokens.refreshToken).toEqual(expect.any(String));
    });

    it('throws when user missing', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(null);
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

      await expect(svc.refresh('missing')).rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('findById', () => {
    it('returns public user on hit', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(fakeUser);
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

      const u = await svc.findById(fakeUser.id);
      expect(u.email).toBe(fakeUser.email);
    });

    it('throws on miss', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValue(null);
      const svc = createAuthService(prisma as unknown as import('@prisma/client').PrismaClient);

      await expect(svc.findById('missing')).rejects.toBeInstanceOf(UnauthorizedError);
    });
  });
});
