import type { CueType, PrismaClient } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { ValidationError } from '@/utils/errors';
import type { AnalyticsEventInput } from '@/validators/analytics.validators';

/** 4KB per event when serialized — keeps a single bad client from DoS'ing us. */
const MAX_PAYLOAD_SERIALIZED_BYTES = 4 * 1024;

export interface CourseAnalyticsAggregate {
  totalViews: number;
  completionRate: number;
  perCueTypeAccuracy: Record<CueType, number | null>;
}

export interface AnalyticsService {
  ingestEvents(userId: string, events: AnalyticsEventInput[]): Promise<{ count: number }>;
  getCourseAggregate(courseId: string): Promise<CourseAnalyticsAggregate>;
}

function enforceEventSizeCap(events: AnalyticsEventInput[]): void {
  for (let i = 0; i < events.length; i += 1) {
    const serialized = JSON.stringify(events[i]);
    if (serialized.length > MAX_PAYLOAD_SERIALIZED_BYTES) {
      throw new ValidationError(
        `Event at index ${i} exceeds ${MAX_PAYLOAD_SERIALIZED_BYTES}-byte cap`,
      );
    }
  }
}

export function createAnalyticsService(
  prisma: PrismaClient = defaultPrisma,
): AnalyticsService {
  return {
    async ingestEvents(userId, events) {
      enforceEventSizeCap(events);

      // `createMany` is the cheapest path for a batch insert; `skipDuplicates`
      // is left off because we don't have a uniqueness constraint on
      // analytics rows (they're append-only).
      const result = await prisma.analyticsEvent.createMany({
        data: events.map((e) => ({
          userId,
          eventType: e.eventType,
          occurredAt: new Date(e.occurredAt),
          ...(e.videoId !== undefined ? { videoId: e.videoId } : {}),
          ...(e.cueId !== undefined ? { cueId: e.cueId } : {}),
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          payload: (e.payload ?? {}) as any,
        })),
      });
      return { count: result.count };
    },

    async getCourseAggregate(courseId) {
      // Pull the list of video IDs for this course once — we use it in every
      // sub-query below.
      const videos = await prisma.video.findMany({
        where: { courseId },
        select: { id: true },
      });
      const videoIds = videos.map((v) => v.id);

      const enrollmentCount = await prisma.enrollment.count({ where: { courseId } });

      // totalViews: count of `video_view` events on any of this course's
      // videos. Fall back to enrollmentCount when no events have been
      // recorded yet so the dashboard shows something sane in the first days
      // after launch.
      let totalViews = 0;
      if (videoIds.length > 0) {
        totalViews = await prisma.analyticsEvent.count({
          where: { eventType: 'video_view', videoId: { in: videoIds } },
        });
      }
      if (totalViews === 0) totalViews = enrollmentCount;

      // completionRate (MVP approximation): distinct users who have logged
      // ANY `video_complete` event on this course's videos, divided by
      // enrollments.count. Documented simplification: we don't yet enforce
      // "watched at least 90%", which is the ideal definition — revisit once
      // analytics ingestion has enough real-world fidelity to compute watch
      // percentage. See roadmap Phase 6.
      let completedUserCount = 0;
      if (videoIds.length > 0) {
        const completions = await prisma.analyticsEvent.findMany({
          where: { eventType: 'video_complete', videoId: { in: videoIds } },
          select: { userId: true },
          distinct: ['userId'],
        });
        completedUserCount = completions.filter((c) => c.userId !== null).length;
      }
      const completionRate = enrollmentCount > 0
        ? completedUserCount / enrollmentCount
        : 0;

      // perCueTypeAccuracy: per cue type, fraction of attempts that were
      // correct, restricted to cues on videos in this course. Return null
      // for a type with no attempts so the client can distinguish "no data"
      // from "0% accuracy".
      const perCueTypeAccuracy: Record<CueType, number | null> = {
        MCQ: null,
        MATCHING: null,
        BLANKS: null,
        VOICE: null,
      };

      if (videoIds.length > 0) {
        // Fetch all attempts in one query joined to Cue.type. Postgres has
        // the aggregate we need if we go via $queryRaw, but the dataset on
        // this endpoint is small enough that a simple `findMany` + in-memory
        // reduction is fine and easier to keep correct.
        const attempts = await prisma.attempt.findMany({
          where: { videoId: { in: videoIds } },
          select: {
            correct: true,
            cue: { select: { type: true } },
          },
        });

        const byType = new Map<CueType, { correct: number; total: number }>();
        for (const a of attempts) {
          const key = a.cue.type;
          const bucket = byType.get(key) ?? { correct: 0, total: 0 };
          bucket.total += 1;
          if (a.correct) bucket.correct += 1;
          byType.set(key, bucket);
        }
        for (const [type, { correct, total }] of byType) {
          perCueTypeAccuracy[type] = total > 0 ? correct / total : null;
        }
      }

      return { totalViews, completionRate, perCueTypeAccuracy };
    },
  };
}

export const analyticsService = createAnalyticsService();
