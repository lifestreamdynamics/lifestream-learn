import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import { createAnalyticsService } from '@/services/analytics.service';
import { ValidationError } from '@/utils/errors';

type MockPrisma = {
  analyticsEvent: {
    createMany: jest.Mock;
    count: jest.Mock;
    findMany: jest.Mock;
  };
  enrollment: { count: jest.Mock };
  video: { findMany: jest.Mock };
  attempt: { findMany: jest.Mock };
};

function buildMockPrisma(): MockPrisma {
  return {
    analyticsEvent: {
      createMany: jest.fn(),
      count: jest.fn(),
      findMany: jest.fn(),
    },
    enrollment: { count: jest.fn() },
    video: { findMany: jest.fn() },
    attempt: { findMany: jest.fn() },
  };
}

const USER_ID = '11111111-1111-4111-8111-111111111111';
const COURSE_ID = '22222222-2222-4222-8222-222222222222';

describe('analytics.service', () => {
  describe('ingestEvents', () => {
    it('forwards the batch to createMany', async () => {
      const prisma = buildMockPrisma();
      prisma.analyticsEvent.createMany.mockResolvedValueOnce({ count: 2 });
      const svc = createAnalyticsService(prisma as unknown as PrismaClient);
      const res = await svc.ingestEvents(USER_ID, [
        { eventType: 'video_view', occurredAt: new Date().toISOString() },
        {
          eventType: 'cue_answered',
          occurredAt: new Date().toISOString(),
          payload: { ok: true },
        },
      ]);
      expect(res.count).toBe(2);
      expect(prisma.analyticsEvent.createMany).toHaveBeenCalledTimes(1);
    });

    it('rejects a single oversized event (>4KB serialized)', async () => {
      const prisma = buildMockPrisma();
      const svc = createAnalyticsService(prisma as unknown as PrismaClient);
      const big = 'x'.repeat(5000);
      await expect(
        svc.ingestEvents(USER_ID, [
          {
            eventType: 'huge',
            occurredAt: new Date().toISOString(),
            payload: { big },
          },
        ]),
      ).rejects.toBeInstanceOf(ValidationError);
      expect(prisma.analyticsEvent.createMany).not.toHaveBeenCalled();
    });
  });

  describe('getCourseAggregate', () => {
    it('shape when no data', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findMany.mockResolvedValueOnce([]);
      prisma.enrollment.count.mockResolvedValueOnce(0);
      prisma.analyticsEvent.count.mockResolvedValueOnce(0);
      prisma.analyticsEvent.findMany.mockResolvedValueOnce([]);
      prisma.attempt.findMany.mockResolvedValueOnce([]);
      const svc = createAnalyticsService(prisma as unknown as PrismaClient);
      const res = await svc.getCourseAggregate(COURSE_ID);
      expect(res).toEqual({
        totalViews: 0,
        completionRate: 0,
        perCueTypeAccuracy: {
          MCQ: null,
          MATCHING: null,
          BLANKS: null,
          VOICE: null,
        },
      });
    });

    it('falls back to enrollment count when no view events', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findMany.mockResolvedValueOnce([{ id: 'v1' }]);
      prisma.enrollment.count.mockResolvedValueOnce(5);
      prisma.analyticsEvent.count.mockResolvedValueOnce(0); // no video_view
      prisma.analyticsEvent.findMany.mockResolvedValueOnce([]);
      prisma.attempt.findMany.mockResolvedValueOnce([]);
      const svc = createAnalyticsService(prisma as unknown as PrismaClient);
      const res = await svc.getCourseAggregate(COURSE_ID);
      expect(res.totalViews).toBe(5);
    });

    it('computes perCueTypeAccuracy from attempts', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findMany.mockResolvedValueOnce([{ id: 'v1' }]);
      prisma.enrollment.count.mockResolvedValueOnce(2);
      prisma.analyticsEvent.count.mockResolvedValueOnce(3);
      prisma.analyticsEvent.findMany.mockResolvedValueOnce([{ userId: USER_ID }]);
      prisma.attempt.findMany.mockResolvedValueOnce([
        { correct: true, cue: { type: 'MCQ' } },
        { correct: false, cue: { type: 'MCQ' } },
        { correct: true, cue: { type: 'BLANKS' } },
      ]);
      const svc = createAnalyticsService(prisma as unknown as PrismaClient);
      const res = await svc.getCourseAggregate(COURSE_ID);
      expect(res.totalViews).toBe(3);
      expect(res.completionRate).toBeCloseTo(0.5);
      expect(res.perCueTypeAccuracy.MCQ).toBeCloseTo(0.5);
      expect(res.perCueTypeAccuracy.BLANKS).toBe(1);
      expect(res.perCueTypeAccuracy.MATCHING).toBeNull();
    });
  });
});
