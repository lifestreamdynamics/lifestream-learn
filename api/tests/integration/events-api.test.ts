import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { prisma } from '@/config/prisma';
import {
  createAnalyticsEvent,
  createCourse,
  createCueDirect,
  createUser,
  createVideoDirect,
  enroll,
} from '@tests/integration/helpers/factories';

jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
  getTranscodeQueue: jest.fn().mockReturnValue({
    client: Promise.resolve({ ping: () => Promise.resolve('PONG') }),
  }),
  TRANSCODE_QUEUE_NAME: 'transcode',
  closeTranscodeQueue: jest.fn().mockResolvedValue(undefined),
}));

describe('Events + admin analytics API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('POST /api/events', () => {
    it('ingests a batch of events (202)', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .post('/api/events')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send([
          {
            eventType: 'video_view',
            occurredAt: '2026-04-19T00:00:00.000Z',
            payload: { playerState: 'foreground' },
          },
          {
            eventType: 'custom_new_event',
            occurredAt: '2026-04-19T00:00:01.000Z',
          },
        ]);
      expect(res.status).toBe(202);
      expect(res.body.ingested).toBe(2);

      const count = await prisma.analyticsEvent.count({
        where: { userId: learner.id },
      });
      expect(count).toBe(2);
    });

    it('rejects an oversized payload (400)', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const big = 'x'.repeat(5000);
      const res = await request(app)
        .post('/api/events')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send([
          {
            eventType: 'huge',
            occurredAt: '2026-04-19T00:00:00.000Z',
            payload: { big },
          },
        ]);
      expect(res.status).toBe(400);
    });

    it('rejects batch > 100 events', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const batch = Array.from({ length: 101 }, (_, i) => ({
        eventType: 'x',
        occurredAt: new Date(i).toISOString(),
      }));
      const res = await request(app)
        .post('/api/events')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send(batch);
      expect(res.status).toBe(400);
    });

    it('rejects non-array body', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .post('/api/events')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ eventType: 'x', occurredAt: '2026-01-01T00:00:00.000Z' });
      expect(res.status).toBe(400);
    });

    it('401 unauthenticated', async () => {
      const app = await getTestApp();
      const res = await request(app).post('/api/events').send([]);
      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/admin/analytics/courses/:id', () => {
    it('smoke test: non-zero aggregates with seeded data', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, {
        slug: 'an',
        published: true,
      });
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'x',
      });
      const cue = await createCueDirect(video.id, {
        type: 'MCQ',
        payload: { question: 'q', choices: ['a', 'b'], answerIndex: 0 },
        atMs: 100,
      });
      await enroll(learner.id, course.id);

      // Correct and incorrect attempts on the same cue type
      await prisma.attempt.createMany({
        data: [
          { userId: learner.id, videoId: video.id, cueId: cue.id, correct: true },
          { userId: learner.id, videoId: video.id, cueId: cue.id, correct: false },
        ],
      });

      // One view + one completion for the learner
      await createAnalyticsEvent(learner.id, {
        eventType: 'video_view',
        videoId: video.id,
      });
      await createAnalyticsEvent(learner.id, {
        eventType: 'video_complete',
        videoId: video.id,
      });

      const res = await request(app)
        .get(`/api/admin/analytics/courses/${course.id}`)
        .set('authorization', `Bearer ${admin.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.totalViews).toBeGreaterThan(0);
      expect(res.body.completionRate).toBeGreaterThan(0);
      expect(res.body.perCueTypeAccuracy.MCQ).toBeCloseTo(0.5);
      expect(res.body.perCueTypeAccuracy.BLANKS).toBeNull();
    });

    it('403 for non-admin', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get('/api/admin/analytics/courses/00000000-0000-4000-8000-000000000000')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(403);
    });
  });
});
