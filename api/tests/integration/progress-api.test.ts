import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import {
  createCourse,
  createCueDirect,
  createUser,
  createVideoDirect,
  enroll,
  createAnalyticsEvent,
} from '@tests/integration/helpers/factories';
import { prisma } from '@/config/prisma';

jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
  getTranscodeQueue: jest.fn().mockReturnValue({
    client: Promise.resolve({ ping: () => Promise.resolve('PONG') }),
  }),
  TRANSCODE_QUEUE_NAME: 'transcode',
  closeTranscodeQueue: jest.fn().mockResolvedValue(undefined),
}));

const MCQ_PAYLOAD = {
  question: 'Capital of France?',
  choices: ['Berlin', 'Paris', 'Madrid'],
  answerIndex: 1,
  explanation: 'France -> Paris',
};

const BLANKS_PAYLOAD = {
  sentenceTemplate: 'The sky is {{0}}.',
  blanks: [{ accept: ['blue'] }],
};

describe('Progress API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*', 'progress:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('GET /api/me/progress', () => {
    it('requires auth (401 without bearer)', async () => {
      const app = await getTestApp();
      const res = await request(app).get('/api/me/progress');
      expect(res.status).toBe(401);
    });

    it('fresh user with no enrollments -> zeros, not an error', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get('/api/me/progress')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.summary.coursesEnrolled).toBe(0);
      expect(res.body.summary.overallAccuracy).toBeNull();
      expect(res.body.summary.overallGrade).toBeNull();
      expect(res.body.perCourse).toEqual([]);
      // Slice P3 — streak + recently-unlocked fields present for fresh user.
      expect(res.body.summary.currentStreak).toBe(0);
      expect(res.body.summary.longestStreak).toBe(0);
      expect(res.body.recentlyUnlocked).toEqual([]);
    });

    it('happy path: 2 courses, some attempts, some correct — numbers match hand-calc', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const c1 = await createCourse(designer.id, { slug: 'p2-c1', published: true });
      const c2 = await createCourse(designer.id, { slug: 'p2-c2', published: true });
      await enroll(learner.id, c1.id);
      await enroll(learner.id, c2.id);
      const v1 = await createVideoDirect(c1.id, { durationMs: 60000 });
      const v2 = await createVideoDirect(c2.id, { durationMs: 120000 });
      const cueA = await createCueDirect(v1.id, {
        type: 'MCQ',
        payload: MCQ_PAYLOAD,
        atMs: 1000,
      });
      const cueB = await createCueDirect(v1.id, {
        type: 'BLANKS',
        payload: BLANKS_PAYLOAD,
        atMs: 2000,
        orderIndex: 1,
      });
      const cueC = await createCueDirect(v2.id, {
        type: 'MCQ',
        payload: MCQ_PAYLOAD,
        atMs: 1000,
      });

      // Correct MCQ on cueA, wrong BLANKS on cueB, correct MCQ on cueC.
      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: cueA.id, response: { choiceIndex: 1 } });
      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: cueB.id, response: { answers: ['green'] } });
      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: cueC.id, response: { choiceIndex: 1 } });

      // Simulate a `video_complete` event for v1.
      await createAnalyticsEvent(learner.id, {
        eventType: 'video_complete',
        videoId: v1.id,
      });

      const res = await request(app)
        .get('/api/me/progress')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.summary.coursesEnrolled).toBe(2);
      expect(res.body.summary.totalCuesAttempted).toBe(3);
      expect(res.body.summary.totalCuesCorrect).toBe(2);
      // 2/3 accuracy → D (≥0.6 but <0.7).
      expect(res.body.summary.overallGrade).toBe('D');
      expect(res.body.summary.lessonsCompleted).toBe(1);
      expect(res.body.summary.totalWatchTimeMs).toBe(60000);
      expect(res.body.perCourse).toHaveLength(2);
      // lessons array must not appear in the overall summary.
      for (const pc of res.body.perCourse) {
        expect(pc).not.toHaveProperty('lessons');
      }
    });

    it('recentlyUnlocked populated after first lesson completion', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, {
        slug: 'p3-unlock',
        published: true,
      });
      await enroll(learner.id, course.id);
      const video = await createVideoDirect(course.id, { durationMs: 60000 });

      // Seed the `first_lesson` achievement so evaluateAndUnlock has
      // something to match against. Integration tests get a clean DB
      // each run (resetDb also truncates UserAchievement), so we seed
      // the subset this test exercises rather than relying on the full
      // seed script being run.
      await prisma.achievement.upsert({
        where: { id: 'first_lesson' },
        update: {},
        create: {
          id: 'first_lesson',
          title: 'First Lesson',
          description: 'Complete your first lesson',
          iconKey: 'school',
          criteriaJson: { type: 'lessons_completed', count: 1 },
        },
      });

      // Simulate lesson completion via the analytics-event factory.
      await createAnalyticsEvent(learner.id, {
        eventType: 'video_complete',
        videoId: video.id,
      });

      const res = await request(app)
        .get('/api/me/progress')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.recentlyUnlocked).toHaveLength(1);
      expect(res.body.recentlyUnlocked[0].id).toBe('first_lesson');
      expect(res.body.recentlyUnlocked[0].title).toBe('First Lesson');
      expect(res.body.recentlyUnlocked[0].iconKey).toBe('school');

      // Second call should surface an empty list (one-shot toast
      // semantics — the cached response doesn't replay the unlock).
      const res2 = await request(app)
        .get('/api/me/progress')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res2.body.recentlyUnlocked).toEqual([]);
    });

    it('cache invalidates on new attempt: numbers change', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const c = await createCourse(designer.id, { slug: 'p2-cache', published: true });
      await enroll(learner.id, c.id);
      const v = await createVideoDirect(c.id, { durationMs: 1000 });
      const cue = await createCueDirect(v.id, {
        type: 'MCQ',
        payload: MCQ_PAYLOAD,
        atMs: 100,
      });

      // First call — no attempts yet.
      const r1 = await request(app)
        .get('/api/me/progress')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(r1.body.summary.totalCuesAttempted).toBe(0);

      // Submit an attempt — should invalidate the cached overall view.
      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: cue.id, response: { choiceIndex: 1 } });
      // Give the fire-and-forget invalidation a beat to land before we
      // re-query. 100ms is generous for an in-process Redis `DEL`.
      await new Promise((r) => setTimeout(r, 100));

      const r2 = await request(app)
        .get('/api/me/progress')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(r2.body.summary.totalCuesAttempted).toBe(1);
      expect(r2.body.summary.totalCuesCorrect).toBe(1);
    });
  });

  describe('GET /api/me/progress/courses/:courseId', () => {
    it('happy path -> per-lesson breakdown', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, {
        slug: 'p2-detail',
        published: true,
      });
      await enroll(learner.id, course.id);
      const v1 = await createVideoDirect(course.id, { durationMs: 30000 });
      const v2 = await createVideoDirect(course.id, { durationMs: 30000 });
      const cue1 = await createCueDirect(v1.id, {
        type: 'MCQ',
        payload: MCQ_PAYLOAD,
      });
      const cue2 = await createCueDirect(v2.id, {
        type: 'MCQ',
        payload: MCQ_PAYLOAD,
      });
      // Rebuild orderIndex deterministically on the second video so
      // lessons come back in the expected order.
      await prisma.video.update({
        where: { id: v2.id },
        data: { orderIndex: 1 },
      });

      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: cue1.id, response: { choiceIndex: 1 } });
      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: cue2.id, response: { choiceIndex: 0 } });

      const res = await request(app)
        .get(`/api/me/progress/courses/${course.id}`)
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.course.id).toBe(course.id);
      expect(res.body.videosTotal).toBe(2);
      expect(res.body.cuesAttempted).toBe(2);
      expect(res.body.cuesCorrect).toBe(1);
      expect(res.body.lessons).toHaveLength(2);
      // lesson[0] is v1 (correct), lesson[1] is v2 (wrong)
      const lessonV1 = res.body.lessons.find(
        (l: { videoId: string }) => l.videoId === v1.id,
      );
      const lessonV2 = res.body.lessons.find(
        (l: { videoId: string }) => l.videoId === v2.id,
      );
      expect(lessonV1.cuesCorrect).toBe(1);
      expect(lessonV2.cuesCorrect).toBe(0);
    });

    it('returns 404 when user has no enrollment in that course', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, {
        slug: 'p2-noenrol',
        published: true,
      });
      // Deliberately no enroll().
      const res = await request(app)
        .get(`/api/me/progress/courses/${course.id}`)
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(404);
    });

    it('returns 400 for a malformed UUID', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get('/api/me/progress/courses/not-a-uuid')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(400);
    });
  });

  describe('GET /api/me/progress/lessons/:videoId', () => {
    it('happy path: per-cue breakdown, SECURITY invariant', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, {
        slug: 'p2-lesson',
        published: true,
      });
      await enroll(learner.id, course.id);
      const video = await createVideoDirect(course.id, { durationMs: 60000 });
      const attemptedCue = await createCueDirect(video.id, {
        type: 'MCQ',
        payload: MCQ_PAYLOAD,
        atMs: 1000,
      });
      const unattemptedCue = await createCueDirect(video.id, {
        type: 'MCQ',
        payload: MCQ_PAYLOAD,
        atMs: 2000,
        orderIndex: 1,
      });
      void unattemptedCue;

      // Only attempt the first cue.
      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: attemptedCue.id, response: { choiceIndex: 1 } });

      const res = await request(app)
        .get(`/api/me/progress/lessons/${video.id}`)
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.cues).toHaveLength(2);

      const attemptedOutcome = res.body.cues.find(
        (c: { cueId: string }) => c.cueId === attemptedCue.id,
      );
      const unattemptedOutcome = res.body.cues.find(
        (c: { cueId: string }) => c.cueId === unattemptedCue.id,
      );

      expect(attemptedOutcome.attempted).toBe(true);
      expect(attemptedOutcome.correct).toBe(true);
      expect(attemptedOutcome.correctAnswerSummary).toBe('Paris');

      // SECURITY: unattempted cue MUST NOT leak the answer.
      expect(unattemptedOutcome.attempted).toBe(false);
      expect(unattemptedOutcome.correctAnswerSummary).toBeNull();
      expect(unattemptedOutcome.yourAnswerSummary).toBeNull();

      // Even at the serialised-body level, the raw answer field must not
      // appear for the unattempted cue.
      const bodyText = JSON.stringify(res.body);
      expect(bodyText).not.toContain('answerIndex');
    });

    it('returns 404 when not enrolled AND no attempts', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const stranger = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, {
        slug: 'p2-lesson-404',
        published: true,
      });
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .get(`/api/me/progress/lessons/${video.id}`)
        .set('authorization', `Bearer ${stranger.accessToken}`);
      expect(res.status).toBe(404);
    });

    it('returns 404 when the video does not exist', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get('/api/me/progress/lessons/00000000-0000-4000-8000-000000000000')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(404);
    });
  });
});
