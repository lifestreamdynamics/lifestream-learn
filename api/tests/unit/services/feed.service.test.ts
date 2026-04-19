import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import { createFeedService } from '@/services/feed.service';
import {
  decodeFeedCursor,
  encodeFeedCursor,
} from '@/validators/feed.validators';
import { ValidationError } from '@/utils/errors';

type MockPrisma = {
  $queryRaw: jest.Mock;
  cue: { groupBy: jest.Mock };
  attempt: { findMany: jest.Mock };
};

function buildMockPrisma(): MockPrisma {
  return {
    $queryRaw: jest.fn(),
    cue: { groupBy: jest.fn() },
    attempt: { findMany: jest.fn() },
  };
}

const USER_ID = '11111111-1111-4111-8111-111111111111';
const COURSE_ID = '22222222-2222-4222-8222-222222222222';

function fakeRow(i: number) {
  return {
    videoId: `video-${i}`,
    videoTitle: `Video ${i}`,
    videoOrderIndex: i,
    videoStatus: 'READY',
    videoDurationMs: 12000,
    videoCreatedAt: new Date(),
    courseId: COURSE_ID,
    courseTitle: 'C',
    courseCoverImageUrl: null,
    startedAt: new Date('2026-04-18T10:00:00Z'),
  };
}

describe('feed.service', () => {
  describe('cursor encoding round-trip', () => {
    it('encodes and decodes', () => {
      const cursor = {
        startedAt: new Date('2026-04-19T12:00:00Z'),
        orderIndex: 5,
        videoId: '33333333-3333-4333-8333-333333333333',
      };
      const encoded = encodeFeedCursor(cursor);
      const decoded = decodeFeedCursor(encoded);
      expect(decoded).toMatchObject({
        orderIndex: 5,
        videoId: cursor.videoId,
      });
      expect(decoded?.startedAt.getTime()).toBe(cursor.startedAt.getTime());
    });

    it('rejects garbage', () => {
      expect(decodeFeedCursor('not-base64$$')).toBeNull();
      expect(decodeFeedCursor(Buffer.from('only-one-part').toString('base64'))).toBeNull();
    });
  });

  describe('getFeed', () => {
    it('empty feed case', async () => {
      const prisma = buildMockPrisma();
      prisma.$queryRaw.mockResolvedValueOnce([]);
      const svc = createFeedService(prisma as unknown as PrismaClient);
      const res = await svc.getFeed(USER_ID, {});
      expect(res.items).toEqual([]);
      expect(res.nextCursor).toBeNull();
      expect(res.hasMore).toBe(false);
    });

    it('stitches cueCount and hasAttempted', async () => {
      const prisma = buildMockPrisma();
      prisma.$queryRaw.mockResolvedValueOnce([fakeRow(0), fakeRow(1)]);
      prisma.cue.groupBy.mockResolvedValueOnce([
        { videoId: 'video-0', _count: { _all: 3 } },
      ]);
      prisma.attempt.findMany.mockResolvedValueOnce([{ videoId: 'video-1' }]);
      const svc = createFeedService(prisma as unknown as PrismaClient);
      const res = await svc.getFeed(USER_ID, {});
      expect(res.items).toHaveLength(2);
      expect(res.items[0].cueCount).toBe(3);
      expect(res.items[0].hasAttempted).toBe(false);
      expect(res.items[1].cueCount).toBe(0);
      expect(res.items[1].hasAttempted).toBe(true);
    });

    it('hasMore+nextCursor when page is full', async () => {
      const prisma = buildMockPrisma();
      // limit=2 → request takes 3, returning 3 → hasMore=true
      prisma.$queryRaw.mockResolvedValueOnce([fakeRow(0), fakeRow(1), fakeRow(2)]);
      prisma.cue.groupBy.mockResolvedValueOnce([]);
      prisma.attempt.findMany.mockResolvedValueOnce([]);
      const svc = createFeedService(prisma as unknown as PrismaClient);
      const res = await svc.getFeed(USER_ID, { limit: 2 });
      expect(res.items).toHaveLength(2);
      expect(res.hasMore).toBe(true);
      expect(res.nextCursor).toBeTruthy();
    });

    it('invalid cursor rejected', async () => {
      const prisma = buildMockPrisma();
      const svc = createFeedService(prisma as unknown as PrismaClient);
      await expect(
        svc.getFeed(USER_ID, { cursor: '%%bad' }),
      ).rejects.toBeInstanceOf(ValidationError);
    });
  });
});
