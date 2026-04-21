import '@tests/unit/setup';

// Mock the Redis revocation primitive so the session service's
// best-effort Redis calls don't open a live connection in unit tests.
jest.mock('@/services/refresh-token-store', () => ({
  tryRevokeRefreshJti: jest.fn().mockResolvedValue(true),
  isRefreshJtiRevoked: jest.fn().mockResolvedValue(false),
}));

import {
  createSessionService,
  parseDeviceLabel,
  hashIp,
  SessionInvalidError,
} from '@/services/session.service';
import { tryRevokeRefreshJti } from '@/services/refresh-token-store';

type MockPrisma = {
  session: {
    create: jest.Mock;
    findUnique: jest.Mock;
    findMany: jest.Mock;
    update: jest.Mock;
    updateMany: jest.Mock;
  };
};

function buildMockPrisma(): MockPrisma {
  return {
    session: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
  };
}

describe('parseDeviceLabel', () => {
  it('returns null for null/empty', () => {
    expect(parseDeviceLabel(null)).toBeNull();
    expect(parseDeviceLabel(undefined)).toBeNull();
    expect(parseDeviceLabel('')).toBeNull();
    expect(parseDeviceLabel('   ')).toBeNull();
  });

  it('picks the most specific known token', () => {
    expect(
      parseDeviceLabel('Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36'),
    ).toBe('Android');
    expect(
      parseDeviceLabel('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'),
    ).toBe('iPhone');
    expect(parseDeviceLabel('Mozilla/5.0 (Macintosh; Intel Mac OS X)')).toBe('macOS');
    expect(parseDeviceLabel('Mozilla/5.0 (Windows NT 10.0; Win64; x64)')).toBe(
      'Windows',
    );
    expect(parseDeviceLabel('Dalvik/2.1.0 (Linux; U; Android 14)')).toBe('Android');
    expect(parseDeviceLabel('Mozilla/5.0 (X11; Linux x86_64)')).toBe('Linux');
  });

  it('truncates unknown UAs to 60 chars', () => {
    const weird = 'customCLI/1.0 ' + 'x'.repeat(200);
    const out = parseDeviceLabel(weird);
    expect(out).not.toBeNull();
    expect(out!.length).toBeLessThanOrEqual(60);
  });
});

describe('hashIp', () => {
  it('returns null for null/empty', () => {
    expect(hashIp(null)).toBeNull();
    expect(hashIp(undefined)).toBeNull();
    expect(hashIp('')).toBeNull();
    expect(hashIp('   ')).toBeNull();
  });

  it('is deterministic per (ip, salt)', () => {
    const a = hashIp('1.2.3.4');
    const b = hashIp('1.2.3.4');
    expect(a).toBe(b);
    expect(a).not.toBeNull();
    expect(a).toHaveLength(32);
  });

  it('differs across ips', () => {
    expect(hashIp('1.2.3.4')).not.toBe(hashIp('1.2.3.5'));
  });

  it('never echoes the raw ip back', () => {
    const out = hashIp('10.0.0.1') ?? '';
    expect(out).not.toContain('10');
    expect(out).not.toContain('.');
    expect(out).toMatch(/^[0-9a-f]{32}$/);
  });
});

describe('session.service', () => {
  beforeEach(() => {
    (tryRevokeRefreshJti as jest.Mock).mockReset().mockResolvedValue(true);
  });

  describe('createSession', () => {
    it('persists deviceLabel + ipHash from context', async () => {
      const prisma = buildMockPrisma();
      prisma.session.create.mockResolvedValue({ id: 's1' });
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      await svc.createSession('u1', 'jti-1', {
        userAgent: 'Mozilla/5.0 (Linux; Android 14)',
        ip: '1.2.3.4',
      });

      expect(prisma.session.create).toHaveBeenCalledTimes(1);
      const arg = prisma.session.create.mock.calls[0][0];
      expect(arg.data.userId).toBe('u1');
      expect(arg.data.refreshJti).toBe('jti-1');
      expect(arg.data.deviceLabel).toBe('Android');
      expect(arg.data.ipHash).toMatch(/^[0-9a-f]{32}$/);
    });
  });

  describe('rotate', () => {
    it('throws when old row missing', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findUnique.mockResolvedValue(null);
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      await expect(
        svc.rotate('u1', 'missing-jti', 'new-jti', {}),
      ).rejects.toBeInstanceOf(SessionInvalidError);
    });

    it('throws when row belongs to another user', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'other-user',
        refreshJti: 'old-jti',
        revokedAt: null,
      });
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      await expect(
        svc.rotate('u1', 'old-jti', 'new-jti', {}),
      ).rejects.toBeInstanceOf(SessionInvalidError);
    });

    it('throws when row is already revoked', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        refreshJti: 'old-jti',
        revokedAt: new Date(),
      });
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      await expect(
        svc.rotate('u1', 'old-jti', 'new-jti', {}),
      ).rejects.toBeInstanceOf(SessionInvalidError);
    });

    it('revokes old row and mints a new one on success', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        refreshJti: 'old-jti',
        revokedAt: null,
      });
      prisma.session.update.mockResolvedValue({});
      prisma.session.create.mockResolvedValue({ id: 's2' });
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      const result = await svc.rotate('u1', 'old-jti', 'new-jti', {
        userAgent: 'Mozilla/5.0 (iPhone)',
        ip: '5.6.7.8',
      });
      expect(result.id).toBe('s2');
      expect(prisma.session.update).toHaveBeenCalledTimes(1);
      expect(prisma.session.update.mock.calls[0][0].data.revokedAt).toBeInstanceOf(
        Date,
      );
      const createArg = prisma.session.create.mock.calls[0][0];
      expect(createArg.data.refreshJti).toBe('new-jti');
      expect(createArg.data.deviceLabel).toBe('iPhone');
    });
  });

  describe('listActiveForUser', () => {
    it('flags the current session', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findMany.mockResolvedValue([
        {
          id: 's1',
          deviceLabel: 'Android',
          ipHash: 'deadbeef' + 'cafe'.repeat(6),
          createdAt: new Date(),
          lastSeenAt: new Date(),
        },
        {
          id: 's2',
          deviceLabel: 'macOS',
          ipHash: 'feedface' + 'beef'.repeat(6),
          createdAt: new Date(),
          lastSeenAt: new Date(),
        },
      ]);
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      const result = await svc.listActiveForUser('u1', 's2');
      expect(result).toHaveLength(2);
      expect(result[0].id).toBe('s1');
      expect(result[0].current).toBe(false);
      expect(result[1].id).toBe('s2');
      expect(result[1].current).toBe(true);
      // First 8 chars of the hash only.
      expect(result[0].ipHashPrefix).toBe('deadbeef');
      expect(result[1].ipHashPrefix).toBe('feedface');
    });

    it('treats missing currentSessionId as "no current"', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findMany.mockResolvedValue([
        {
          id: 's1',
          deviceLabel: 'Android',
          ipHash: null,
          createdAt: new Date(),
          lastSeenAt: new Date(),
        },
      ]);
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      const result = await svc.listActiveForUser('u1', undefined);
      expect(result[0].current).toBe(false);
      expect(result[0].ipHashPrefix).toBeNull();
    });
  });

  describe('revokeSessionById', () => {
    it('returns false when session does not belong to user', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'other',
        refreshJti: 'j',
        revokedAt: null,
      });
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      expect(await svc.revokeSessionById('u1', 's1')).toBe(false);
      expect(prisma.session.update).not.toHaveBeenCalled();
    });

    it('revokes + pushes jti to Redis', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        refreshJti: 'jti-1',
        revokedAt: null,
      });
      prisma.session.update.mockResolvedValue({});
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      expect(await svc.revokeSessionById('u1', 's1')).toBe(true);
      expect(prisma.session.update).toHaveBeenCalledTimes(1);
      expect(tryRevokeRefreshJti).toHaveBeenCalledWith('jti-1');
    });

    it('is idempotent when already revoked', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        refreshJti: 'jti-1',
        revokedAt: new Date(),
      });
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      expect(await svc.revokeSessionById('u1', 's1')).toBe(true);
      expect(prisma.session.update).not.toHaveBeenCalled();
    });
  });

  describe('revokeAllOtherSessions', () => {
    it('no-ops when current is the only active session', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findMany.mockResolvedValue([]);
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      expect(await svc.revokeAllOtherSessions('u1', 's-current')).toBe(0);
      expect(prisma.session.updateMany).not.toHaveBeenCalled();
    });

    it('revokes every other row and pushes each jti', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findMany.mockResolvedValue([
        { id: 's2', refreshJti: 'jti-2' },
        { id: 's3', refreshJti: 'jti-3' },
      ]);
      prisma.session.updateMany.mockResolvedValue({ count: 2 });
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      expect(await svc.revokeAllOtherSessions('u1', 's-current')).toBe(2);
      expect(prisma.session.updateMany).toHaveBeenCalledTimes(1);
      expect(tryRevokeRefreshJti).toHaveBeenCalledWith('jti-2');
      expect(tryRevokeRefreshJti).toHaveBeenCalledWith('jti-3');
    });
  });

  describe('revokeAllForUser', () => {
    it('flips every row and pushes every jti', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findMany.mockResolvedValue([
        { id: 's1', refreshJti: 'jti-1' },
        { id: 's2', refreshJti: 'jti-2' },
      ]);
      prisma.session.updateMany.mockResolvedValue({ count: 2 });
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      expect(await svc.revokeAllForUser('u1')).toBe(2);
      expect(tryRevokeRefreshJti).toHaveBeenCalledTimes(2);
    });

    it('no-ops when user has no active sessions', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findMany.mockResolvedValue([]);
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      expect(await svc.revokeAllForUser('u1')).toBe(0);
      expect(prisma.session.updateMany).not.toHaveBeenCalled();
    });
  });

  describe('revokeSessionByJti', () => {
    it('returns false when jti not found', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findUnique.mockResolvedValue(null);
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      expect(await svc.revokeSessionByJti('missing')).toBe(false);
    });

    it('revokes + pushes jti', async () => {
      const prisma = buildMockPrisma();
      prisma.session.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        refreshJti: 'jti-1',
        revokedAt: null,
      });
      prisma.session.update.mockResolvedValue({});
      const svc = createSessionService(
        prisma as unknown as import('@prisma/client').PrismaClient,
      );

      expect(await svc.revokeSessionByJti('jti-1')).toBe(true);
      expect(prisma.session.update).toHaveBeenCalledTimes(1);
      expect(tryRevokeRefreshJti).toHaveBeenCalledWith('jti-1');
    });
  });
});
