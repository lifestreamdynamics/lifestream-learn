import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import {
  createCourse,
  createUser,
  createVideoDirect,
} from '@tests/integration/helpers/factories';

jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
  getTranscodeQueue: jest.fn().mockReturnValue({
    client: Promise.resolve({ ping: () => Promise.resolve('PONG') }),
  }),
  TRANSCODE_QUEUE_NAME: 'transcode',
  closeTranscodeQueue: jest.fn().mockResolvedValue(undefined),
}));

describe('Enrollments API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('POST /api/enrollments', () => {
    it('learner can enroll in published course (201), idempotent (200)', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, {
        slug: 'e1',
        published: true,
      });

      const r1 = await request(app)
        .post('/api/enrollments')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ courseId: course.id });
      expect(r1.status).toBe(201);

      const r2 = await request(app)
        .post('/api/enrollments')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ courseId: course.id });
      expect(r2.status).toBe(200);
    });

    it('409 on unpublished course', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, { slug: 'e2' });

      const res = await request(app)
        .post('/api/enrollments')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ courseId: course.id });
      expect(res.status).toBe(409);
    });

    it('404 on missing course', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .post('/api/enrollments')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ courseId: '00000000-0000-4000-8000-000000000000' });
      expect(res.status).toBe(404);
    });
  });

  describe('GET /api/enrollments', () => {
    it('returns shaped list ordered newest first', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const c1 = await createCourse(designer.id, {
        slug: 'x1',
        published: true,
      });
      const c2 = await createCourse(designer.id, {
        slug: 'x2',
        published: true,
      });
      await request(app)
        .post('/api/enrollments')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ courseId: c1.id });
      await new Promise((r) => setTimeout(r, 10));
      await request(app)
        .post('/api/enrollments')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ courseId: c2.id });

      const res = await request(app)
        .get('/api/enrollments')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(2);
      expect(res.body[0].courseId).toBe(c2.id);
      expect(res.body[0].course.slug).toBe('x2');
    });
  });

  describe('PATCH /api/enrollments/:courseId/progress', () => {
    it('happy path 204', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, {
        slug: 'p1',
        published: true,
      });
      const video = await createVideoDirect(course.id);
      await request(app)
        .post('/api/enrollments')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ courseId: course.id });

      const res = await request(app)
        .patch(`/api/enrollments/${course.id}/progress`)
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ lastVideoId: video.id, lastPosMs: 5000 });
      expect(res.status).toBe(204);
    });

    it('400 when video belongs to a different course', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const c1 = await createCourse(designer.id, {
        slug: 'p2',
        published: true,
      });
      const c2 = await createCourse(designer.id, {
        slug: 'p3',
        published: true,
      });
      const foreignVideo = await createVideoDirect(c2.id);
      await request(app)
        .post('/api/enrollments')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ courseId: c1.id });

      const res = await request(app)
        .patch(`/api/enrollments/${c1.id}/progress`)
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ lastVideoId: foreignVideo.id, lastPosMs: 10 });
      expect(res.status).toBe(400);
    });

    it('404 when no enrollment exists', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, {
        slug: 'p4',
        published: true,
      });
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .patch(`/api/enrollments/${course.id}/progress`)
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ lastVideoId: video.id, lastPosMs: 0 });
      expect(res.status).toBe(404);
    });
  });
});
