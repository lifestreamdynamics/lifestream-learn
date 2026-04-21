import type {
  Achievement,
  CueType,
  Prisma,
  PrismaClient,
  UserAchievement,
} from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { logger } from '@/config/logger';
import {
  computeStreakFromEvents,
  timezoneOffsetFromPreferences,
} from '@/services/progress.service.streak';

/**
 * Slice P3 — achievement unlock evaluator.
 *
 * Philosophy: **pull, not push.** Grading hot path never calls this —
 * the attempt submission endpoint stays fast. Unlocks are evaluated
 * when the client asks for progress (`GET /api/me/progress` /
 * `GET /api/me/achievements`). The tradeoff: a learner sees their
 * new unlock on next dashboard load rather than in the cue-submit
 * response, which is the correct UX anyway (toast on profile open
 * reads as "look what you earned" rather than a mid-quiz interruption).
 *
 * Criteria are discriminated-union JSON documents on the Achievement
 * row. Supported types (see seed catalog):
 *   - `lessons_completed` — distinct video_complete events ≥ count
 *   - `streak`            — currentStreak OR longestStreak ≥ days
 *   - `perfect_lesson`    — any lesson where every cue latest-attempt
 *                            is correct AND every cue was attempted
 *   - `course_complete`   — any enrolled course where every READY video
 *                            has a `video_complete` event
 *   - `cues_correct`      — distinct cues with latest-attempt-correct ≥ count
 *   - `cues_correct_by_type` — same, filtered by cue type
 *
 * The grading invariant from `progress.service.ts` ("latest attempt per
 * cue wins") applies here too — never double-count a cue.
 *
 * Coverage target: ≥95% (same grading-adjacent rule as P2). Enforced
 * per-file in `jest.config.js`.
 */

export interface AchievementSummary {
  id: string;
  title: string;
  iconKey: string;
  unlockedAt: Date;
}

export interface AchievementsList {
  unlocked: Achievement[];
  locked: Achievement[];
  unlockedAtByAchievementId: Record<string, string>;
}

export interface AchievementService {
  /**
   * Evaluate every criterion in the catalog against the current state
   * of this user; insert any newly-met rows (skipDuplicates so repeat
   * calls are idempotent). Returns **only the newly-unlocked rows** —
   * already-unlocked achievements are filtered out so the client can
   * toast new ones without de-dup logic.
   */
  evaluateAndUnlock(userId: string): Promise<AchievementSummary[]>;

  /** For the `GET /api/me/achievements` endpoint. */
  listForUser(userId: string): Promise<AchievementsList>;
}

// ---------- criterion evaluators ----------
//
// Each evaluator takes `(prisma, userId)` and returns `true` when the
// criterion is currently met. We avoid tearing across criteria: data is
// queried inside each evaluator. This is fine because `evaluateAndUnlock`
// runs on the progress-fetch path (pull, not hot path), so a handful of
// small queries per dashboard load is not a cost worth optimising for v1.
//
// All evaluators are pure w.r.t. the Achievement catalog — they don't
// write. The write step lives in `evaluateAndUnlock` which batches every
// newly-passing criterion into one `createMany`.

async function meetsLessonsCompleted(
  prisma: PrismaClient,
  userId: string,
  count: number,
): Promise<boolean> {
  const rows = await prisma.analyticsEvent.findMany({
    where: { userId, eventType: 'video_complete' },
    select: { videoId: true },
    distinct: ['videoId'],
  });
  // Count non-null videoIds; a malformed row with null videoId shouldn't
  // credit the learner.
  let n = 0;
  for (const r of rows) if (r.videoId !== null) n += 1;
  return n >= count;
}

async function meetsStreak(
  prisma: PrismaClient,
  userId: string,
  days: number,
): Promise<boolean> {
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
  const streak = computeStreakFromEvents(
    events.map((e) => e.occurredAt),
    { timezoneOffsetMinutes: tz },
  );
  // An achievement stays earned: once the learner ever hit the bar,
  // the row exists forever. So we check *longest* streak here, not
  // current — `streak_7` should NOT silently lock again if today's
  // streak drops.
  return streak.longestStreak >= days;
}

async function meetsPerfectLesson(
  prisma: PrismaClient,
  userId: string,
): Promise<boolean> {
  // Any video where: (a) learner has ≥1 attempt per cue, AND
  // (b) every cue's latest attempt is correct. We pull the candidate
  // set by grouping the learner's attempts per video, then verify
  // cue-count parity for each.
  const attempts = await prisma.attempt.findMany({
    where: { userId },
    select: { videoId: true, cueId: true, correct: true, submittedAt: true },
    orderBy: { submittedAt: 'desc' },
  });
  if (attempts.length === 0) return false;

  // Group by videoId, taking only the latest attempt per cue.
  type LatestByCue = Map<string, boolean>;
  const perVideo = new Map<string, LatestByCue>();
  for (const a of attempts) {
    let m = perVideo.get(a.videoId);
    if (!m) {
      m = new Map();
      perVideo.set(a.videoId, m);
    }
    if (!m.has(a.cueId)) {
      m.set(a.cueId, a.correct);
    }
  }

  // Candidate videos: those where every latest-attempt was correct.
  // Then check cue-count: all cues in the video must have an attempt.
  const candidates: string[] = [];
  for (const [videoId, byCue] of perVideo) {
    let allCorrect = true;
    for (const correct of byCue.values()) {
      if (!correct) {
        allCorrect = false;
        break;
      }
    }
    if (allCorrect) candidates.push(videoId);
  }
  if (candidates.length === 0) return false;

  const videos = await prisma.video.findMany({
    where: { id: { in: candidates } },
    select: {
      id: true,
      _count: { select: { cues: true } },
    },
  });
  for (const v of videos) {
    const attemptedCueCount = perVideo.get(v.id)?.size ?? 0;
    // Must have ≥1 cue (empty lessons don't qualify) and every cue
    // attempted.
    if (v._count.cues > 0 && attemptedCueCount === v._count.cues) {
      return true;
    }
  }
  return false;
}

async function meetsCourseComplete(
  prisma: PrismaClient,
  userId: string,
): Promise<boolean> {
  // Enrolled courses whose every READY video has a `video_complete`
  // event for this user.
  const enrollments = await prisma.enrollment.findMany({
    where: { userId },
    select: {
      course: {
        select: {
          id: true,
          videos: {
            where: { status: 'READY' },
            select: { id: true },
          },
        },
      },
    },
  });
  if (enrollments.length === 0) return false;

  const completedEvents = await prisma.analyticsEvent.findMany({
    where: { userId, eventType: 'video_complete' },
    select: { videoId: true },
    distinct: ['videoId'],
  });
  const completedVideoIds = new Set<string>();
  for (const e of completedEvents) {
    if (e.videoId) completedVideoIds.add(e.videoId);
  }

  for (const e of enrollments) {
    const vids = e.course.videos;
    if (vids.length === 0) continue; // empty course doesn't qualify
    let all = true;
    for (const v of vids) {
      if (!completedVideoIds.has(v.id)) {
        all = false;
        break;
      }
    }
    if (all) return true;
  }
  return false;
}

async function meetsCuesCorrect(
  prisma: PrismaClient,
  userId: string,
  count: number,
  opts: { cueType?: CueType } = {},
): Promise<boolean> {
  // Count distinct cues whose *latest* attempt is correct (P2 rule).
  const attempts = await prisma.attempt.findMany({
    where: {
      userId,
      ...(opts.cueType ? { cue: { type: opts.cueType } } : {}),
    },
    select: { cueId: true, correct: true, submittedAt: true },
    orderBy: { submittedAt: 'desc' },
  });
  const latestByCue = new Map<string, boolean>();
  for (const a of attempts) {
    if (!latestByCue.has(a.cueId)) latestByCue.set(a.cueId, a.correct);
  }
  let n = 0;
  for (const correct of latestByCue.values()) if (correct) n += 1;
  return n >= count;
}

// ---------- criterion dispatcher ----------

interface CriteriaDoc {
  type: string;
  [k: string]: unknown;
}

function parseCriteria(raw: unknown): CriteriaDoc | null {
  if (raw === null || typeof raw !== 'object') return null;
  const obj = raw as Record<string, unknown>;
  if (typeof obj.type !== 'string') return null;
  return obj as CriteriaDoc;
}

async function evaluateCriterion(
  prisma: PrismaClient,
  userId: string,
  raw: unknown,
): Promise<boolean> {
  const c = parseCriteria(raw);
  if (!c) return false;
  switch (c.type) {
    case 'lessons_completed': {
      const n = typeof c.count === 'number' ? c.count : 1;
      return meetsLessonsCompleted(prisma, userId, n);
    }
    case 'streak': {
      const days = typeof c.days === 'number' ? c.days : 1;
      return meetsStreak(prisma, userId, days);
    }
    case 'perfect_lesson':
      return meetsPerfectLesson(prisma, userId);
    case 'course_complete':
      return meetsCourseComplete(prisma, userId);
    case 'cues_correct': {
      const n = typeof c.count === 'number' ? c.count : 1;
      return meetsCuesCorrect(prisma, userId, n);
    }
    case 'cues_correct_by_type': {
      const n = typeof c.count === 'number' ? c.count : 1;
      const cueType =
        c.cueType === 'MCQ' ||
        c.cueType === 'MATCHING' ||
        c.cueType === 'BLANKS' ||
        c.cueType === 'VOICE'
          ? (c.cueType as CueType)
          : undefined;
      if (!cueType) return false;
      return meetsCuesCorrect(prisma, userId, n, { cueType });
    }
    default:
      // Unknown criterion type — log but never crash the dashboard.
      logger.warn({ type: c.type }, 'achievement: unknown criterion type');
      return false;
  }
}

// ---------- service factory ----------

export function createAchievementService(
  prisma: PrismaClient = defaultPrisma,
): AchievementService {
  return {
    async evaluateAndUnlock(userId) {
      const [catalog, alreadyUnlocked] = await Promise.all([
        prisma.achievement.findMany({
          select: {
            id: true,
            title: true,
            iconKey: true,
            criteriaJson: true,
          },
        }),
        prisma.userAchievement.findMany({
          where: { userId },
          select: { achievementId: true },
        }),
      ]);
      const alreadyUnlockedIds = new Set(
        alreadyUnlocked.map((r) => r.achievementId),
      );

      // Evaluate only the *still-locked* ones — saves work once the
      // catalog fills up and a learner has most of them.
      const toEvaluate = catalog.filter((a) => !alreadyUnlockedIds.has(a.id));
      const newlyUnlocked: Array<{
        id: string;
        title: string;
        iconKey: string;
      }> = [];
      for (const ach of toEvaluate) {
        try {
          const ok = await evaluateCriterion(prisma, userId, ach.criteriaJson);
          if (ok) {
            newlyUnlocked.push({
              id: ach.id,
              title: ach.title,
              iconKey: ach.iconKey,
            });
          }
        } catch (err) {
          // One bad criterion shouldn't sink every unlock in the batch.
          logger.warn(
            { err, userId, achievementId: ach.id },
            'achievement: criterion evaluation failed',
          );
        }
      }
      if (newlyUnlocked.length === 0) return [];

      // Insert with skipDuplicates for a concurrency belt-and-braces:
      // two dashboards open in parallel could both evaluate true; the
      // composite PK (userId, achievementId) makes the second a no-op.
      const rows: Prisma.UserAchievementCreateManyInput[] = newlyUnlocked.map(
        (n) => ({ userId, achievementId: n.id }),
      );
      try {
        await prisma.userAchievement.createMany({
          data: rows,
          skipDuplicates: true,
        });
      } catch (err) {
        logger.warn(
          { err, userId, count: rows.length },
          'achievement: createMany failed; continuing without unlock toast',
        );
        return [];
      }

      // Read back the rows we just inserted for the newly-unlocked set —
      // this gives us the authoritative `unlockedAt` timestamp the DB
      // wrote with the default, so the client toast shows the true
      // unlock time (not `new Date()` on the API node).
      const persisted = await prisma.userAchievement.findMany({
        where: {
          userId,
          achievementId: { in: newlyUnlocked.map((n) => n.id) },
        },
        select: { achievementId: true, unlockedAt: true },
      });
      const unlockedAtById = new Map<string, Date>();
      for (const p of persisted) {
        unlockedAtById.set(p.achievementId, p.unlockedAt);
      }

      return newlyUnlocked.map((n) => ({
        id: n.id,
        title: n.title,
        iconKey: n.iconKey,
        unlockedAt: unlockedAtById.get(n.id) ?? new Date(),
      }));
    },

    async listForUser(userId) {
      const [catalog, unlocks] = await Promise.all([
        prisma.achievement.findMany({
          orderBy: { id: 'asc' },
        }),
        prisma.userAchievement.findMany({
          where: { userId },
          select: { achievementId: true, unlockedAt: true },
        }),
      ]);
      const unlockedSet = new Set(unlocks.map((u) => u.achievementId));
      const unlockedAtByAchievementId: Record<string, string> = {};
      for (const u of unlocks) {
        unlockedAtByAchievementId[u.achievementId] = u.unlockedAt.toISOString();
      }
      const unlocked: Achievement[] = [];
      const locked: Achievement[] = [];
      for (const a of catalog) {
        if (unlockedSet.has(a.id)) unlocked.push(a);
        else locked.push(a);
      }
      return { unlocked, locked, unlockedAtByAchievementId };
    },
  };
}

// Re-export UserAchievement for callers that want the full row shape.
export type { UserAchievement };

export const achievementService = createAchievementService();
