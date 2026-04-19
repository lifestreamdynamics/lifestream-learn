import type { PrismaClient, VideoStatus } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { ValidationError } from '@/utils/errors';
import { decodeFeedCursor, encodeFeedCursor } from '@/validators/feed.validators';

export interface FeedEntry {
  video: {
    id: string;
    courseId: string;
    title: string;
    orderIndex: number;
    status: 'READY';
    durationMs: number | null;
    createdAt: Date;
  };
  course: {
    id: string;
    title: string;
    coverImageUrl: string | null;
  };
  cueCount: number;
  hasAttempted: boolean;
}

export interface FeedResult {
  items: FeedEntry[];
  nextCursor: string | null;
  hasMore: boolean;
}

export interface FeedService {
  getFeed(
    userId: string,
    opts: { cursor?: string; limit?: number },
  ): Promise<FeedResult>;
}

/**
 * Internal row shape from the ordered raw query. `startedAt` is the learner's
 * enrollment start; `orderIndex`, `videoId`, etc. are the video's fields. We
 * use a small `$queryRaw` so the ordering tuple (startedAt desc, orderIndex
 * asc, videoId asc) is expressible in a single window of rows — Prisma's
 * fluent API can't join-then-order by a mix of related columns cleanly.
 */
interface RawFeedRow {
  videoId: string;
  videoTitle: string;
  videoOrderIndex: number;
  videoStatus: VideoStatus;
  videoDurationMs: number | null;
  videoCreatedAt: Date;
  courseId: string;
  courseTitle: string;
  courseCoverImageUrl: string | null;
  startedAt: Date;
}

export function createFeedService(
  prisma: PrismaClient = defaultPrisma,
): FeedService {
  return {
    async getFeed(userId, opts) {
      const limit = Math.min(opts.limit ?? 20, 50);

      let cursor = null;
      if (opts.cursor) {
        cursor = decodeFeedCursor(opts.cursor);
        if (!cursor) throw new ValidationError('Invalid cursor');
      }

      // Primary query: the raw SQL shape is the easiest way to order by a
      // mix of enrollment and video columns in a single pass. We request
      // `limit + 1` rows so `hasMore` can be computed without a second
      // round-trip.
      //
      // Ordering: (startedAt desc, orderIndex asc, videoId asc) — matches the
      // cursor triple. The cursor predicate uses tuple comparison semantics:
      // a row is strictly "after" the cursor if:
      //   - startedAt < cursor.startedAt                             , OR
      //   - startedAt = cursor.startedAt AND orderIndex > cursor.orderIndex, OR
      //   - startedAt = cursor.startedAt AND orderIndex = cursor.orderIndex
      //       AND videoId > cursor.videoId
      //
      // That's exactly how you'd hand-write keyset pagination over a mixed
      // asc/desc composite key.
      const takeLimit = limit + 1;

      // Parameterised to avoid SQL injection — userId comes from the verified
      // JWT but still: parameterise on principle.
      const rows = cursor
        ? await prisma.$queryRaw<RawFeedRow[]>`
            SELECT
              v."id"            AS "videoId",
              v."title"         AS "videoTitle",
              v."orderIndex"    AS "videoOrderIndex",
              v."status"        AS "videoStatus",
              v."durationMs"    AS "videoDurationMs",
              v."createdAt"     AS "videoCreatedAt",
              c."id"            AS "courseId",
              c."title"         AS "courseTitle",
              c."coverImageUrl" AS "courseCoverImageUrl",
              e."startedAt"     AS "startedAt"
            FROM "Enrollment" e
            JOIN "Course" c ON c."id" = e."courseId"
            JOIN "Video" v  ON v."courseId" = c."id"
            WHERE e."userId" = ${userId}::uuid
              AND v."status" = 'READY'::"VideoStatus"
              AND (
                e."startedAt" < ${cursor.startedAt}
                OR (e."startedAt" = ${cursor.startedAt} AND v."orderIndex" > ${cursor.orderIndex})
                OR (e."startedAt" = ${cursor.startedAt} AND v."orderIndex" = ${cursor.orderIndex} AND v."id"::text > ${cursor.videoId})
              )
            ORDER BY e."startedAt" DESC, v."orderIndex" ASC, v."id" ASC
            LIMIT ${takeLimit}
          `
        : await prisma.$queryRaw<RawFeedRow[]>`
            SELECT
              v."id"            AS "videoId",
              v."title"         AS "videoTitle",
              v."orderIndex"    AS "videoOrderIndex",
              v."status"        AS "videoStatus",
              v."durationMs"    AS "videoDurationMs",
              v."createdAt"     AS "videoCreatedAt",
              c."id"            AS "courseId",
              c."title"         AS "courseTitle",
              c."coverImageUrl" AS "courseCoverImageUrl",
              e."startedAt"     AS "startedAt"
            FROM "Enrollment" e
            JOIN "Course" c ON c."id" = e."courseId"
            JOIN "Video" v  ON v."courseId" = c."id"
            WHERE e."userId" = ${userId}::uuid
              AND v."status" = 'READY'::"VideoStatus"
            ORDER BY e."startedAt" DESC, v."orderIndex" ASC, v."id" ASC
            LIMIT ${takeLimit}
          `;

      const hasMore = rows.length > limit;
      const page = hasMore ? rows.slice(0, limit) : rows;

      if (page.length === 0) {
        return { items: [], nextCursor: null, hasMore: false };
      }

      // Second query: per-video cue counts. groupBy + `_count: true` returns
      // one row per videoId we pass in.
      const pageVideoIds = page.map((r) => r.videoId);
      const cueCounts = await prisma.cue.groupBy({
        by: ['videoId'],
        where: { videoId: { in: pageVideoIds } },
        _count: { _all: true },
      });
      const cueCountMap = new Map<string, number>();
      for (const g of cueCounts) cueCountMap.set(g.videoId, g._count._all);

      // Third query: videos the learner has attempted at least once.
      // `distinct` keeps the payload small even for heavy learners.
      const attempted = await prisma.attempt.findMany({
        where: { userId, videoId: { in: pageVideoIds } },
        select: { videoId: true },
        distinct: ['videoId'],
      });
      const attemptedSet = new Set(attempted.map((a) => a.videoId));

      const items: FeedEntry[] = page.map((r) => ({
        video: {
          id: r.videoId,
          courseId: r.courseId,
          title: r.videoTitle,
          orderIndex: r.videoOrderIndex,
          // The WHERE clause constrains status to READY — reflect that in the
          // type so downstream consumers don't have to re-check.
          status: 'READY',
          durationMs: r.videoDurationMs,
          createdAt: r.videoCreatedAt,
        },
        course: {
          id: r.courseId,
          title: r.courseTitle,
          coverImageUrl: r.courseCoverImageUrl,
        },
        cueCount: cueCountMap.get(r.videoId) ?? 0,
        hasAttempted: attemptedSet.has(r.videoId),
      }));

      const last = page[page.length - 1];
      const nextCursor = hasMore && last
        ? encodeFeedCursor({
            startedAt: last.startedAt,
            orderIndex: last.videoOrderIndex,
            videoId: last.videoId,
          })
        : null;

      return { items, nextCursor, hasMore };
    },
  };
}

export const feedService = createFeedService();
