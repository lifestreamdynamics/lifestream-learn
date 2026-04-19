import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import {
  createUser,
  createCourse,
  addCollaborator,
  enroll,
  createVideoDirect,
  createCueDirect,
} from '@tests/integration/helpers/factories';

jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
  getTranscodeQueue: jest.fn().mockReturnValue({
    client: Promise.resolve({ ping: () => Promise.resolve('PONG') }),
  }),
  TRANSCODE_QUEUE_NAME: 'transcode',
  closeTranscodeQueue: jest.fn().mockResolvedValue(undefined),
}));

const VALID_MCQ = {
  question: 'What is 2+2?',
  choices: ['3', '4', '5', '6'],
  answerIndex: 1,
  explanation: 'Math.',
};

const VALID_BLANKS = {
  sentenceTemplate: 'Capital of France: {{0}}',
  blanks: [{ accept: ['Paris'] }],
};

const VALID_MATCHING = {
  prompt: 'Match capitals',
  left: ['France', 'Germany'],
  right: ['Berlin', 'Paris'],
  pairs: [
    [0, 1],
    [1, 0],
  ],
};

describe('Cues API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('POST /api/videos/:id/cues', () => {
    it('owner can create MCQ, BLANKS, MATCHING cues', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const mcqRes = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ atMs: 1000, type: 'MCQ', payload: VALID_MCQ });
      expect(mcqRes.status).toBe(201);
      expect(mcqRes.body.type).toBe('MCQ');
      expect(mcqRes.body.orderIndex).toBe(0);

      const blanksRes = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ atMs: 2000, type: 'BLANKS', payload: VALID_BLANKS });
      expect(blanksRes.status).toBe(201);
      expect(blanksRes.body.orderIndex).toBe(1);

      const matchRes = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ atMs: 3000, type: 'MATCHING', payload: VALID_MATCHING });
      expect(matchRes.status).toBe(201);
      expect(matchRes.body.orderIndex).toBe(2);
    });

    it('403 for a non-owner designer', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const other = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(owner.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${other.accessToken}`)
        .send({ atMs: 0, type: 'MCQ', payload: VALID_MCQ });
      expect(res.status).toBe(403);
    });

    it('403 when a learner tries to create', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);
      await enroll(learner.id, course.id);

      const res = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ atMs: 0, type: 'MCQ', payload: VALID_MCQ });
      expect(res.status).toBe(403);
    });

    it('501 for VOICE cue creation', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ atMs: 0, type: 'VOICE', payload: {} });
      expect(res.status).toBe(501);
      expect(res.body.error).toBe('NOT_IMPLEMENTED');
    });

    it('400 on invalid MCQ payload (answerIndex out of range)', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({
          atMs: 0,
          type: 'MCQ',
          payload: { question: 'q', choices: ['a', 'b'], answerIndex: 5 },
        });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('VALIDATION_ERROR');
    });

    it('401 without bearer token', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .send({ atMs: 0, type: 'MCQ', payload: VALID_MCQ });
      expect(res.status).toBe(401);
    });

    it('admin can create on any course', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${admin.accessToken}`)
        .send({ atMs: 0, type: 'MCQ', payload: VALID_MCQ });
      expect(res.status).toBe(201);
    });

    it('collaborator can create', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const collab = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(owner.id);
      await addCollaborator(course.id, collab.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .post(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${collab.accessToken}`)
        .send({ atMs: 0, type: 'MCQ', payload: VALID_MCQ });
      expect(res.status).toBe(201);
    });
  });

  describe('GET /api/videos/:id/cues', () => {
    it('owner can list cues ordered by atMs', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);
      await createCueDirect(video.id, {
        type: 'MCQ',
        atMs: 5000,
        orderIndex: 1,
        payload: VALID_MCQ,
      });
      await createCueDirect(video.id, {
        type: 'BLANKS',
        atMs: 1000,
        orderIndex: 0,
        payload: VALID_BLANKS,
      });

      const res = await request(app)
        .get(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(2);
      expect(res.body[0].atMs).toBe(1000);
      expect(res.body[1].atMs).toBe(5000);
    });

    it('enrolled learner can list', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);
      await enroll(learner.id, course.id);

      const res = await request(app)
        .get(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('403 for an unenrolled stranger', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const stranger = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .get(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${stranger.accessToken}`);
      expect(res.status).toBe(403);
    });

    it('404 for missing video', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const res = await request(app)
        .get('/api/videos/00000000-0000-0000-0000-000000000000/cues')
        .set('authorization', `Bearer ${admin.accessToken}`);
      expect(res.status).toBe(404);
    });
  });

  describe('PATCH /api/cues/:id', () => {
    it('owner can patch atMs + pause', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);
      const cue = await createCueDirect(video.id, {
        type: 'MCQ',
        payload: VALID_MCQ,
      });

      const res = await request(app)
        .patch(`/api/cues/${cue.id}`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ atMs: 9999, pause: false });
      expect(res.status).toBe(200);
      expect(res.body.atMs).toBe(9999);
      expect(res.body.pause).toBe(false);
    });

    it('rejects type change', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);
      const cue = await createCueDirect(video.id, { type: 'MCQ', payload: VALID_MCQ });

      const res = await request(app)
        .patch(`/api/cues/${cue.id}`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ type: 'BLANKS' });
      expect(res.status).toBe(400);
    });

    it('403 for non-owner designer', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const other = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(owner.id);
      const video = await createVideoDirect(course.id);
      const cue = await createCueDirect(video.id, { type: 'MCQ', payload: VALID_MCQ });

      const res = await request(app)
        .patch(`/api/cues/${cue.id}`)
        .set('authorization', `Bearer ${other.accessToken}`)
        .send({ atMs: 10 });
      expect(res.status).toBe(403);
    });

    it('400 on invalid new payload', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);
      const cue = await createCueDirect(video.id, { type: 'MCQ', payload: VALID_MCQ });

      const res = await request(app)
        .patch(`/api/cues/${cue.id}`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ payload: { question: 'q', choices: ['a', 'b'], answerIndex: 9 } });
      expect(res.status).toBe(400);
    });
  });

  describe('DELETE /api/cues/:id', () => {
    it('owner can delete', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);
      const cue = await createCueDirect(video.id, { type: 'MCQ', payload: VALID_MCQ });

      const res = await request(app)
        .delete(`/api/cues/${cue.id}`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(res.status).toBe(204);

      // verify gone
      const list = await request(app)
        .get(`/api/videos/${video.id}/cues`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(list.body).toHaveLength(0);
    });

    it('404 for missing cue', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const res = await request(app)
        .delete('/api/cues/00000000-0000-0000-0000-000000000000')
        .set('authorization', `Bearer ${admin.accessToken}`);
      expect(res.status).toBe(404);
    });
  });
});
