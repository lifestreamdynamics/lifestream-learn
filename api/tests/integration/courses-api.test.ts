import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import {
  addCollaborator,
  createCourse,
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

describe('Courses API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('POST /api/courses', () => {
    it('designer creates a course with auto-slug', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const res = await request(app)
        .post('/api/courses')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ title: 'My First Course', description: 'Hello' });
      expect(res.status).toBe(201);
      expect(res.body.slug).toMatch(/^my-first-course-[0-9a-f]{6}$/);
      expect(res.body.ownerId).toBe(designer.id);
      expect(res.body.published).toBe(false);
    });

    it('rejects without description', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const res = await request(app)
        .post('/api/courses')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ title: 'T' });
      expect(res.status).toBe(400);
    });

    it('403 for learner', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .post('/api/courses')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ title: 'T', description: 'd' });
      expect(res.status).toBe(403);
    });

    it('401 unauthenticated', async () => {
      const app = await getTestApp();
      const res = await request(app)
        .post('/api/courses')
        .send({ title: 'T', description: 'd' });
      expect(res.status).toBe(401);
    });

    it('409 on explicit slug collision', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      await createCourse(designer.id, { slug: 'unique-slug' });
      const res = await request(app)
        .post('/api/courses')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ title: 'Dup', description: 'd', slug: 'unique-slug' });
      expect(res.status).toBe(409);
    });
  });

  describe('GET /api/courses', () => {
    it('anonymous sees only published', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      await createCourse(designer.id, { slug: 'draft-1', published: false });
      await createCourse(designer.id, { slug: 'live-1', published: true });
      const res = await request(app).get('/api/courses');
      expect(res.status).toBe(200);
      expect(res.body.items).toHaveLength(1);
      expect(res.body.items[0].slug).toBe('live-1');
    });

    it('anonymous owned=true is 403', async () => {
      const app = await getTestApp();
      const res = await request(app).get('/api/courses?owned=true');
      expect(res.status).toBe(403);
    });

    it('pagination cursor round-trip', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      // Three published courses, ordered by createdAt desc.
      for (let i = 0; i < 3; i += 1) {
        await createCourse(designer.id, {
          slug: `c${i}`,
          title: `C${i}`,
          published: true,
        });
        // Mild delay to guarantee distinct createdAt values.
        await new Promise((r) => setTimeout(r, 10));
      }
      const page1 = await request(app).get('/api/courses?limit=2');
      expect(page1.status).toBe(200);
      expect(page1.body.items).toHaveLength(2);
      expect(page1.body.hasMore).toBe(true);

      const page2 = await request(app).get(
        `/api/courses?limit=2&cursor=${encodeURIComponent(page1.body.nextCursor)}`,
      );
      expect(page2.status).toBe(200);
      expect(page2.body.items).toHaveLength(1);
      expect(page2.body.hasMore).toBe(false);
    });

    it('owned=true filters to caller', async () => {
      const app = await getTestApp();
      const a = await createUser({ role: 'COURSE_DESIGNER' });
      const b = await createUser({ role: 'COURSE_DESIGNER' });
      await createCourse(a.id, { slug: 'a1' });
      await createCourse(b.id, { slug: 'b1' });
      const res = await request(app)
        .get('/api/courses?owned=true')
        .set('authorization', `Bearer ${a.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.items).toHaveLength(1);
      expect(res.body.items[0].slug).toBe('a1');
    });

    it('enrolled=true filters to caller enrollment', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const c1 = await createCourse(designer.id, { slug: 'enr-1', published: true });
      await createCourse(designer.id, { slug: 'no-enr', published: true });
      await enroll(learner.id, c1.id);
      const res = await request(app)
        .get('/api/courses?enrolled=true')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.items).toHaveLength(1);
      expect(res.body.items[0].slug).toBe('enr-1');
    });
  });

  describe('GET /api/courses/:id', () => {
    it('owner sees unpublished', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id, { slug: 's1' });
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 12000,
      });
      const res = await request(app)
        .get(`/api/courses/${course.id}`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.videos).toHaveLength(1);
      expect(res.body.videos[0].id).toBe(video.id);
    });

    it('stranger gets 404 for unpublished', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const other = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id, { slug: 's2' });
      const res = await request(app)
        .get(`/api/courses/${course.id}`)
        .set('authorization', `Bearer ${other.accessToken}`);
      expect(res.status).toBe(404);
    });

    it('anonymous sees published', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id, {
        slug: 'pub-1',
        published: true,
      });
      const res = await request(app).get(`/api/courses/${course.id}`);
      expect(res.status).toBe(200);
    });
  });

  describe('PATCH /api/courses/:id', () => {
    it('owner can update title', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id, { slug: 'upd' });
      const res = await request(app)
        .patch(`/api/courses/${course.id}`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ title: 'Updated' });
      expect(res.status).toBe(200);
      expect(res.body.title).toBe('Updated');
    });

    it('stranger forbidden', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const other = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(owner.id, { slug: 'upd-2' });
      const res = await request(app)
        .patch(`/api/courses/${course.id}`)
        .set('authorization', `Bearer ${other.accessToken}`)
        .send({ title: 'x' });
      expect(res.status).toBe(403);
    });
  });

  describe('POST /api/courses/:id/publish', () => {
    it('409 without a READY video', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id, { slug: 'publess' });
      const res = await request(app)
        .post(`/api/courses/${course.id}/publish`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(res.status).toBe(409);
    });

    it('200 with a READY video; idempotent', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id, { slug: 'pubok' });
      await createVideoDirect(course.id, { status: 'READY', hlsPrefix: 'x' });
      const res1 = await request(app)
        .post(`/api/courses/${course.id}/publish`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(res1.status).toBe(200);
      expect(res1.body.published).toBe(true);
      const res2 = await request(app)
        .post(`/api/courses/${course.id}/publish`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(res2.status).toBe(200);
      expect(res2.body.published).toBe(true);
    });
  });

  describe('Collaborators', () => {
    it('add → 201, re-add → 200, delete → 204, delete idempotent', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const collab = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(owner.id, { slug: 'collab' });

      const r1 = await request(app)
        .post(`/api/courses/${course.id}/collaborators`)
        .set('authorization', `Bearer ${owner.accessToken}`)
        .send({ userId: collab.id });
      expect(r1.status).toBe(201);

      const r2 = await request(app)
        .post(`/api/courses/${course.id}/collaborators`)
        .set('authorization', `Bearer ${owner.accessToken}`)
        .send({ userId: collab.id });
      expect(r2.status).toBe(200);

      const r3 = await request(app)
        .delete(`/api/courses/${course.id}/collaborators/${collab.id}`)
        .set('authorization', `Bearer ${owner.accessToken}`);
      expect(r3.status).toBe(204);

      const r4 = await request(app)
        .delete(`/api/courses/${course.id}/collaborators/${collab.id}`)
        .set('authorization', `Bearer ${owner.accessToken}`);
      expect(r4.status).toBe(204);
    });

    it('rejects adding a LEARNER (400)', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(owner.id, { slug: 'no-l' });
      const res = await request(app)
        .post(`/api/courses/${course.id}/collaborators`)
        .set('authorization', `Bearer ${owner.accessToken}`)
        .send({ userId: learner.id });
      expect(res.status).toBe(400);
    });

    it('collaborator added via factory can be removed via API', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const collab = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(owner.id, { slug: 'facfac' });
      await addCollaborator(course.id, collab.id);
      const res = await request(app)
        .delete(`/api/courses/${course.id}/collaborators/${collab.id}`)
        .set('authorization', `Bearer ${owner.accessToken}`);
      expect(res.status).toBe(204);
    });
  });
});
