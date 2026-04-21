import type { CueType, PrismaClient } from '@prisma/client';
import type IORedis from 'ioredis';
import { prisma as defaultPrisma } from '@/config/prisma';
import { redis as defaultRedis } from '@/config/redis';
import { NotFoundError } from '@/utils/errors';
import { logger } from '@/config/logger';
import {
  computeStreakFromEvents,
  timezoneOffsetFromPreferences,
  type StreakResult,
} from '@/services/progress.service.streak';
import {
  createAchievementService,
  type AchievementSummary,
} from '@/services/achievement.service';

// Re-export for callers that want the helpers from this module as a
// single entrypoint.
export {
  computeStreakFromEvents,
  timezoneOffsetFromPreferences,
} from '@/services/progress.service.streak';
export type { StreakResult } from '@/services/progress.service.streak';

/**
 * Slice P2 — progress aggregation service.
 *
 * This is the headline feature of the profile redesign: it powers the
 * GPA-style summary card, the per-course breakdown, and the lesson review
 * screen. Grade aggregation is *grading-adjacent* (a wrong numerator or
 * denominator would leak / miscredit a learner), so the unit tests for
 * this file target ≥95% coverage per `CLAUDE.md`.
 *
 * Security invariant (repeated in `getLessonReview` below): the lesson
 * review endpoint **must not** echo the correct-answer shape for cues
 * the user has not yet attempted. That mirrors the same posture as
 * `attempt.service.ts` which never returns `payload.answerIndex`.
 *
 * Caching: three Redis keys, 5-minute TTL, invalidated on attempt write
 * (`attempt.service` clears the matching keys). The Redis client already
 * has a `learn:` `keyPrefix` so keys in this file are un-prefixed in
 * source but become `learn:progress:...` on the wire.
 */

export type Grade = 'A' | 'B' | 'C' | 'D' | 'F';

/** Grade-letter mapping — single source of truth for the server. Never
 * duplicate this on the client; `accuracy` is always returned alongside
 * `grade` so the UI can render the letter directly. */
export function gradeFromAccuracy(accuracy: number | null): Grade | null {
  if (accuracy === null) return null;
  if (accuracy >= 0.9) return 'A';
  if (accuracy >= 0.8) return 'B';
  if (accuracy >= 0.7) return 'C';
  if (accuracy >= 0.6) return 'D';
  return 'F';
}

export interface ProgressSummary {
  coursesEnrolled: number;
  lessonsCompleted: number;
  totalCuesAttempted: number;
  totalCuesCorrect: number;
  overallAccuracy: number | null;
  overallGrade: Grade | null;
  /**
   * Approximation: sum of `Video.durationMs` for videos the learner has
   * fired a `video_complete` analytics event on. We do not (yet) track
   * per-second watch time; when per-second tracking lands, this becomes
   * the floor of the real number. Intentionally coarse for now.
   */
  totalWatchTimeMs: number;
  /**
   * Slice P3 — consecutive-day streaks computed off `AnalyticsEvent`
   * (`video_view` OR `cue_answered`) in the user's local timezone
   * (offset stored in `user.preferences.timezoneOffsetMinutes`).
   * `currentStreak` is the streak ending *today* or *yesterday*
   * ("you haven't missed today yet" grace). Both are 0 for a fresh user.
   */
  currentStreak: number;
  longestStreak: number;
}

export interface CourseProgressSummary {
  course: {
    id: string;
    title: string;
    slug: string;
    coverImageUrl: string | null;
  };
  videosTotal: number;
  videosCompleted: number;
  completionPct: number;
  cuesAttempted: number;
  cuesCorrect: number;
  accuracy: number | null;
  grade: Grade | null;
  lastVideoId: string | null;
  lastPosMs: number | null;
}

export interface OverallProgress {
  summary: ProgressSummary;
  perCourse: CourseProgressSummary[];
  /**
   * Slice P3 — achievements newly unlocked during *this* response. The
   * client uses this as a pull-not-push "show a toast" signal. Empty
   * array on calls where no criterion newly evaluates to true.
   */
  recentlyUnlocked: AchievementSummary[];
}

export interface LessonProgressSummary {
  videoId: string;
  title: string;
  orderIndex: number;
  durationMs: number | null;
  cueCount: number;
  cuesAttempted: number;
  cuesCorrect: number;
  accuracy: number | null;
  grade: Grade | null;
  completed: boolean;
}

export interface CourseProgressDetail extends CourseProgressSummary {
  lessons: LessonProgressSummary[];
}

export interface CueOutcome {
  cueId: string;
  atMs: number;
  type: CueType;
  prompt: string;
  attempted: boolean;
  /** null until the cue has been attempted at least once. */
  correct: boolean | null;
  scoreJson: unknown | null;
  submittedAt: Date | null;
  /** Designer-authored explanation; exposed for attempted MCQ cues. */
  explanation: string | null;
  yourAnswerSummary: string | null;
  /**
   * SECURITY: null for unattempted cues. This is the load-bearing
   * invariant of this endpoint — the server never pre-leaks the
   * correct-answer shape. Mirrors the `attempt.service` invariant that
   * `payload.answerIndex` is never echoed to the client.
   */
  correctAnswerSummary: string | null;
}

export interface LessonReview {
  video: {
    id: string;
    title: string;
    orderIndex: number;
    durationMs: number | null;
    courseId: string;
  };
  course: {
    id: string;
    title: string;
    slug: string;
  };
  score: {
    cuesAttempted: number;
    cuesCorrect: number;
    accuracy: number | null;
    grade: Grade | null;
  };
  cues: CueOutcome[];
}

export interface ProgressService {
  getOverallProgress(userId: string): Promise<OverallProgress>;
  getCourseProgress(userId: string, courseId: string): Promise<CourseProgressDetail>;
  getLessonReview(userId: string, videoId: string): Promise<LessonReview>;
  /**
   * Best-effort cache invalidation. Called from `attempt.service` after
   * a successful attempt write; never blocks the attempt response.
   */
  invalidateForAttempt(input: {
    userId: string;
    videoId: string;
    courseId: string;
  }): Promise<void>;
}

// Cache TTL: 5 minutes. Long enough to blunt the N+1 cost of a
// designer/admin opening the profile repeatedly while browsing, short
// enough that a stale response after a cache-invalidation miss self-heals
// before the learner notices.
export const PROGRESS_CACHE_TTL_SECONDS = 300;

// Key builders. `learn:` prefix is applied by the ioredis keyPrefix so
// these stay short in source.
const overallKey = (userId: string): string => `progress:overall:${userId}`;
const courseKey = (userId: string, courseId: string): string =>
  `progress:course:${userId}:${courseId}`;
const lessonKey = (userId: string, videoId: string): string =>
  `progress:lesson:${userId}:${videoId}`;
// Slice P3 — achievements-list cache key. Stays in the `progress:` Redis
// namespace so Phase 1 key-prefix hygiene still holds (no new namespace).
export const achievementsKey = (userId: string): string =>
  `progress:achievements:${userId}`;

function safeAccuracy(correct: number, attempted: number): number | null {
  if (attempted <= 0) return null;
  return correct / attempted;
}

/**
 * Slice P3 — fetch the learner's streak-eligible events
 * (`video_view` OR `cue_answered`) and fold them through the pure
 * `computeStreakFromEvents` helper. Lives here rather than in
 * `progress.service.streak.ts` because it needs Prisma; the pure
 * helper stays import-safe from both progress and achievement services.
 */
export async function computeStreakForUser(
  prisma: PrismaClient,
  userId: string,
): Promise<StreakResult> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { preferences: true },
  });
  const tz = timezoneOffsetFromPreferences(user?.preferences);
  const events = await prisma.analyticsEvent.findMany({
    where: {
      userId,
      eventType: { in: ['video_view', 'cue_answered'] },
    },
    select: { occurredAt: true },
  });
  return computeStreakFromEvents(
    events.map((e) => e.occurredAt),
    { timezoneOffsetMinutes: tz },
  );
}

/**
 * Render a one-line summary of a cue's answer key for the lesson review
 * screen. Only called for *attempted* cues — never for unattempted cues
 * where the correct answer must stay on the server.
 */
function correctAnswerSummaryFor(
  cueType: CueType,
  payload: unknown,
): string | null {
  if (payload === null || typeof payload !== 'object') return null;
  const p = payload as Record<string, unknown>;
  switch (cueType) {
    case 'MCQ': {
      const choices = p.choices;
      const answerIndex = p.answerIndex;
      if (Array.isArray(choices) && typeof answerIndex === 'number') {
        const choice = choices[answerIndex];
        if (typeof choice === 'string') return choice;
      }
      return null;
    }
    case 'BLANKS': {
      const blanks = p.blanks;
      if (!Array.isArray(blanks)) return null;
      const parts: string[] = [];
      for (const b of blanks) {
        if (b && typeof b === 'object' && 'accept' in b) {
          const accept = (b as { accept: unknown }).accept;
          if (Array.isArray(accept) && typeof accept[0] === 'string') {
            parts.push(accept[0]);
          }
        }
      }
      return parts.length > 0 ? parts.join(', ') : null;
    }
    case 'MATCHING': {
      const pairs = p.pairs;
      const left = p.left;
      const right = p.right;
      /* istanbul ignore next -- defensive: validated payload always supplies all three arrays. */
      if (!Array.isArray(pairs) || !Array.isArray(left) || !Array.isArray(right)) {
        return null;
      }
      const rendered: string[] = [];
      for (const pair of pairs) {
        if (Array.isArray(pair) && pair.length === 2) {
          const [l, r] = pair;
          if (typeof l === 'number' && typeof r === 'number') {
            const leftLabel = left[l];
            const rightLabel = right[r];
            if (typeof leftLabel === 'string' && typeof rightLabel === 'string') {
              rendered.push(`${leftLabel} → ${rightLabel}`);
            }
          }
        }
      }
      return rendered.length > 0 ? rendered.join('; ') : null;
    }
    /* istanbul ignore next -- VOICE is rejected at cue.service (ADR 0004); this branch is defensive. */
    case 'VOICE':
      return null;
  }
}

/** Extract the human-readable prompt from a cue payload. */
function promptFor(cueType: CueType, payload: unknown): string {
  if (cueType === 'VOICE') {
    return 'Voice exercise (not yet supported)';
  }
  if (payload === null || typeof payload !== 'object') return '';
  const p = payload as Record<string, unknown>;
  switch (cueType) {
    case 'MCQ':
      return typeof p.question === 'string' ? p.question : '';
    case 'BLANKS':
      return typeof p.sentenceTemplate === 'string' ? p.sentenceTemplate : '';
    case 'MATCHING':
      return typeof p.prompt === 'string' ? p.prompt : '';
  }
}

/** Render a short summary of the learner's most recent attempt for a cue. */
function yourAnswerSummaryFor(
  cueType: CueType,
  scoreJson: unknown,
): string | null {
  if (scoreJson === null || typeof scoreJson !== 'object') return null;
  const s = scoreJson as Record<string, unknown>;
  switch (cueType) {
    case 'MCQ':
      // Grader writes `{ selected: number }`.
      if (typeof s.selected === 'number') return `Choice ${s.selected + 1}`;
      return null;
    case 'BLANKS': {
      // Grader writes `{ perBlank: boolean[] }`. We don't have the raw
      // answers on the attempt row — the BLANKS response isn't persisted
      // verbatim. Summarise as "N of M blanks correct".
      const perBlank = s.perBlank;
      if (Array.isArray(perBlank)) {
        const total = perBlank.length;
        const correct = perBlank.filter((v) => v === true).length;
        return `${correct}/${total} blanks correct`;
      }
      return null;
    }
    case 'MATCHING': {
      // Grader writes `{ correctPairs: number, totalPairs: number }`.
      const correctPairs = s.correctPairs;
      const totalPairs = s.totalPairs;
      /* istanbul ignore else -- grader always writes these fields as numbers; else branch defensive. */
      if (typeof correctPairs === 'number' && typeof totalPairs === 'number') {
        return `${correctPairs}/${totalPairs} pairs`;
      }
      /* istanbul ignore next */
      return null;
    }
    /* istanbul ignore next -- VOICE never reaches this path (ADR 0004). */
    case 'VOICE':
      return null;
  }
}

/** Parse an ISO date off a cached payload; tolerate either Date or string. */
function reviveDate(v: unknown): Date | null {
  if (v === null || v === undefined) return null;
  /* istanbul ignore next -- Date survives JSON round-trip as string; left for safety. */
  if (v instanceof Date) return v;
  if (typeof v === 'string') {
    const d = new Date(v);
    return Number.isFinite(d.getTime()) ? d : null;
  }
  /* istanbul ignore next -- non-string, non-Date, non-null inputs are not emitted by our code. */
  return null;
}

async function readCache<T>(
  redis: IORedis,
  key: string,
): Promise<T | null> {
  try {
    const raw = await redis.get(key);
    if (!raw) return null;
    return JSON.parse(raw) as T;
  } catch (err) {
    // Cache read errors are never fatal — fall through to the DB path.
    logger.warn({ err, key }, 'progress cache read failed');
    return null;
  }
}

async function writeCache<T>(
  redis: IORedis,
  key: string,
  value: T,
): Promise<void> {
  try {
    await redis.set(key, JSON.stringify(value), 'EX', PROGRESS_CACHE_TTL_SECONDS);
  } catch (err) {
    logger.warn({ err, key }, 'progress cache write failed');
  }
}

async function deleteCache(redis: IORedis, keys: string[]): Promise<void> {
  if (keys.length === 0) return;
  try {
    await redis.del(...keys);
  } catch (err) {
    logger.warn({ err, keys }, 'progress cache invalidation failed');
  }
}

export function createProgressService(
  prisma: PrismaClient = defaultPrisma,
  redis: IORedis = defaultRedis,
): ProgressService {
  // Built on-demand so the caller can inject a mocked prisma/redis in
  // unit tests and have the achievement evaluator share that mock.
  const achievements = createAchievementService(prisma);


  async function computeCourseSummary(
    userId: string,
    courseId: string,
  ): Promise<CourseProgressDetail> {
    const course = await prisma.course.findUnique({
      where: { id: courseId },
      select: {
        id: true,
        title: true,
        slug: true,
        coverImageUrl: true,
        videos: {
          orderBy: { orderIndex: 'asc' },
          select: {
            id: true,
            title: true,
            orderIndex: true,
            durationMs: true,
            cues: {
              select: { id: true },
            },
          },
        },
      },
    });
    if (!course) {
      throw new NotFoundError('Course not found');
    }

    const enrollment = await prisma.enrollment.findUnique({
      where: { userId_courseId: { userId, courseId } },
      select: { lastVideoId: true, lastPosMs: true },
    });
    if (!enrollment) {
      throw new NotFoundError('You are not enrolled in this course');
    }

    const videoIds = course.videos.map((v) => v.id);
    const videoIdSet = new Set(videoIds);

    // Attempts — grouped by video and by cue for lesson/course accuracy.
    const attempts = videoIds.length > 0
      ? await prisma.attempt.findMany({
          where: { userId, videoId: { in: videoIds } },
          select: {
            videoId: true,
            cueId: true,
            correct: true,
            submittedAt: true,
          },
          orderBy: { submittedAt: 'desc' },
        })
      : [];

    // Use the *most recent* attempt per cueId for scoring — otherwise the
    // learner could game accuracy by piling on wrong attempts. (Attempts
    // are additive on the wire; the grade is "latest answer".)
    const latestByCue = new Map<string, { correct: boolean; videoId: string }>();
    for (const a of attempts) {
      if (!latestByCue.has(a.cueId)) {
        latestByCue.set(a.cueId, { correct: a.correct, videoId: a.videoId });
      }
    }

    // Per-video attempt counts.
    const perVideo = new Map<string, { attempted: number; correct: number }>();
    for (const [, v] of latestByCue) {
      const bucket = perVideo.get(v.videoId) ?? { attempted: 0, correct: 0 };
      bucket.attempted += 1;
      if (v.correct) bucket.correct += 1;
      perVideo.set(v.videoId, bucket);
    }

    // Video completions: distinct videoIds on a `video_complete` event for
    // this user, filtered to videos in this course.
    const completions = videoIds.length > 0
      ? await prisma.analyticsEvent.findMany({
          where: {
            userId,
            eventType: 'video_complete',
            videoId: { in: videoIds },
          },
          select: { videoId: true },
          distinct: ['videoId'],
        })
      : [];
    const completedSet = new Set<string>();
    for (const c of completions) {
      if (c.videoId && videoIdSet.has(c.videoId)) {
        completedSet.add(c.videoId);
      }
    }

    const lessons: LessonProgressSummary[] = course.videos.map((v) => {
      const bucket = perVideo.get(v.id) ?? { attempted: 0, correct: 0 };
      const acc = safeAccuracy(bucket.correct, bucket.attempted);
      return {
        videoId: v.id,
        title: v.title,
        orderIndex: v.orderIndex,
        durationMs: v.durationMs ?? null,
        cueCount: v.cues.length,
        cuesAttempted: bucket.attempted,
        cuesCorrect: bucket.correct,
        accuracy: acc,
        grade: gradeFromAccuracy(acc),
        completed: completedSet.has(v.id),
      };
    });

    const videosTotal = course.videos.length;
    const videosCompleted = completedSet.size;
    const completionPct = videosTotal > 0
      ? videosCompleted / videosTotal
      : 0;

    let cuesAttempted = 0;
    let cuesCorrect = 0;
    for (const lesson of lessons) {
      cuesAttempted += lesson.cuesAttempted;
      cuesCorrect += lesson.cuesCorrect;
    }
    const accuracy = safeAccuracy(cuesCorrect, cuesAttempted);

    return {
      course: {
        id: course.id,
        title: course.title,
        slug: course.slug,
        coverImageUrl: course.coverImageUrl,
      },
      videosTotal,
      videosCompleted,
      completionPct,
      cuesAttempted,
      cuesCorrect,
      accuracy,
      grade: gradeFromAccuracy(accuracy),
      lastVideoId: enrollment.lastVideoId,
      lastPosMs: enrollment.lastPosMs,
      lessons,
    };
  }

  return {
    async getOverallProgress(userId) {
      const cached = await readCache<OverallProgress>(redis, overallKey(userId));
      if (cached) {
        // `recentlyUnlocked` is a one-shot "show a toast" signal — it
        // lives on the freshly-computed response, not on a cached one.
        // Surface an empty list on cache hit so the client doesn't
        // re-toast an achievement it already showed five minutes ago.
        // (The toast-queue on the client also dedupes by id.)
        return { ...cached, recentlyUnlocked: [] };
      }

      // Pull all enrollments. We compute per-course summaries in-process
      // rather than a single giant query — N+1 is real, but the number of
      // enrollments per user is modest (tens at most) and the per-course
      // summary is needed fully computed anyway.
      const enrollments = await prisma.enrollment.findMany({
        where: { userId },
        orderBy: [{ startedAt: 'desc' }],
        select: { courseId: true },
      });

      const perCourse: CourseProgressSummary[] = [];
      for (const e of enrollments) {
        try {
          const detail = await computeCourseSummary(userId, e.courseId);
          // Strip the per-lesson array for the overall view.
          const { lessons: _lessons, ...summary } = detail;
          void _lessons;
          perCourse.push(summary);
        } catch (err) {
          // A course that was deleted while the enrollment still exists
          // (shouldn't happen with `onDelete: Cascade` but defensive) —
          // skip rather than explode the whole dashboard.
          logger.warn(
            { err, courseId: e.courseId, userId },
            'progress: skipping course that failed to summarise',
          );
        }
      }

      let totalCuesAttempted = 0;
      let totalCuesCorrect = 0;
      let lessonsCompleted = 0;
      let totalWatchTimeMs = 0;
      for (const c of perCourse) {
        totalCuesAttempted += c.cuesAttempted;
        totalCuesCorrect += c.cuesCorrect;
        lessonsCompleted += c.videosCompleted;
      }

      // totalWatchTimeMs is computed off the `video_complete` events
      // directly (across all courses in one query) rather than summing
      // the per-course list, because per-course summaries don't expose
      // the durations of the *completed* videos.
      if (perCourse.length > 0) {
        const completedEvents = await prisma.analyticsEvent.findMany({
          where: {
            userId,
            eventType: 'video_complete',
          },
          select: { videoId: true },
          distinct: ['videoId'],
        });
        const completedVideoIds = completedEvents
          .map((e) => e.videoId)
          .filter((id): id is string => id !== null);
        if (completedVideoIds.length > 0) {
          const videos = await prisma.video.findMany({
            where: { id: { in: completedVideoIds } },
            select: { durationMs: true },
          });
          for (const v of videos) {
            if (v.durationMs) totalWatchTimeMs += v.durationMs;
          }
        }
      }

      const overallAccuracy = safeAccuracy(totalCuesCorrect, totalCuesAttempted);

      // Slice P3 — compute streak and evaluate achievements. The streak
      // helper is pulled from this same file (re-used by
      // `achievement.service`). Achievement evaluation is pull-not-push:
      // grading never triggers it, so hot-path cost stays zero.
      const streak = await computeStreakForUser(prisma, userId);
      let recentlyUnlocked: AchievementSummary[] = [];
      try {
        recentlyUnlocked = await achievements.evaluateAndUnlock(userId);
      } catch (err) {
        // Never let an achievement hiccup break the dashboard.
        logger.warn(
          { err, userId },
          'progress: achievement evaluation failed; continuing without recentlyUnlocked',
        );
      }

      const result: OverallProgress = {
        summary: {
          coursesEnrolled: enrollments.length,
          lessonsCompleted,
          totalCuesAttempted,
          totalCuesCorrect,
          overallAccuracy,
          overallGrade: gradeFromAccuracy(overallAccuracy),
          totalWatchTimeMs,
          currentStreak: streak.currentStreak,
          longestStreak: streak.longestStreak,
        },
        perCourse,
        recentlyUnlocked,
      };

      // Cache without the transient `recentlyUnlocked` so a subsequent
      // cache-hit returns an empty list instead of replaying the toast.
      const cacheable: OverallProgress = { ...result, recentlyUnlocked: [] };
      await writeCache(redis, overallKey(userId), cacheable);
      return result;
    },

    async getCourseProgress(userId, courseId) {
      const cached = await readCache<CourseProgressDetail>(
        redis,
        courseKey(userId, courseId),
      );
      if (cached) return cached;
      const result = await computeCourseSummary(userId, courseId);
      await writeCache(redis, courseKey(userId, courseId), result);
      return result;
    },

    async getLessonReview(userId, videoId) {
      const cacheKey = lessonKey(userId, videoId);
      const cached = await readCache<LessonReview>(redis, cacheKey);
      if (cached) {
        // Revive any ISO strings the caller may have stashed as Dates.
        cached.cues = cached.cues.map((c) => ({
          ...c,
          submittedAt: reviveDate(c.submittedAt),
        }));
        return cached;
      }

      const video = await prisma.video.findUnique({
        where: { id: videoId },
        select: {
          id: true,
          title: true,
          orderIndex: true,
          durationMs: true,
          courseId: true,
          course: {
            select: {
              id: true,
              title: true,
              slug: true,
            },
          },
          cues: {
            orderBy: [{ orderIndex: 'asc' }, { atMs: 'asc' }],
            select: {
              id: true,
              atMs: true,
              type: true,
              payload: true,
            },
          },
        },
      });
      if (!video) {
        throw new NotFoundError('Video not found');
      }

      // Access: accept if the user has any attempts on this video OR is
      // enrolled in the parent course. Designers testing their own cues
      // fall under the `any attempts` branch already.
      const attempts = await prisma.attempt.findMany({
        where: { userId, videoId },
        orderBy: { submittedAt: 'desc' },
        select: {
          cueId: true,
          correct: true,
          scoreJson: true,
          submittedAt: true,
        },
      });
      const hasAttempts = attempts.length > 0;
      let hasEnrollment = false;
      if (!hasAttempts) {
        const enr = await prisma.enrollment.findUnique({
          where: {
            userId_courseId: { userId, courseId: video.courseId },
          },
          select: { id: true },
        });
        hasEnrollment = enr !== null;
      }
      if (!hasAttempts && !hasEnrollment) {
        // Not enrolled + no attempts = they shouldn't even be seeing this
        // screen, and we must not leak the cue list. 404 is right here —
        // 403 would disclose the lesson exists.
        throw new NotFoundError('Lesson not found');
      }

      // Most-recent attempt per cue.
      const latestByCue = new Map<string, typeof attempts[number]>();
      for (const a of attempts) {
        if (!latestByCue.has(a.cueId)) latestByCue.set(a.cueId, a);
      }

      const cues: CueOutcome[] = video.cues.map((cue) => {
        const latest = latestByCue.get(cue.id) ?? null;
        const attempted = latest !== null;
        const prompt = promptFor(cue.type, cue.payload);

        // SECURITY: the correct-answer summary ONLY appears for attempted
        // cues. This mirrors the attempt-submission endpoint never echoing
        // `payload.answerIndex` back to the client. Do not relax this
        // without updating both integration and unit tests — the test
        // suite asserts it as a load-bearing invariant.
        const correctAnswerSummary = attempted
          ? correctAnswerSummaryFor(cue.type, cue.payload)
          : null;

        // For MCQ we also pass through the designer-authored explanation
        // to attempted cues only (same rationale: pre-leaking "Paris is
        // the capital of France" before the learner attempts would defeat
        // the cue). Explanation is surfaced on the graded-attempt path in
        // `attempt.service` today; here we re-expose it through the
        // review screen.
        let explanation: string | null = null;
        if (
          attempted &&
          cue.type === 'MCQ' &&
          cue.payload !== null &&
          typeof cue.payload === 'object'
        ) {
          const pe = (cue.payload as Record<string, unknown>).explanation;
          if (typeof pe === 'string') explanation = pe;
        }

        return {
          cueId: cue.id,
          atMs: cue.atMs,
          type: cue.type,
          prompt,
          attempted,
          correct: latest ? latest.correct : null,
          scoreJson: latest ? (latest.scoreJson as unknown) : null,
          submittedAt: latest ? latest.submittedAt : null,
          explanation,
          yourAnswerSummary: latest
            ? yourAnswerSummaryFor(cue.type, latest.scoreJson)
            : null,
          correctAnswerSummary,
        };
      });

      const cuesAttempted = cues.filter((c) => c.attempted).length;
      const cuesCorrect = cues.filter((c) => c.correct === true).length;
      const accuracy = safeAccuracy(cuesCorrect, cuesAttempted);

      const result: LessonReview = {
        video: {
          id: video.id,
          title: video.title,
          orderIndex: video.orderIndex,
          durationMs: video.durationMs ?? null,
          courseId: video.courseId,
        },
        course: video.course,
        score: {
          cuesAttempted,
          cuesCorrect,
          accuracy,
          grade: gradeFromAccuracy(accuracy),
        },
        cues,
      };
      await writeCache(redis, cacheKey, result);
      return result;
    },

    async invalidateForAttempt({ userId, videoId, courseId }) {
      await deleteCache(redis, [
        overallKey(userId),
        courseKey(userId, courseId),
        lessonKey(userId, videoId),
        // Slice P3 — achievements change with attempts too (cues_correct
        // / perfect_lesson / *_master criteria). Invalidate alongside.
        achievementsKey(userId),
      ]);
    },
  };
}

export const progressService = createProgressService();
