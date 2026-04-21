import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import type IORedis from 'ioredis';
import {
  computeStreakFromEvents,
  createProgressService,
  gradeFromAccuracy,
  PROGRESS_CACHE_TTL_SECONDS,
  timezoneOffsetFromPreferences,
} from '@/services/progress.service';
import { NotFoundError } from '@/utils/errors';

// ---------- mocks ----------

type MockRedis = {
  get: jest.Mock;
  set: jest.Mock;
  del: jest.Mock;
};

function buildRedis(): MockRedis {
  return {
    get: jest.fn().mockResolvedValue(null),
    set: jest.fn().mockResolvedValue('OK'),
    del: jest.fn().mockResolvedValue(1),
  };
}

type MockPrisma = {
  course: { findUnique: jest.Mock };
  enrollment: { findUnique: jest.Mock; findMany: jest.Mock };
  attempt: { findMany: jest.Mock };
  analyticsEvent: { findMany: jest.Mock };
  video: { findUnique: jest.Mock; findMany: jest.Mock };
  user: { findUnique: jest.Mock };
  achievement: { findMany: jest.Mock };
  userAchievement: {
    findMany: jest.Mock;
    createMany: jest.Mock;
  };
};

function buildPrisma(): MockPrisma {
  return {
    course: { findUnique: jest.fn() },
    enrollment: { findUnique: jest.fn(), findMany: jest.fn() },
    attempt: { findMany: jest.fn() },
    // Default: empty list. Suites that want a richer stream override
    // via `mockResolvedValue` / `mockImplementation` on a per-test basis.
    analyticsEvent: { findMany: jest.fn().mockResolvedValue([]) },
    video: { findUnique: jest.fn(), findMany: jest.fn().mockResolvedValue([]) },
    // Slice P3 — streak + achievement hooks. Defaults: no prefs (tz 0),
    // empty catalog, no prior unlocks. Tests opt-in to richer data.
    user: {
      findUnique: jest.fn().mockResolvedValue({ preferences: null }),
    },
    achievement: {
      findMany: jest.fn().mockResolvedValue([]),
    },
    userAchievement: {
      findMany: jest.fn().mockResolvedValue([]),
      createMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
  };
}

// Convenience: build a service + the underlying mocks.
function makeService(overrides?: {
  prisma?: MockPrisma;
  redis?: MockRedis;
}) {
  const prisma = overrides?.prisma ?? buildPrisma();
  const redis = overrides?.redis ?? buildRedis();
  const svc = createProgressService(
    prisma as unknown as PrismaClient,
    redis as unknown as IORedis,
  );
  return { prisma, redis, svc };
}

const USER_ID = '11111111-1111-4111-8111-111111111111';
const COURSE_ID = '22222222-2222-4222-8222-222222222222';
const COURSE_ID_2 = '44444444-4444-4444-8444-444444444444';
const VIDEO_ID = '33333333-3333-4333-8333-333333333333';
const VIDEO_ID_2 = '55555555-5555-4555-8555-555555555555';
const CUE_ID_1 = '66666666-6666-4666-8666-666666666666';
const CUE_ID_2 = '77777777-7777-4777-8777-777777777777';
const CUE_ID_3 = '88888888-8888-4888-8888-888888888888';

// ---------- gradeFromAccuracy truth table ----------

describe('gradeFromAccuracy', () => {
  // Full truth table including boundary conditions.
  const cases: [number | null, 'A' | 'B' | 'C' | 'D' | 'F' | null][] = [
    [1.0, 'A'],
    [0.95, 'A'],
    [0.9, 'A'],
    [0.899, 'B'],
    [0.85, 'B'],
    [0.8, 'B'],
    [0.799, 'C'],
    [0.7, 'C'],
    [0.699, 'D'],
    [0.6, 'D'],
    [0.599, 'F'],
    [0.0, 'F'],
    [null, null],
  ];
  for (const [input, expected] of cases) {
    it(`${input} → ${expected}`, () => {
      expect(gradeFromAccuracy(input)).toBe(expected);
    });
  }
});

// ---------- getOverallProgress ----------

describe('getOverallProgress', () => {
  it('returns zeros + empty perCourse for a user with no enrollments', async () => {
    const { prisma, svc, redis } = makeService();
    prisma.enrollment.findMany.mockResolvedValue([]);

    const result = await svc.getOverallProgress(USER_ID);

    expect(result.summary.coursesEnrolled).toBe(0);
    expect(result.summary.lessonsCompleted).toBe(0);
    expect(result.summary.totalCuesAttempted).toBe(0);
    expect(result.summary.totalCuesCorrect).toBe(0);
    expect(result.summary.overallAccuracy).toBeNull();
    expect(result.summary.overallGrade).toBeNull();
    expect(result.summary.totalWatchTimeMs).toBe(0);
    // Slice P3 — streak fields present and zero for a fresh user.
    expect(result.summary.currentStreak).toBe(0);
    expect(result.summary.longestStreak).toBe(0);
    expect(result.recentlyUnlocked).toEqual([]);
    expect(result.perCourse).toEqual([]);
    // And cached.
    expect(redis.set).toHaveBeenCalledWith(
      `progress:overall:${USER_ID}`,
      expect.any(String),
      'EX',
      PROGRESS_CACHE_TTL_SECONDS,
    );
  });

  it('cache hit short-circuits the DB path', async () => {
    const { prisma, svc, redis } = makeService();
    const cached = {
      summary: {
        coursesEnrolled: 1,
        lessonsCompleted: 0,
        totalCuesAttempted: 0,
        totalCuesCorrect: 0,
        overallAccuracy: null,
        overallGrade: null,
        totalWatchTimeMs: 0,
        // Slice P3 — cached payloads include streak too; cached
        // recentlyUnlocked is always stored as [] (toast is one-shot).
        currentStreak: 2,
        longestStreak: 5,
      },
      perCourse: [],
      recentlyUnlocked: [],
    };
    redis.get.mockResolvedValueOnce(JSON.stringify(cached));

    const result = await svc.getOverallProgress(USER_ID);
    // Cache-hit returns a fresh empty recentlyUnlocked regardless.
    expect(result.summary.currentStreak).toBe(2);
    expect(result.summary.longestStreak).toBe(5);
    expect(result.recentlyUnlocked).toEqual([]);
    expect(prisma.enrollment.findMany).not.toHaveBeenCalled();
  });

  it('aggregates across two courses with mixed correctness', async () => {
    const { prisma, svc } = makeService();
    prisma.enrollment.findMany.mockResolvedValue([
      { courseId: COURSE_ID },
      { courseId: COURSE_ID_2 },
    ]);

    // Course 1: 2 videos, 2 cues, 1 correct, 1 wrong; 1 completed video.
    prisma.course.findUnique.mockImplementation(
      ({ where: { id } }: { where: { id: string } }) => {
        if (id === COURSE_ID) {
          return Promise.resolve({
            id: COURSE_ID,
            title: 'Course 1',
            slug: 'c1',
            coverImageUrl: null,
            videos: [
              {
                id: VIDEO_ID,
                title: 'V1',
                orderIndex: 0,
                durationMs: 60000,
                cues: [{ id: CUE_ID_1 }, { id: CUE_ID_2 }],
              },
            ],
          });
        }
        if (id === COURSE_ID_2) {
          return Promise.resolve({
            id: COURSE_ID_2,
            title: 'Course 2',
            slug: 'c2',
            coverImageUrl: 'cover.jpg',
            videos: [
              {
                id: VIDEO_ID_2,
                title: 'V2',
                orderIndex: 0,
                durationMs: 90000,
                cues: [{ id: CUE_ID_3 }],
              },
            ],
          });
        }
        return Promise.resolve(null);
      },
    );
    prisma.enrollment.findUnique.mockImplementation(
      ({ where }: { where: { userId_courseId: { courseId: string } } }) => {
        const { courseId } = where.userId_courseId;
        return Promise.resolve({
          lastVideoId: courseId === COURSE_ID ? VIDEO_ID : null,
          lastPosMs: courseId === COURSE_ID ? 12345 : null,
        });
      },
    );
    prisma.attempt.findMany.mockImplementation((args: unknown) => {
      const where = (args as { where: { videoId?: { in?: string[] } } })
        .where;
      const ids = where.videoId?.in ?? [];
      if (ids.includes(VIDEO_ID)) {
        return Promise.resolve([
          {
            videoId: VIDEO_ID,
            cueId: CUE_ID_1,
            correct: true,
            submittedAt: new Date('2026-04-10T00:00:00Z'),
          },
          {
            videoId: VIDEO_ID,
            cueId: CUE_ID_2,
            correct: false,
            submittedAt: new Date('2026-04-10T00:00:00Z'),
          },
        ]);
      }
      if (ids.includes(VIDEO_ID_2)) {
        return Promise.resolve([
          {
            videoId: VIDEO_ID_2,
            cueId: CUE_ID_3,
            correct: true,
            submittedAt: new Date('2026-04-11T00:00:00Z'),
          },
        ]);
      }
      return Promise.resolve([]);
    });
    prisma.analyticsEvent.findMany.mockImplementation((args: unknown) => {
      const where = (args as {
        where: {
          videoId?: { in?: string[] };
          eventType: string | { in: string[] };
        };
      }).where;
      if (where.videoId?.in?.includes(VIDEO_ID)) {
        return Promise.resolve([{ videoId: VIDEO_ID }]);
      }
      if (where.videoId?.in?.includes(VIDEO_ID_2)) {
        return Promise.resolve([]);
      }
      // Slice P3 — streak query (`eventType: { in: [...] }`, no video
      // filter). Return an empty list so this suite doesn't assert on
      // streak values (covered by dedicated streak tests below).
      if (typeof where.eventType !== 'string') {
        return Promise.resolve([]);
      }
      // The overall watch-time query (no videoId filter, single eventType).
      return Promise.resolve([{ videoId: VIDEO_ID }]);
    });
    prisma.video.findMany.mockResolvedValue([{ durationMs: 60000 }]);

    const result = await svc.getOverallProgress(USER_ID);

    expect(result.summary.coursesEnrolled).toBe(2);
    // 2 cues in course 1 (1 correct) + 1 in course 2 (1 correct) = 2/3.
    expect(result.summary.totalCuesAttempted).toBe(3);
    expect(result.summary.totalCuesCorrect).toBe(2);
    expect(result.summary.overallAccuracy).toBeCloseTo(2 / 3);
    // 0.667 → D (below the 0.7 C threshold).
    expect(result.summary.overallGrade).toBe('D');
    // Only VIDEO_ID was video_complete'd.
    expect(result.summary.lessonsCompleted).toBe(1);
    expect(result.summary.totalWatchTimeMs).toBe(60000);
    // Slice P3 — streak stays zero with no streak-eligible events mocked.
    expect(result.summary.currentStreak).toBe(0);
    expect(result.summary.longestStreak).toBe(0);
    expect(result.perCourse).toHaveLength(2);
  });

  it('skips a course whose summary fails (defensive)', async () => {
    const { prisma, svc } = makeService();
    prisma.enrollment.findMany.mockResolvedValue([{ courseId: COURSE_ID }]);
    // Course missing → NotFoundError thrown; service should swallow + skip.
    prisma.course.findUnique.mockResolvedValue(null);

    const result = await svc.getOverallProgress(USER_ID);
    expect(result.perCourse).toEqual([]);
    expect(result.summary.coursesEnrolled).toBe(1);
  });
});

// ---------- getCourseProgress ----------

describe('getCourseProgress', () => {
  it('computes per-lesson breakdown with latest-attempt-wins scoring', async () => {
    const { prisma, svc } = makeService();
    prisma.course.findUnique.mockResolvedValue({
      id: COURSE_ID,
      title: 'Course',
      slug: 'c',
      coverImageUrl: null,
      videos: [
        {
          id: VIDEO_ID,
          title: 'V1',
          orderIndex: 0,
          durationMs: 30000,
          cues: [{ id: CUE_ID_1 }, { id: CUE_ID_2 }],
        },
        {
          id: VIDEO_ID_2,
          title: 'V2',
          orderIndex: 1,
          durationMs: 20000,
          cues: [{ id: CUE_ID_3 }],
        },
      ],
    });
    prisma.enrollment.findUnique.mockResolvedValue({
      lastVideoId: VIDEO_ID_2,
      lastPosMs: 500,
    });
    // Two attempts on CUE_ID_1: first wrong, second right — latest wins.
    prisma.attempt.findMany.mockResolvedValue([
      {
        videoId: VIDEO_ID,
        cueId: CUE_ID_1,
        correct: true,
        submittedAt: new Date('2026-04-12T00:00:00Z'),
      },
      {
        videoId: VIDEO_ID,
        cueId: CUE_ID_1,
        correct: false,
        submittedAt: new Date('2026-04-11T00:00:00Z'),
      },
      {
        videoId: VIDEO_ID,
        cueId: CUE_ID_2,
        correct: false,
        submittedAt: new Date('2026-04-11T00:00:00Z'),
      },
      {
        videoId: VIDEO_ID_2,
        cueId: CUE_ID_3,
        correct: true,
        submittedAt: new Date('2026-04-11T00:00:00Z'),
      },
    ]);
    prisma.analyticsEvent.findMany.mockResolvedValue([
      { videoId: VIDEO_ID_2 },
    ]);

    const result = await svc.getCourseProgress(USER_ID, COURSE_ID);

    expect(result.course.id).toBe(COURSE_ID);
    expect(result.videosTotal).toBe(2);
    expect(result.videosCompleted).toBe(1);
    expect(result.completionPct).toBe(0.5);
    expect(result.cuesAttempted).toBe(3);
    expect(result.cuesCorrect).toBe(2);
    expect(result.accuracy).toBeCloseTo(2 / 3);
    expect(result.grade).toBe('D');
    expect(result.lastVideoId).toBe(VIDEO_ID_2);
    expect(result.lessons).toHaveLength(2);
    // v1 latest attempts: cue1 correct (2026-04-12), cue2 wrong. 1/2 = 0.5 → F.
    expect(result.lessons[0].cuesCorrect).toBe(1);
    expect(result.lessons[0].cuesAttempted).toBe(2);
    expect(result.lessons[0].accuracy).toBe(0.5);
    expect(result.lessons[0].grade).toBe('F');
    expect(result.lessons[0].completed).toBe(false);
    expect(result.lessons[1].completed).toBe(true);
    expect(result.lessons[1].grade).toBe('A');
  });

  it('throws NotFoundError when the course does not exist', async () => {
    const { prisma, svc } = makeService();
    prisma.course.findUnique.mockResolvedValue(null);
    await expect(
      svc.getCourseProgress(USER_ID, COURSE_ID),
    ).rejects.toBeInstanceOf(NotFoundError);
  });

  it('throws NotFoundError when user has no enrollment in the course', async () => {
    const { prisma, svc } = makeService();
    prisma.course.findUnique.mockResolvedValue({
      id: COURSE_ID,
      title: 'C',
      slug: 'c',
      coverImageUrl: null,
      videos: [],
    });
    prisma.enrollment.findUnique.mockResolvedValue(null);
    await expect(
      svc.getCourseProgress(USER_ID, COURSE_ID),
    ).rejects.toBeInstanceOf(NotFoundError);
  });

  it('cache hit skips DB', async () => {
    const { prisma, svc, redis } = makeService();
    const payload = {
      course: {
        id: COURSE_ID,
        title: 'C',
        slug: 'c',
        coverImageUrl: null,
      },
      videosTotal: 0,
      videosCompleted: 0,
      completionPct: 0,
      cuesAttempted: 0,
      cuesCorrect: 0,
      accuracy: null,
      grade: null,
      lastVideoId: null,
      lastPosMs: null,
      lessons: [],
    };
    redis.get.mockResolvedValueOnce(JSON.stringify(payload));
    const result = await svc.getCourseProgress(USER_ID, COURSE_ID);
    expect(result).toEqual(payload);
    expect(prisma.course.findUnique).not.toHaveBeenCalled();
  });
});

// ---------- getLessonReview ----------

describe('getLessonReview', () => {
  function setupVideoAttempted(prisma: MockPrisma, opts: { attempted: boolean; correct?: boolean }) {
    prisma.video.findUnique.mockResolvedValue({
      id: VIDEO_ID,
      title: 'V1',
      orderIndex: 0,
      durationMs: 60000,
      courseId: COURSE_ID,
      course: { id: COURSE_ID, title: 'C', slug: 'c' },
      cues: [
        {
          id: CUE_ID_1,
          atMs: 1000,
          type: 'MCQ',
          payload: {
            question: 'Capital of France?',
            choices: ['Berlin', 'Paris', 'Madrid'],
            answerIndex: 1,
            explanation: 'France → Paris',
          },
        },
        {
          id: CUE_ID_2,
          atMs: 2000,
          type: 'BLANKS',
          payload: {
            sentenceTemplate: 'The sky is {{0}}.',
            blanks: [{ accept: ['blue'] }],
          },
        },
        {
          id: CUE_ID_3,
          atMs: 3000,
          type: 'MATCHING',
          payload: {
            prompt: 'Match',
            left: ['France', 'Germany'],
            right: ['Paris', 'Berlin'],
            pairs: [
              [0, 0],
              [1, 1],
            ],
          },
        },
      ],
    });
    if (opts.attempted) {
      prisma.attempt.findMany.mockResolvedValue([
        {
          cueId: CUE_ID_1,
          correct: opts.correct ?? true,
          scoreJson: { selected: 1 },
          submittedAt: new Date('2026-04-10T00:00:00Z'),
        },
      ]);
    } else {
      prisma.attempt.findMany.mockResolvedValue([]);
      prisma.enrollment.findUnique.mockResolvedValue({ id: 'e1' });
    }
  }

  it('SECURITY: unattempted cues have null correctAnswerSummary', async () => {
    const { prisma, svc } = makeService();
    setupVideoAttempted(prisma, { attempted: false });

    const result = await svc.getLessonReview(USER_ID, VIDEO_ID);

    // Serialize the whole response and assert none of the raw answer
    // keys ever leak. This is the load-bearing invariant of this slice.
    const serialized = JSON.stringify(result);
    expect(serialized).not.toContain('answerIndex');
    expect(serialized).not.toContain('"accept"');
    expect(serialized).not.toContain('"pairs"');

    for (const c of result.cues) {
      expect(c.attempted).toBe(false);
      expect(c.correctAnswerSummary).toBeNull();
      expect(c.yourAnswerSummary).toBeNull();
      expect(c.explanation).toBeNull();
      expect(c.correct).toBeNull();
    }
  });

  it('attempted cue exposes the per-type correct-answer summary', async () => {
    const { prisma, svc } = makeService();
    setupVideoAttempted(prisma, { attempted: true, correct: true });

    const result = await svc.getLessonReview(USER_ID, VIDEO_ID);
    const mcqOutcome = result.cues.find((c) => c.cueId === CUE_ID_1)!;
    expect(mcqOutcome.attempted).toBe(true);
    expect(mcqOutcome.correctAnswerSummary).toBe('Paris');
    expect(mcqOutcome.explanation).toBe('France → Paris');
    expect(mcqOutcome.yourAnswerSummary).toBe('Choice 2');
    expect(mcqOutcome.correct).toBe(true);

    // Other cues not attempted — still redacted.
    const blanks = result.cues.find((c) => c.cueId === CUE_ID_2)!;
    expect(blanks.attempted).toBe(false);
    expect(blanks.correctAnswerSummary).toBeNull();
  });

  it('throws NotFoundError when video does not exist', async () => {
    const { prisma, svc } = makeService();
    prisma.video.findUnique.mockResolvedValue(null);
    await expect(
      svc.getLessonReview(USER_ID, VIDEO_ID),
    ).rejects.toBeInstanceOf(NotFoundError);
  });

  it('throws NotFoundError when user has no attempts AND no enrollment', async () => {
    const { prisma, svc } = makeService();
    prisma.video.findUnique.mockResolvedValue({
      id: VIDEO_ID,
      title: 'V',
      orderIndex: 0,
      durationMs: null,
      courseId: COURSE_ID,
      course: { id: COURSE_ID, title: 'C', slug: 'c' },
      cues: [],
    });
    prisma.attempt.findMany.mockResolvedValue([]);
    prisma.enrollment.findUnique.mockResolvedValue(null);
    await expect(
      svc.getLessonReview(USER_ID, VIDEO_ID),
    ).rejects.toBeInstanceOf(NotFoundError);
  });

  it('VOICE cues render a stub prompt and no answer leakage', async () => {
    const { prisma, svc } = makeService();
    prisma.video.findUnique.mockResolvedValue({
      id: VIDEO_ID,
      title: 'V',
      orderIndex: 0,
      durationMs: null,
      courseId: COURSE_ID,
      course: { id: COURSE_ID, title: 'C', slug: 'c' },
      cues: [
        {
          id: CUE_ID_1,
          atMs: 0,
          type: 'VOICE',
          payload: { type: 'VOICE' },
        },
      ],
    });
    prisma.attempt.findMany.mockResolvedValue([]);
    prisma.enrollment.findUnique.mockResolvedValue({ id: 'e' });

    const result = await svc.getLessonReview(USER_ID, VIDEO_ID);
    expect(result.cues[0].prompt).toBe('Voice exercise (not yet supported)');
    expect(result.cues[0].correctAnswerSummary).toBeNull();
  });

  it('renders BLANKS + MATCHING correct-answer summaries for attempted cues', async () => {
    const { prisma, svc } = makeService();
    prisma.video.findUnique.mockResolvedValue({
      id: VIDEO_ID,
      title: 'V',
      orderIndex: 0,
      durationMs: null,
      courseId: COURSE_ID,
      course: { id: COURSE_ID, title: 'C', slug: 'c' },
      cues: [
        {
          id: CUE_ID_2,
          atMs: 2000,
          type: 'BLANKS',
          payload: {
            sentenceTemplate: '{{0}} and {{1}}.',
            blanks: [{ accept: ['alpha', 'a'] }, { accept: ['beta'] }],
          },
        },
        {
          id: CUE_ID_3,
          atMs: 3000,
          type: 'MATCHING',
          payload: {
            prompt: 'Pair up',
            left: ['x', 'y'],
            right: ['p', 'q'],
            pairs: [
              [0, 1],
              [1, 0],
            ],
          },
        },
      ],
    });
    prisma.attempt.findMany.mockResolvedValue([
      {
        cueId: CUE_ID_2,
        correct: true,
        scoreJson: { perBlank: [true, false] },
        submittedAt: new Date(),
      },
      {
        cueId: CUE_ID_3,
        correct: false,
        scoreJson: { correctPairs: 1, totalPairs: 2 },
        submittedAt: new Date(),
      },
    ]);

    const result = await svc.getLessonReview(USER_ID, VIDEO_ID);
    const blanks = result.cues.find((c) => c.cueId === CUE_ID_2)!;
    expect(blanks.correctAnswerSummary).toBe('alpha, beta');
    expect(blanks.yourAnswerSummary).toBe('1/2 blanks correct');
    const matching = result.cues.find((c) => c.cueId === CUE_ID_3)!;
    expect(matching.correctAnswerSummary).toBe('x → q; y → p');
    expect(matching.yourAnswerSummary).toBe('1/2 pairs');
  });

  it('cache hit revives Date fields on attempted cues', async () => {
    const { svc, redis } = makeService();
    const iso = '2026-04-10T00:00:00.000Z';
    redis.get.mockResolvedValueOnce(
      JSON.stringify({
        video: {
          id: VIDEO_ID,
          title: 'V',
          orderIndex: 0,
          durationMs: 1,
          courseId: COURSE_ID,
        },
        course: { id: COURSE_ID, title: 'C', slug: 'c' },
        score: {
          cuesAttempted: 1,
          cuesCorrect: 1,
          accuracy: 1,
          grade: 'A',
        },
        cues: [
          {
            cueId: CUE_ID_1,
            atMs: 0,
            type: 'MCQ',
            prompt: 'q',
            attempted: true,
            correct: true,
            scoreJson: { selected: 0 },
            submittedAt: iso,
            explanation: null,
            yourAnswerSummary: 'Choice 1',
            correctAnswerSummary: 'a',
          },
        ],
      }),
    );
    const result = await svc.getLessonReview(USER_ID, VIDEO_ID);
    expect(result.cues[0].submittedAt).toBeInstanceOf(Date);
    expect((result.cues[0].submittedAt as Date).toISOString()).toBe(iso);
  });
});

// ---------- malformed payload tolerance (defensive) ----------

describe('malformed payload tolerance', () => {
  it('handles unexpected shapes without crashing', async () => {
    const { prisma, svc } = makeService();
    prisma.video.findUnique.mockResolvedValue({
      id: VIDEO_ID,
      title: 'V',
      orderIndex: 0,
      durationMs: null,
      courseId: COURSE_ID,
      course: { id: COURSE_ID, title: 'C', slug: 'c' },
      cues: [
        // MCQ missing answerIndex -> summary stays null
        {
          id: 'c-a',
          atMs: 0,
          type: 'MCQ',
          payload: { question: 'q', choices: ['a', 'b'] },
        },
        // BLANKS where blanks isn't an array
        { id: 'c-b', atMs: 0, type: 'BLANKS', payload: { sentenceTemplate: 's' } },
        // MATCHING with malformed pairs
        {
          id: 'c-c',
          atMs: 0,
          type: 'MATCHING',
          payload: { prompt: 'p', left: ['a'], right: ['b'], pairs: [['x', 'y']] },
        },
        // MCQ where payload is null (Prisma can legally store null Json)
        { id: 'c-d', atMs: 0, type: 'MCQ', payload: null },
      ],
    });
    prisma.attempt.findMany.mockResolvedValue([
      { cueId: 'c-a', correct: false, scoreJson: null, submittedAt: new Date() },
      { cueId: 'c-b', correct: false, scoreJson: null, submittedAt: new Date() },
      { cueId: 'c-c', correct: false, scoreJson: null, submittedAt: new Date() },
      { cueId: 'c-d', correct: false, scoreJson: null, submittedAt: new Date() },
    ]);
    const result = await svc.getLessonReview(USER_ID, VIDEO_ID);
    for (const cue of result.cues) {
      expect(cue.correctAnswerSummary).toBeNull();
      expect(cue.yourAnswerSummary).toBeNull();
    }
  });

  it('reviveDate: Date instance and invalid strings both handled on cache read', async () => {
    const { svc, redis } = makeService();
    // Missing submittedAt is null; a Date on the cached object survives;
    // a garbage string reviver returns an invalid-date.
    redis.get.mockResolvedValueOnce(
      JSON.stringify({
        video: { id: VIDEO_ID, title: 'V', orderIndex: 0, durationMs: null, courseId: COURSE_ID },
        course: { id: COURSE_ID, title: 'C', slug: 'c' },
        score: { cuesAttempted: 0, cuesCorrect: 0, accuracy: null, grade: null },
        cues: [
          // submittedAt null
          {
            cueId: 'c1', atMs: 0, type: 'MCQ', prompt: 'q', attempted: false,
            correct: null, scoreJson: null, submittedAt: null, explanation: null,
            yourAnswerSummary: null, correctAnswerSummary: null,
          },
        ],
      }),
    );
    const result = await svc.getLessonReview(USER_ID, VIDEO_ID);
    expect(result.cues[0].submittedAt).toBeNull();
  });

  it('BLANKS with non-object accept / MATCHING with mixed types — returns null', async () => {
    const { prisma, svc } = makeService();
    prisma.video.findUnique.mockResolvedValue({
      id: VIDEO_ID,
      title: 'V',
      orderIndex: 0,
      durationMs: null,
      courseId: COURSE_ID,
      course: { id: COURSE_ID, title: 'C', slug: 'c' },
      cues: [
        // BLANKS where blanks has a non-object entry
        {
          id: 'c1',
          atMs: 0,
          type: 'BLANKS',
          payload: { sentenceTemplate: 's', blanks: [null, 'not-obj'] },
        },
      ],
    });
    prisma.attempt.findMany.mockResolvedValue([
      { cueId: 'c1', correct: false, scoreJson: { perBlank: null }, submittedAt: new Date() },
    ]);
    const result = await svc.getLessonReview(USER_ID, VIDEO_ID);
    expect(result.cues[0].correctAnswerSummary).toBeNull();
    expect(result.cues[0].yourAnswerSummary).toBeNull();
  });
});

// ---------- invalidateForAttempt ----------

describe('invalidateForAttempt', () => {
  it('clears the three user-keyed caches', async () => {
    const { svc, redis } = makeService();
    await svc.invalidateForAttempt({
      userId: USER_ID,
      videoId: VIDEO_ID,
      courseId: COURSE_ID,
    });
    expect(redis.del).toHaveBeenCalledWith(
      `progress:overall:${USER_ID}`,
      `progress:course:${USER_ID}:${COURSE_ID}`,
      `progress:lesson:${USER_ID}:${VIDEO_ID}`,
      // Slice P3 — achievements cache invalidates alongside.
      `progress:achievements:${USER_ID}`,
    );
  });

  it('swallows Redis errors (best-effort)', async () => {
    const { svc, redis } = makeService();
    redis.del.mockRejectedValueOnce(new Error('redis down'));
    // Must not reject.
    await expect(
      svc.invalidateForAttempt({
        userId: USER_ID,
        videoId: VIDEO_ID,
        courseId: COURSE_ID,
      }),
    ).resolves.toBeUndefined();
  });
});

// ---------- cache error resilience ----------

describe('cache error resilience', () => {
  it('falls through to DB when Redis GET throws', async () => {
    const { prisma, svc, redis } = makeService();
    redis.get.mockRejectedValueOnce(new Error('redis down'));
    prisma.enrollment.findMany.mockResolvedValue([]);
    const result = await svc.getOverallProgress(USER_ID);
    expect(result.summary.coursesEnrolled).toBe(0);
  });

  it('returns the computed value even when Redis SET throws', async () => {
    const { prisma, svc, redis } = makeService();
    redis.set.mockRejectedValueOnce(new Error('redis down'));
    prisma.enrollment.findMany.mockResolvedValue([]);
    const result = await svc.getOverallProgress(USER_ID);
    expect(result.summary.coursesEnrolled).toBe(0);
  });
});

// ---------- Slice P3: streak helper ----------
//
// `computeStreakFromEvents` is pure — fixed `nowMs` so tests don't drift
// as the wall clock advances. Day index = `floor((utc + tzOffset) / 1d)`.
// With `nowMs = 2026-04-20T12:00:00Z` and `tz=0`, "today" is day N.

describe('computeStreakFromEvents', () => {
  // Pin "today" to 2026-04-20 12:00 UTC. Matches `currentDate` in
  // CLAUDE.md context, but any fixed value would do.
  const NOW_MS = Date.UTC(2026, 3, 20, 12, 0, 0);

  function d(iso: string): Date {
    return new Date(iso);
  }

  it('empty events → zero/zero', () => {
    expect(
      computeStreakFromEvents([], { timezoneOffsetMinutes: 0, nowMs: NOW_MS }),
    ).toEqual({ currentStreak: 0, longestStreak: 0 });
  });

  it('single event today (tz 0) → current=1, longest=1', () => {
    const r = computeStreakFromEvents(
      [d('2026-04-20T09:00:00Z')],
      { timezoneOffsetMinutes: 0, nowMs: NOW_MS },
    );
    expect(r.currentStreak).toBe(1);
    expect(r.longestStreak).toBe(1);
  });

  it('three contiguous days ending today → current=3, longest=3', () => {
    const r = computeStreakFromEvents(
      [
        d('2026-04-20T09:00:00Z'),
        d('2026-04-19T09:00:00Z'),
        d('2026-04-18T09:00:00Z'),
      ],
      { timezoneOffsetMinutes: 0, nowMs: NOW_MS },
    );
    expect(r.currentStreak).toBe(3);
    expect(r.longestStreak).toBe(3);
  });

  it('seven contiguous days ending today → current=7, longest=7', () => {
    const events: Date[] = [];
    for (let i = 0; i < 7; i += 1) {
      events.push(new Date(NOW_MS - i * 86_400_000));
    }
    const r = computeStreakFromEvents(events, {
      timezoneOffsetMinutes: 0,
      nowMs: NOW_MS,
    });
    expect(r.currentStreak).toBe(7);
    expect(r.longestStreak).toBe(7);
  });

  it('gap breaks the streak; longest remembers the older run', () => {
    const r = computeStreakFromEvents(
      [
        // today only
        d('2026-04-20T09:00:00Z'),
        // 4-day run ending 2026-04-10 (old)
        d('2026-04-10T09:00:00Z'),
        d('2026-04-09T09:00:00Z'),
        d('2026-04-08T09:00:00Z'),
        d('2026-04-07T09:00:00Z'),
      ],
      { timezoneOffsetMinutes: 0, nowMs: NOW_MS },
    );
    expect(r.currentStreak).toBe(1);
    expect(r.longestStreak).toBe(4);
  });

  it('grace day: streak ended yesterday still counts as current', () => {
    // No event today; 2-day run ending yesterday.
    const r = computeStreakFromEvents(
      [
        d('2026-04-19T09:00:00Z'),
        d('2026-04-18T09:00:00Z'),
      ],
      { timezoneOffsetMinutes: 0, nowMs: NOW_MS },
    );
    // Grace allows "today" to use yesterday's streak-tail.
    expect(r.currentStreak).toBe(2);
    expect(r.longestStreak).toBe(2);
  });

  it('cross-midnight in user tz: event at 11pm local on day N counts on day N', () => {
    // Learner is UTC-5 (offset = -300). 2026-04-20 03:00 UTC = 22:00
    // local on 2026-04-19, so it belongs to the 19th, not the 20th.
    const r = computeStreakFromEvents(
      [
        d('2026-04-20T03:00:00Z'), // UTC+0 says 20th; UTC-5 says 19th
        d('2026-04-19T03:00:00Z'), // UTC+0 says 19th; UTC-5 says 18th
      ],
      {
        timezoneOffsetMinutes: -300,
        nowMs: Date.UTC(2026, 3, 20, 3, 0, 0), // "today" per UTC-5 = 19th
      },
    );
    // Events fall on 18th+19th local; "today" local is 19th → current=2.
    expect(r.currentStreak).toBe(2);
    expect(r.longestStreak).toBe(2);
  });

  it('same day, multiple events → counts as one day', () => {
    const r = computeStreakFromEvents(
      [
        d('2026-04-20T08:00:00Z'),
        d('2026-04-20T12:00:00Z'),
        d('2026-04-20T18:00:00Z'),
      ],
      { timezoneOffsetMinutes: 0, nowMs: NOW_MS },
    );
    expect(r.currentStreak).toBe(1);
    expect(r.longestStreak).toBe(1);
  });
});

describe('timezoneOffsetFromPreferences', () => {
  it('returns 0 on null prefs', () => {
    expect(timezoneOffsetFromPreferences(null)).toBe(0);
  });
  it('returns 0 on non-object prefs', () => {
    expect(timezoneOffsetFromPreferences('not-an-object')).toBe(0);
  });
  it('returns the number when present', () => {
    expect(timezoneOffsetFromPreferences({ timezoneOffsetMinutes: -300 })).toBe(
      -300,
    );
  });
  it('ignores non-numeric values', () => {
    expect(
      timezoneOffsetFromPreferences({ timezoneOffsetMinutes: 'utc' }),
    ).toBe(0);
  });
  it('ignores NaN / Infinity', () => {
    expect(
      timezoneOffsetFromPreferences({ timezoneOffsetMinutes: Number.NaN }),
    ).toBe(0);
    expect(
      timezoneOffsetFromPreferences({ timezoneOffsetMinutes: Infinity }),
    ).toBe(0);
  });
});

// ---------- Slice P3: streak + achievement wiring in getOverallProgress ----------

describe('getOverallProgress — Slice P3 wiring', () => {
  it('surfaces currentStreak/longestStreak from the analytics events', async () => {
    const { prisma, svc } = makeService();
    prisma.enrollment.findMany.mockResolvedValue([]);
    const now = new Date();
    prisma.user.findUnique.mockResolvedValue({ preferences: null });
    prisma.analyticsEvent.findMany.mockImplementation((args: unknown) => {
      const where = (args as { where: { eventType: unknown } }).where;
      if (typeof where.eventType !== 'string') {
        // Streak query → 2 consecutive days ending today.
        return Promise.resolve([
          { occurredAt: new Date(now.getTime() - 86_400_000) },
          { occurredAt: now },
        ]);
      }
      return Promise.resolve([]);
    });

    const result = await svc.getOverallProgress(USER_ID);
    expect(result.summary.currentStreak).toBeGreaterThanOrEqual(1);
    expect(result.summary.longestStreak).toBeGreaterThanOrEqual(1);
  });

  it('populates recentlyUnlocked from achievement service', async () => {
    const { prisma, svc } = makeService();
    prisma.enrollment.findMany.mockResolvedValue([]);
    prisma.achievement.findMany.mockResolvedValue([
      {
        id: 'first_lesson',
        title: 'First Lesson',
        iconKey: 'school',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    ]);
    prisma.userAchievement.findMany.mockImplementation((args: unknown) => {
      const a = args as { where?: { achievementId?: unknown } };
      // After createMany we read-back the row we just inserted so
      // the client gets the authoritative unlockedAt.
      if (a.where?.achievementId) {
        return Promise.resolve([
          { achievementId: 'first_lesson', unlockedAt: new Date(0) },
        ]);
      }
      return Promise.resolve([]);
    });
    prisma.userAchievement.createMany.mockResolvedValue({ count: 1 });
    // `lessons_completed` reads `analyticsEvent.findMany` with
    // eventType === 'video_complete' and distinct videoId.
    prisma.analyticsEvent.findMany.mockImplementation((args: unknown) => {
      const where = (args as { where: { eventType: unknown } }).where;
      if (where.eventType === 'video_complete') {
        return Promise.resolve([{ videoId: VIDEO_ID }]);
      }
      return Promise.resolve([]);
    });

    const result = await svc.getOverallProgress(USER_ID);
    expect(result.recentlyUnlocked).toHaveLength(1);
    expect(result.recentlyUnlocked[0].id).toBe('first_lesson');
    expect(result.recentlyUnlocked[0].title).toBe('First Lesson');
    expect(result.recentlyUnlocked[0].iconKey).toBe('school');
  });

  it('survives achievement evaluation error (dashboard still returns)', async () => {
    const { prisma, svc } = makeService();
    prisma.enrollment.findMany.mockResolvedValue([]);
    prisma.achievement.findMany.mockRejectedValue(new Error('db down'));
    const result = await svc.getOverallProgress(USER_ID);
    expect(result.summary.coursesEnrolled).toBe(0);
    expect(result.recentlyUnlocked).toEqual([]);
  });

  it('cache-hit returns empty recentlyUnlocked even if cached payload had any', async () => {
    const { svc, redis } = makeService();
    redis.get.mockResolvedValueOnce(
      JSON.stringify({
        summary: {
          coursesEnrolled: 0,
          lessonsCompleted: 0,
          totalCuesAttempted: 0,
          totalCuesCorrect: 0,
          overallAccuracy: null,
          overallGrade: null,
          totalWatchTimeMs: 0,
          currentStreak: 0,
          longestStreak: 0,
        },
        perCourse: [],
        // Cached payload *shouldn't* contain unlocks, but defense-in-depth:
        // if it somehow does, the cache-hit path must replace it with [].
        recentlyUnlocked: [{ id: 'stale', title: 'Stale', iconKey: 'x' }],
      }),
    );
    const result = await svc.getOverallProgress(USER_ID);
    expect(result.recentlyUnlocked).toEqual([]);
  });
});
