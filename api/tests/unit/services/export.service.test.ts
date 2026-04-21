import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import {
  ANALYTICS_EVENT_EXPORT_CAP,
  EXPORT_SCHEMA_VERSION,
  createExportService,
} from '@/services/export.service';
import { NotFoundError } from '@/utils/errors';

/**
 * Slice P8 — export service unit tests.
 *
 * These tests work against a hand-rolled mock PrismaClient. They're the
 * shape-and-redaction spec for the export payload: a regression here
 * means we shipped something we promised not to (credentials in the
 * output, unversioned payload, analytics leaking past the cap without
 * the truncation flag).
 */

const USER_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

interface MockPrisma {
  user: { findUnique: jest.Mock };
  enrollment: { findMany: jest.Mock };
  attempt: { findMany: jest.Mock };
  analyticsEvent: { findMany: jest.Mock; count: jest.Mock };
  userAchievement: { findMany: jest.Mock };
  session: { findMany: jest.Mock };
  course: { count: jest.Mock };
  courseCollaborator: { count: jest.Mock };
}

function buildMockPrisma(): MockPrisma {
  return {
    user: { findUnique: jest.fn() },
    enrollment: { findMany: jest.fn().mockResolvedValue([]) },
    attempt: { findMany: jest.fn().mockResolvedValue([]) },
    analyticsEvent: {
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    },
    userAchievement: { findMany: jest.fn().mockResolvedValue([]) },
    session: { findMany: jest.fn().mockResolvedValue([]) },
    course: { count: jest.fn().mockResolvedValue(0) },
    courseCollaborator: { count: jest.fn().mockResolvedValue(0) },
  };
}

function userRow(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: USER_ID,
    email: 'u@example.local',
    passwordHash: 'SHOULD-NEVER-APPEAR-IN-EXPORT',
    role: 'LEARNER',
    displayName: 'Test User',
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-02T00:00:00Z'),
    avatarKey: null,
    useGravatar: false,
    preferences: null,
    passwordChangedAt: null,
    deletedAt: null,
    deletionPurgeAt: null,
    mfaEnabled: false,
    mfaBackupCodes: ['SHOULD-NEVER-APPEAR-1', 'SHOULD-NEVER-APPEAR-2'],
    ...overrides,
  };
}

describe('export.service', () => {
  describe('exportUserData', () => {
    it('throws NotFoundError when the user row is missing', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(null);
      const svc = createExportService(prisma as unknown as PrismaClient);
      await expect(svc.exportUserData(USER_ID)).rejects.toThrow(NotFoundError);
    });

    it('returns a versioned, shape-correct payload for a minimal user', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(userRow());
      const svc = createExportService(prisma as unknown as PrismaClient);

      const res = await svc.exportUserData(USER_ID);

      expect(res.schemaVersion).toBe(EXPORT_SCHEMA_VERSION);
      expect(typeof res.exportedAt).toBe('string');
      // ISO 8601 — startsWith `YYYY-` + ends with `Z`.
      expect(res.exportedAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
      expect(res.user.id).toBe(USER_ID);
      expect(res.user.email).toBe('u@example.local');
      expect(res.user.mfaEnabled).toBe(false);
      // Verify top-level keys present.
      expect(Object.keys(res).sort()).toEqual(
        [
          'achievements',
          'analyticsEvents',
          'analyticsEventsTruncated',
          'attempts',
          'collaboratorCoursesCount',
          'enrollments',
          'exportedAt',
          'ownedCoursesCount',
          'schemaVersion',
          'sessions',
          'user',
        ].sort(),
      );
    });

    it('NEVER leaks passwordHash, mfaBackupCodes, or mfaSecret', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(
        userRow({
          passwordHash: 'bcrypt$sensitive',
          mfaBackupCodes: ['bcrypt$1', 'bcrypt$2'],
        }),
      );
      const svc = createExportService(prisma as unknown as PrismaClient);

      const res = await svc.exportUserData(USER_ID);
      const json = JSON.stringify(res);
      expect(json).not.toContain('passwordHash');
      expect(json).not.toContain('bcrypt$sensitive');
      expect(json).not.toContain('mfaBackupCodes');
      expect(json).not.toContain('bcrypt$1');
      expect(json).not.toContain('mfaSecretEncrypted');
      // The boolean flag IS present; the credentials themselves are not.
      expect(res.user).toHaveProperty('mfaEnabled', false);
    });

    it('flags analyticsEventsTruncated: true when total exceeds the cap', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(userRow());
      // Return `ANALYTICS_EVENT_EXPORT_CAP` rows (what the cap actually
      // yields) but report a total count beyond that.
      const fakeRows = Array.from({ length: ANALYTICS_EVENT_EXPORT_CAP }, (_, i) => ({
        id: `ev-${i}`,
        eventType: 'video_view',
        videoId: null,
        cueId: null,
        payload: {},
        occurredAt: new Date('2026-04-01T00:00:00Z'),
        receivedAt: new Date('2026-04-01T00:00:00Z'),
      }));
      prisma.analyticsEvent.findMany.mockResolvedValueOnce(fakeRows);
      prisma.analyticsEvent.count.mockResolvedValueOnce(
        ANALYTICS_EVENT_EXPORT_CAP + 42,
      );
      const svc = createExportService(prisma as unknown as PrismaClient);

      const res = await svc.exportUserData(USER_ID);
      expect(res.analyticsEventsTruncated).toBe(true);
      expect(res.analyticsEvents).toHaveLength(ANALYTICS_EVENT_EXPORT_CAP);
    });

    it('flags analyticsEventsTruncated: false when total is at or below cap', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(userRow());
      prisma.analyticsEvent.findMany.mockResolvedValueOnce([]);
      prisma.analyticsEvent.count.mockResolvedValueOnce(0);
      const svc = createExportService(prisma as unknown as PrismaClient);

      const res = await svc.exportUserData(USER_ID);
      expect(res.analyticsEventsTruncated).toBe(false);
    });

    it('includes enrollments with resolved course titles', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(userRow());
      prisma.enrollment.findMany.mockResolvedValueOnce([
        {
          id: 'enr-1',
          courseId: 'c-1',
          startedAt: new Date('2026-03-01T00:00:00Z'),
          lastVideoId: 'v-1',
          lastPosMs: 15000,
          updatedAt: new Date('2026-03-02T00:00:00Z'),
          course: { title: 'Welcome Course' },
        },
      ]);
      const svc = createExportService(prisma as unknown as PrismaClient);

      const res = await svc.exportUserData(USER_ID);
      expect(res.enrollments).toEqual([
        {
          id: 'enr-1',
          courseId: 'c-1',
          courseTitle: 'Welcome Course',
          startedAt: '2026-03-01T00:00:00.000Z',
          lastVideoId: 'v-1',
          lastPosMs: 15000,
          updatedAt: '2026-03-02T00:00:00.000Z',
        },
      ]);
    });

    it('truncates session ipHash to first 8 chars (no full hash leak)', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(userRow());
      prisma.session.findMany
        .mockResolvedValueOnce([
          {
            id: 's-1',
            deviceLabel: 'Android',
            ipHash: 'aabbccdd11223344eeff5566ddccbbaa',
            createdAt: new Date('2026-04-01T00:00:00Z'),
            lastSeenAt: new Date('2026-04-05T00:00:00Z'),
            revokedAt: null,
          },
        ])
        .mockResolvedValueOnce([]);
      const svc = createExportService(prisma as unknown as PrismaClient);

      const res = await svc.exportUserData(USER_ID);
      expect(res.sessions).toHaveLength(1);
      expect(res.sessions[0].ipHashPrefix).toBe('aabbccdd');
      // Full hash must not appear anywhere.
      const json = JSON.stringify(res);
      expect(json).not.toContain('aabbccdd11223344eeff5566ddccbbaa');
    });

    it('lists non-revoked sessions before revoked ones', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(userRow());
      prisma.session.findMany
        .mockResolvedValueOnce([
          {
            id: 's-active',
            deviceLabel: 'iPhone',
            ipHash: null,
            createdAt: new Date('2026-04-01T00:00:00Z'),
            lastSeenAt: new Date('2026-04-05T00:00:00Z'),
            revokedAt: null,
          },
        ])
        .mockResolvedValueOnce([
          {
            id: 's-revoked',
            deviceLabel: 'macOS',
            ipHash: null,
            createdAt: new Date('2026-03-01T00:00:00Z'),
            lastSeenAt: new Date('2026-03-05T00:00:00Z'),
            revokedAt: new Date('2026-03-06T00:00:00Z'),
          },
        ]);
      const svc = createExportService(prisma as unknown as PrismaClient);

      const res = await svc.exportUserData(USER_ID);
      expect(res.sessions.map((s) => s.id)).toEqual(['s-active', 's-revoked']);
      expect(res.sessions[0].revokedAt).toBeNull();
      expect(res.sessions[1].revokedAt).toBe('2026-03-06T00:00:00.000Z');
    });

    it('emits owned and collaborator course counts (not the content)', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(
        userRow({ role: 'COURSE_DESIGNER' }),
      );
      prisma.course.count.mockResolvedValueOnce(3);
      prisma.courseCollaborator.count.mockResolvedValueOnce(5);
      const svc = createExportService(prisma as unknown as PrismaClient);

      const res = await svc.exportUserData(USER_ID);
      expect(res.ownedCoursesCount).toBe(3);
      expect(res.collaboratorCoursesCount).toBe(5);
      // The payload shape must NOT include a full course list.
      expect(res).not.toHaveProperty('ownedCourses');
      expect(res).not.toHaveProperty('collaboratorCourses');
    });

    it('passes a take cap to the analyticsEvent query', async () => {
      const prisma = buildMockPrisma();
      prisma.user.findUnique.mockResolvedValueOnce(userRow());
      const svc = createExportService(prisma as unknown as PrismaClient);
      await svc.exportUserData(USER_ID);

      const call = prisma.analyticsEvent.findMany.mock.calls[0]?.[0];
      expect(call?.take).toBe(ANALYTICS_EVENT_EXPORT_CAP);
      expect(call?.orderBy).toEqual({ occurredAt: 'desc' });
      expect(call?.where).toEqual({ userId: USER_ID });
    });
  });
});
