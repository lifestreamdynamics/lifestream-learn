import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import { createEnrollmentService } from '@/services/enrollment.service';
import {
  ConflictError,
  NotFoundError,
  ValidationError,
} from '@/utils/errors';

type MockPrisma = {
  course: { findUnique: jest.Mock };
  enrollment: {
    findUnique: jest.Mock;
    findMany: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
  };
  video: { findUnique: jest.Mock };
};

function buildMockPrisma(): MockPrisma {
  return {
    course: { findUnique: jest.fn() },
    enrollment: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    video: { findUnique: jest.fn() },
  };
}

const USER_ID = '11111111-1111-4111-8111-111111111111';
const COURSE_ID = '22222222-2222-4222-8222-222222222222';
const VIDEO_ID = '33333333-3333-4333-8333-333333333333';
const ENROLLMENT_ID = '44444444-4444-4444-8444-444444444444';
const OTHER_COURSE_ID = '55555555-5555-4555-8555-555555555555';

describe('enrollment.service', () => {
  describe('createEnrollment', () => {
    it('creates new on first call', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        published: true,
      });
      prisma.enrollment.findUnique.mockResolvedValueOnce(null);
      prisma.enrollment.create.mockResolvedValueOnce({
        id: ENROLLMENT_ID,
        userId: USER_ID,
        courseId: COURSE_ID,
      });
      const svc = createEnrollmentService(prisma as unknown as PrismaClient);

      const res = await svc.createEnrollment(USER_ID, COURSE_ID);
      expect(res.created).toBe(true);
    });

    it('returns existing row idempotently', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        published: true,
      });
      prisma.enrollment.findUnique.mockResolvedValueOnce({
        id: ENROLLMENT_ID,
        userId: USER_ID,
        courseId: COURSE_ID,
      });
      const svc = createEnrollmentService(prisma as unknown as PrismaClient);

      const res = await svc.createEnrollment(USER_ID, COURSE_ID);
      expect(res.created).toBe(false);
      expect(prisma.enrollment.create).not.toHaveBeenCalled();
    });

    it('unpublished course -> ConflictError', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        published: false,
      });
      const svc = createEnrollmentService(prisma as unknown as PrismaClient);
      await expect(svc.createEnrollment(USER_ID, COURSE_ID))
        .rejects.toBeInstanceOf(ConflictError);
    });

    it('missing course -> NotFoundError', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce(null);
      const svc = createEnrollmentService(prisma as unknown as PrismaClient);
      await expect(svc.createEnrollment(USER_ID, COURSE_ID))
        .rejects.toBeInstanceOf(NotFoundError);
    });
  });

  describe('listOwnEnrollments', () => {
    it('returns shaped rows', async () => {
      const prisma = buildMockPrisma();
      prisma.enrollment.findMany.mockResolvedValueOnce([
        {
          id: ENROLLMENT_ID,
          userId: USER_ID,
          courseId: COURSE_ID,
          startedAt: new Date('2026-04-19T00:00:00Z'),
          lastVideoId: null,
          lastPosMs: null,
          course: {
            id: COURSE_ID,
            title: 'T',
            slug: 't-abcdef',
            coverImageUrl: null,
          },
        },
      ]);
      const svc = createEnrollmentService(prisma as unknown as PrismaClient);
      const res = await svc.listOwnEnrollments(USER_ID);
      expect(res).toHaveLength(1);
      expect(res[0].course.title).toBe('T');
    });
  });

  describe('updateProgress', () => {
    it('happy path', async () => {
      const prisma = buildMockPrisma();
      prisma.enrollment.findUnique.mockResolvedValueOnce({ id: ENROLLMENT_ID });
      prisma.video.findUnique.mockResolvedValueOnce({ courseId: COURSE_ID });
      prisma.enrollment.update.mockResolvedValueOnce({});
      const svc = createEnrollmentService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateProgress(USER_ID, COURSE_ID, {
          lastVideoId: VIDEO_ID,
          lastPosMs: 42000,
        }),
      ).resolves.toBeUndefined();
      expect(prisma.enrollment.update).toHaveBeenCalledWith({
        where: { id: ENROLLMENT_ID },
        data: { lastVideoId: VIDEO_ID, lastPosMs: 42000 },
      });
    });

    it('no enrollment -> NotFoundError', async () => {
      const prisma = buildMockPrisma();
      prisma.enrollment.findUnique.mockResolvedValueOnce(null);
      const svc = createEnrollmentService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateProgress(USER_ID, COURSE_ID, {
          lastVideoId: VIDEO_ID,
          lastPosMs: 0,
        }),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('video from a different course -> ValidationError', async () => {
      const prisma = buildMockPrisma();
      prisma.enrollment.findUnique.mockResolvedValueOnce({ id: ENROLLMENT_ID });
      prisma.video.findUnique.mockResolvedValueOnce({ courseId: OTHER_COURSE_ID });
      const svc = createEnrollmentService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateProgress(USER_ID, COURSE_ID, {
          lastVideoId: VIDEO_ID,
          lastPosMs: 0,
        }),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('missing video -> ValidationError', async () => {
      const prisma = buildMockPrisma();
      prisma.enrollment.findUnique.mockResolvedValueOnce({ id: ENROLLMENT_ID });
      prisma.video.findUnique.mockResolvedValueOnce(null);
      const svc = createEnrollmentService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateProgress(USER_ID, COURSE_ID, {
          lastVideoId: VIDEO_ID,
          lastPosMs: 0,
        }),
      ).rejects.toBeInstanceOf(ValidationError);
    });
  });
});
