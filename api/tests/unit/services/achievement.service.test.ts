import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import { createAchievementService } from '@/services/achievement.service';

// ---------- mocks ----------

type MockPrisma = {
  achievement: { findMany: jest.Mock };
  userAchievement: {
    findMany: jest.Mock;
    createMany: jest.Mock;
  };
  analyticsEvent: { findMany: jest.Mock };
  attempt: { findMany: jest.Mock };
  user: { findUnique: jest.Mock };
  enrollment: { findMany: jest.Mock };
  video: { findMany: jest.Mock };
};

function buildPrisma(): MockPrisma {
  return {
    achievement: { findMany: jest.fn().mockResolvedValue([]) },
    userAchievement: {
      findMany: jest.fn().mockResolvedValue([]),
      createMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
    analyticsEvent: { findMany: jest.fn().mockResolvedValue([]) },
    attempt: { findMany: jest.fn().mockResolvedValue([]) },
    user: { findUnique: jest.fn().mockResolvedValue({ preferences: null }) },
    enrollment: { findMany: jest.fn().mockResolvedValue([]) },
    video: { findMany: jest.fn().mockResolvedValue([]) },
  };
}

function makeService(overrides?: { prisma?: MockPrisma }) {
  const prisma = overrides?.prisma ?? buildPrisma();
  const svc = createAchievementService(prisma as unknown as PrismaClient);
  return { prisma, svc };
}

// Catalog helpers — each test seeds only the achievements relevant to
// the criterion under test. Pattern mirrors `progress.service.test.ts`
// (one describe block per behaviour).

const USER_ID = '11111111-1111-4111-8111-111111111111';
const VIDEO_ID_1 = '22222222-2222-4222-8222-222222222222';
const VIDEO_ID_2 = '33333333-3333-4333-8333-333333333333';
const CUE_A = '44444444-4444-4444-8444-444444444444';
const CUE_B = '55555555-5555-4555-8555-555555555555';
const CUE_C = '66666666-6666-4666-8666-666666666666';
const COURSE_ID = '77777777-7777-4777-8777-777777777777';

function stubCatalog(
  prisma: MockPrisma,
  catalog: Array<{
    id: string;
    title: string;
    iconKey: string;
    criteriaJson: Record<string, unknown>;
  }>,
): void {
  prisma.achievement.findMany.mockImplementation((args: unknown) => {
    const a = args as { orderBy?: unknown };
    // `listForUser` passes `orderBy`; `evaluateAndUnlock` does not.
    // Return the same catalog either way.
    void a;
    return Promise.resolve(
      catalog.map((c) => ({
        id: c.id,
        title: c.title,
        description: `desc ${c.id}`,
        iconKey: c.iconKey,
        criteriaJson: c.criteriaJson,
        createdAt: new Date(0),
        updatedAt: new Date(0),
      })),
    );
  });
}

function stubReadbackForNew(
  prisma: MockPrisma,
  newlyUnlocked: string[],
): void {
  // The service does two `userAchievement.findMany` calls: one at the
  // start for the already-unlocked set, and one after createMany to
  // read back the real unlockedAt. This helper sets up both in order.
  const existingCall = jest.fn().mockResolvedValueOnce([]);
  void existingCall;
  prisma.userAchievement.findMany.mockImplementation((args: unknown) => {
    const a = args as { where?: { achievementId?: unknown } };
    if (a.where?.achievementId) {
      return Promise.resolve(
        newlyUnlocked.map((id) => ({
          achievementId: id,
          unlockedAt: new Date('2026-04-20T00:00:00Z'),
        })),
      );
    }
    return Promise.resolve([]);
  });
}

// ---------- evaluateAndUnlock criterion coverage ----------

describe('evaluateAndUnlock — criterion types', () => {
  it('lessons_completed: unlocks when distinct video_completes ≥ count', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'first_lesson',
        title: 'First Lesson',
        iconKey: 'school',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    ]);
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_1 },
    ]);
    stubReadbackForNew(prisma, ['first_lesson']);

    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('first_lesson');
    expect(prisma.userAchievement.createMany).toHaveBeenCalledWith({
      data: [{ userId: USER_ID, achievementId: 'first_lesson' }],
      skipDuplicates: true,
    });
  });

  it('lessons_completed: stays locked below threshold', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'need5',
        title: 'Five',
        iconKey: 'school',
        criteriaJson: { type: 'lessons_completed', count: 5 },
      },
    ]);
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_1 },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('streak: unlocks when longestStreak ≥ days', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'streak_3',
        title: '3-Day Streak',
        iconKey: 'local_fire_department',
        criteriaJson: { type: 'streak', days: 3 },
      },
    ]);
    // 3 consecutive days ending today.
    const now = Date.now();
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { occurredAt: new Date(now) },
      { occurredAt: new Date(now - 86_400_000) },
      { occurredAt: new Date(now - 2 * 86_400_000) },
    ]);
    stubReadbackForNew(prisma, ['streak_3']);

    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['streak_3']);
  });

  it('streak: does not unlock when only 2 days', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'streak_3',
        title: '3-Day Streak',
        iconKey: 'x',
        criteriaJson: { type: 'streak', days: 3 },
      },
    ]);
    const now = Date.now();
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { occurredAt: new Date(now) },
      { occurredAt: new Date(now - 86_400_000) },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('perfect_lesson: every cue in a video attempted + all correct', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'perfect_quiz',
        title: 'Perfect Quiz',
        iconKey: 'verified',
        criteriaJson: { type: 'perfect_lesson' },
      },
    ]);
    prisma.attempt.findMany.mockResolvedValue([
      {
        videoId: VIDEO_ID_1,
        cueId: CUE_A,
        correct: true,
        submittedAt: new Date('2026-04-10T00:00:00Z'),
      },
      {
        videoId: VIDEO_ID_1,
        cueId: CUE_B,
        correct: true,
        submittedAt: new Date('2026-04-10T00:00:00Z'),
      },
    ]);
    prisma.video.findMany.mockResolvedValue([
      { id: VIDEO_ID_1, _count: { cues: 2 } },
    ]);
    stubReadbackForNew(prisma, ['perfect_quiz']);

    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['perfect_quiz']);
  });

  it('perfect_lesson: one wrong answer blocks the unlock', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'perfect_quiz',
        title: 'PQ',
        iconKey: 'v',
        criteriaJson: { type: 'perfect_lesson' },
      },
    ]);
    prisma.attempt.findMany.mockResolvedValue([
      {
        videoId: VIDEO_ID_1,
        cueId: CUE_A,
        correct: true,
        submittedAt: new Date(),
      },
      {
        videoId: VIDEO_ID_1,
        cueId: CUE_B,
        correct: false,
        submittedAt: new Date(),
      },
    ]);
    prisma.video.findMany.mockResolvedValue([
      { id: VIDEO_ID_1, _count: { cues: 2 } },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('perfect_lesson: latest-attempt-wins (redemption)', async () => {
    // Older wrong, newer right — should be perfect under "latest wins".
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'perfect_quiz',
        title: 'PQ',
        iconKey: 'v',
        criteriaJson: { type: 'perfect_lesson' },
      },
    ]);
    prisma.attempt.findMany.mockResolvedValue([
      {
        videoId: VIDEO_ID_1,
        cueId: CUE_A,
        correct: true,
        submittedAt: new Date('2026-04-11T00:00:00Z'),
      },
      {
        videoId: VIDEO_ID_1,
        cueId: CUE_A,
        correct: false,
        submittedAt: new Date('2026-04-10T00:00:00Z'),
      },
    ]);
    prisma.video.findMany.mockResolvedValue([
      { id: VIDEO_ID_1, _count: { cues: 1 } },
    ]);
    stubReadbackForNew(prisma, ['perfect_quiz']);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['perfect_quiz']);
  });

  it('perfect_lesson: empty lesson does not qualify', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'perfect_quiz',
        title: 'PQ',
        iconKey: 'v',
        criteriaJson: { type: 'perfect_lesson' },
      },
    ]);
    prisma.attempt.findMany.mockResolvedValue([]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('course_complete: every READY video has a completion event', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'course_complete',
        title: 'Course Complete',
        iconKey: 'workspace_premium',
        criteriaJson: { type: 'course_complete' },
      },
    ]);
    prisma.enrollment.findMany.mockResolvedValue([
      {
        course: {
          id: COURSE_ID,
          videos: [{ id: VIDEO_ID_1 }, { id: VIDEO_ID_2 }],
        },
      },
    ]);
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_1 },
      { videoId: VIDEO_ID_2 },
    ]);
    stubReadbackForNew(prisma, ['course_complete']);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['course_complete']);
  });

  it('course_complete: one missing video blocks the unlock', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'course_complete',
        title: 'CC',
        iconKey: 'w',
        criteriaJson: { type: 'course_complete' },
      },
    ]);
    prisma.enrollment.findMany.mockResolvedValue([
      {
        course: {
          id: COURSE_ID,
          videos: [{ id: VIDEO_ID_1 }, { id: VIDEO_ID_2 }],
        },
      },
    ]);
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_1 },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('course_complete: empty course does not qualify', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'course_complete',
        title: 'CC',
        iconKey: 'w',
        criteriaJson: { type: 'course_complete' },
      },
    ]);
    prisma.enrollment.findMany.mockResolvedValue([
      { course: { id: COURSE_ID, videos: [] } },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('cues_correct: counts distinct cues where latest attempt is correct', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: '100_cues_correct',
        title: 'Century Club',
        iconKey: 'military_tech',
        criteriaJson: { type: 'cues_correct', count: 2 },
      },
    ]);
    prisma.attempt.findMany.mockResolvedValue([
      // latest correct on CUE_A
      {
        cueId: CUE_A,
        correct: true,
        submittedAt: new Date('2026-04-11T00:00:00Z'),
      },
      // older wrong on CUE_A (latest-wins ignores)
      {
        cueId: CUE_A,
        correct: false,
        submittedAt: new Date('2026-04-10T00:00:00Z'),
      },
      // latest correct on CUE_B
      {
        cueId: CUE_B,
        correct: true,
        submittedAt: new Date('2026-04-11T00:00:00Z'),
      },
    ]);
    stubReadbackForNew(prisma, ['100_cues_correct']);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['100_cues_correct']);
  });

  it('cues_correct_by_type: filters by cue type', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'mcq_master',
        title: 'MCQ Master',
        iconKey: 'radio_button_checked',
        criteriaJson: {
          type: 'cues_correct_by_type',
          cueType: 'MCQ',
          count: 1,
        },
      },
    ]);
    prisma.attempt.findMany.mockImplementation((args: unknown) => {
      const a = args as { where: { cue?: { type: string } } };
      // Service must pass a `cue.type` filter through to Prisma.
      expect(a.where.cue).toEqual({ type: 'MCQ' });
      return Promise.resolve([
        { cueId: CUE_A, correct: true, submittedAt: new Date() },
      ]);
    });
    stubReadbackForNew(prisma, ['mcq_master']);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['mcq_master']);
  });

  it('cues_correct_by_type: rejects unknown cueType gracefully', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'nope',
        title: 'No',
        iconKey: 'x',
        criteriaJson: {
          type: 'cues_correct_by_type',
          cueType: 'LIMERICK',
          count: 1,
        },
      },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });
});

// ---------- edge cases ----------

describe('evaluateAndUnlock — edge cases', () => {
  it('user with no data: returns empty', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'first_lesson',
        title: 'FL',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('user with partial progress: unlocks only what they have earned', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'first_lesson',
        title: 'FL',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
      {
        id: 'need5',
        title: 'Five',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 5 },
      },
    ]);
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_1 },
    ]);
    stubReadbackForNew(prisma, ['first_lesson']);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['first_lesson']);
  });

  it('idempotent: a second call after an unlock returns empty', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'first_lesson',
        title: 'FL',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    ]);
    // Simulate first_lesson already in UserAchievement.
    prisma.userAchievement.findMany.mockImplementation((args: unknown) => {
      const a = args as { where?: { achievementId?: unknown } };
      if (a.where?.achievementId) return Promise.resolve([]);
      return Promise.resolve([{ achievementId: 'first_lesson' }]);
    });
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_1 },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
    // And we never re-insert (the short-circuit filter kicks in first).
    expect(prisma.userAchievement.createMany).not.toHaveBeenCalled();
  });

  it('newly-unlocked filter: pre-existing unlocks excluded from the return', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'first_lesson',
        title: 'FL',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
      {
        id: 'second',
        title: 'Two',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    ]);
    // `first_lesson` already unlocked. Only `second` qualifies as new.
    prisma.userAchievement.findMany.mockImplementation((args: unknown) => {
      const a = args as { where?: { achievementId?: unknown } };
      if (a.where?.achievementId) {
        return Promise.resolve([
          { achievementId: 'second', unlockedAt: new Date(0) },
        ]);
      }
      return Promise.resolve([{ achievementId: 'first_lesson' }]);
    });
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_1 },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['second']);
  });

  it('skips malformed criteriaJson without crashing', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'bad',
        title: 'B',
        iconKey: 's',
        // Missing `type` key.
        criteriaJson: { days: 3 } as Record<string, unknown>,
      },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('unknown criterion type: logs and stays locked', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'bogus',
        title: 'B',
        iconKey: 's',
        criteriaJson: { type: 'totally_made_up' },
      },
    ]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('one bad criterion does not sink others', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'bad',
        title: 'B',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
      {
        id: 'good',
        title: 'G',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    ]);
    // First lookup is the "already unlocked" set (returns empty); the
    // next two are per-criterion evaluations. Throw on the first
    // criterion-scoped `analyticsEvent.findMany` call so the first
    // achievement errors out; the second still resolves.
    let call = 0;
    prisma.analyticsEvent.findMany.mockImplementation(() => {
      call += 1;
      if (call === 1) return Promise.reject(new Error('db flake'));
      return Promise.resolve([{ videoId: VIDEO_ID_1 }]);
    });
    stubReadbackForNew(prisma, ['good']);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['good']);
  });

  it('createMany failure: empty return, no throw', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'first_lesson',
        title: 'FL',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    ]);
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_1 },
    ]);
    prisma.userAchievement.createMany.mockRejectedValue(
      new Error('pk violation'),
    );
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('falls back to `new Date()` when readback is missing a row', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'first_lesson',
        title: 'FL',
        iconKey: 'school',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    ]);
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_1 },
    ]);
    // Readback returns empty despite createMany claiming success —
    // shouldn't happen in production but the service defends.
    prisma.userAchievement.findMany.mockImplementation((args: unknown) => {
      const a = args as { where?: { achievementId?: unknown } };
      if (a.where?.achievementId) return Promise.resolve([]);
      return Promise.resolve([]);
    });
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toHaveLength(1);
    expect(result[0].unlockedAt).toBeInstanceOf(Date);
  });

  it('includes non-null videoId filter for lessons_completed', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'first_lesson',
        title: 'FL',
        iconKey: 's',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    ]);
    // Include a null videoId row; it must NOT credit the learner.
    prisma.analyticsEvent.findMany.mockResolvedValue([{ videoId: null }]);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result).toEqual([]);
  });

  it('cues_correct default count (missing count) is 1', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 'cc',
        title: 'CC',
        iconKey: 's',
        criteriaJson: { type: 'cues_correct' }, // count missing → default 1
      },
    ]);
    prisma.attempt.findMany.mockResolvedValue([
      { cueId: CUE_C, correct: true, submittedAt: new Date() },
    ]);
    stubReadbackForNew(prisma, ['cc']);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['cc']);
  });

  it('streak default days (missing days) is 1', async () => {
    const { prisma, svc } = makeService();
    stubCatalog(prisma, [
      {
        id: 's1',
        title: 'S',
        iconKey: 's',
        criteriaJson: { type: 'streak' },
      },
    ]);
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { occurredAt: new Date() },
    ]);
    stubReadbackForNew(prisma, ['s1']);
    const result = await svc.evaluateAndUnlock(USER_ID);
    expect(result.map((r) => r.id)).toEqual(['s1']);
  });
});

// ---------- listForUser ----------

describe('listForUser', () => {
  it('partitions into unlocked + locked with unlockedAt map', async () => {
    const { prisma, svc } = makeService();
    prisma.achievement.findMany.mockResolvedValue([
      {
        id: 'a1',
        title: 'A1',
        description: 'd1',
        iconKey: 'i1',
        criteriaJson: { type: 'lessons_completed', count: 1 },
        createdAt: new Date(0),
        updatedAt: new Date(0),
      },
      {
        id: 'a2',
        title: 'A2',
        description: 'd2',
        iconKey: 'i2',
        criteriaJson: { type: 'lessons_completed', count: 100 },
        createdAt: new Date(0),
        updatedAt: new Date(0),
      },
    ]);
    prisma.userAchievement.findMany.mockResolvedValueOnce([
      {
        achievementId: 'a1',
        unlockedAt: new Date('2026-04-15T10:00:00Z'),
      },
    ]);
    const result = await svc.listForUser(USER_ID);
    expect(result.unlocked.map((a) => a.id)).toEqual(['a1']);
    expect(result.locked.map((a) => a.id)).toEqual(['a2']);
    expect(result.unlockedAtByAchievementId.a1).toBe(
      '2026-04-15T10:00:00.000Z',
    );
    expect(result.unlockedAtByAchievementId.a2).toBeUndefined();
  });

  it('empty catalog → both lists empty', async () => {
    const { svc } = makeService();
    const result = await svc.listForUser(USER_ID);
    expect(result.unlocked).toEqual([]);
    expect(result.locked).toEqual([]);
    expect(result.unlockedAtByAchievementId).toEqual({});
  });
});
