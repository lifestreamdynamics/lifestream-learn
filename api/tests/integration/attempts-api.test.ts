import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import {
  createUser,
  createCourse,
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

const MCQ_PAYLOAD = {
  question: 'Capital of France?',
  choices: ['Berlin', 'Paris', 'Madrid', 'Rome'],
  answerIndex: 1,
  explanation: 'France -> Paris',
};

const BLANKS_PAYLOAD = {
  sentenceTemplate: 'The capital of France is {{0}}.',
  blanks: [{ accept: ['Paris'] }],
};

const MATCHING_PAYLOAD = {
  prompt: 'Match capitals',
  left: ['France', 'Germany'],
  right: ['Berlin', 'Paris'],
  // France->Paris, Germany->Berlin
  pairs: [
    [0, 1],
    [1, 0],
  ],
};

describe('Attempts API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  async function seedEnrolledScene() {
    const designer = await createUser({ role: 'COURSE_DESIGNER' });
    const learner = await createUser({ role: 'LEARNER' });
    const course = await createCourse(designer.id);
    await enroll(learner.id, course.id);
    const video = await createVideoDirect(course.id);
    const mcqCue = await createCueDirect(video.id, {
      type: 'MCQ',
      payload: MCQ_PAYLOAD,
      atMs: 1000,
      orderIndex: 0,
    });
    const blanksCue = await createCueDirect(video.id, {
      type: 'BLANKS',
      payload: BLANKS_PAYLOAD,
      atMs: 2000,
      orderIndex: 1,
    });
    const matchCue = await createCueDirect(video.id, {
      type: 'MATCHING',
      payload: MATCHING_PAYLOAD,
      atMs: 3000,
      orderIndex: 2,
    });
    return { designer, learner, course, video, mcqCue, blanksCue, matchCue };
  }

  describe('POST /api/attempts', () => {
    it('enrolled learner submits a correct MCQ -> 201, correct=true, explanation passthrough', async () => {
      const app = await getTestApp();
      const { learner, mcqCue } = await seedEnrolledScene();
      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: mcqCue.id, response: { choiceIndex: 1 } });

      expect(res.status).toBe(201);
      expect(res.body.correct).toBe(true);
      expect(res.body.scoreJson).toEqual({ selected: 1 });
      expect(res.body.explanation).toBe('France -> Paris');
      // Must not leak the answer index.
      expect(JSON.stringify(res.body)).not.toContain('answerIndex');
    });

    it('enrolled learner submits an incorrect MCQ -> 201, correct=false, explanation still present', async () => {
      const app = await getTestApp();
      const { learner, mcqCue } = await seedEnrolledScene();
      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: mcqCue.id, response: { choiceIndex: 0 } });

      expect(res.status).toBe(201);
      expect(res.body.correct).toBe(false);
      expect(res.body.scoreJson).toEqual({ selected: 0 });
      expect(res.body.explanation).toBe('France -> Paris');
    });

    it('BLANKS correct path', async () => {
      const app = await getTestApp();
      const { learner, blanksCue } = await seedEnrolledScene();
      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: blanksCue.id, response: { answers: ['paris'] } });
      expect(res.status).toBe(201);
      expect(res.body.correct).toBe(true);
      expect(res.body.scoreJson).toEqual({ perBlank: [true] });
    });

    it('BLANKS incorrect path', async () => {
      const app = await getTestApp();
      const { learner, blanksCue } = await seedEnrolledScene();
      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: blanksCue.id, response: { answers: ['London'] } });
      expect(res.status).toBe(201);
      expect(res.body.correct).toBe(false);
      expect(res.body.scoreJson).toEqual({ perBlank: [false] });
    });

    it('MATCHING correct path', async () => {
      const app = await getTestApp();
      const { learner, matchCue } = await seedEnrolledScene();
      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({
          cueId: matchCue.id,
          response: {
            userPairs: [
              [0, 1],
              [1, 0],
            ],
          },
        });
      expect(res.status).toBe(201);
      expect(res.body.correct).toBe(true);
      expect(res.body.scoreJson).toEqual({ correctPairs: 2, totalPairs: 2 });
      // pair solution must not leak
      expect(JSON.stringify(res.body)).not.toContain('"pairs"');
    });

    it('MATCHING incorrect path', async () => {
      const app = await getTestApp();
      const { learner, matchCue } = await seedEnrolledScene();
      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({
          cueId: matchCue.id,
          response: {
            userPairs: [
              [0, 0], // wrong
              [1, 1], // wrong
            ],
          },
        });
      expect(res.status).toBe(201);
      expect(res.body.correct).toBe(false);
      expect(res.body.scoreJson).toEqual({ correctPairs: 0, totalPairs: 2 });
    });

    it('403 for a stranger learner not enrolled', async () => {
      const app = await getTestApp();
      const { mcqCue } = await seedEnrolledScene();
      const stranger = await createUser({ role: 'LEARNER' });

      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${stranger.accessToken}`)
        .send({ cueId: mcqCue.id, response: { choiceIndex: 1 } });
      expect(res.status).toBe(403);
    });

    it('404 for missing cue', async () => {
      const app = await getTestApp();
      const { learner } = await seedEnrolledScene();
      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({
          cueId: '00000000-0000-0000-0000-000000000000',
          response: { choiceIndex: 0 },
        });
      expect(res.status).toBe(404);
    });

    it('400 when response shape mismatches cue type', async () => {
      const app = await getTestApp();
      const { learner, mcqCue } = await seedEnrolledScene();
      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: mcqCue.id, response: { answers: ['Paris'] } });
      expect(res.status).toBe(400);
    });

    it('designer can submit attempts on their own content without enrolling', async () => {
      const app = await getTestApp();
      const { designer, mcqCue } = await seedEnrolledScene();
      const res = await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ cueId: mcqCue.id, response: { choiceIndex: 1 } });
      expect(res.status).toBe(201);
      expect(res.body.correct).toBe(true);
    });

    it('401 without bearer token', async () => {
      const app = await getTestApp();
      const res = await request(app)
        .post('/api/attempts')
        .send({ cueId: '00000000-0000-0000-0000-000000000000', response: {} });
      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/attempts', () => {
    it("returns only the caller's own attempts", async () => {
      const app = await getTestApp();
      const { course, learner, mcqCue } = await seedEnrolledScene();
      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: mcqCue.id, response: { choiceIndex: 1 } });

      // Another enrolled learner in the SAME course also submits — the
      // first learner's listing must NOT include the other's attempt.
      const other = await createUser({ role: 'LEARNER' });
      await enroll(other.id, course.id);
      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${other.accessToken}`)
        .send({ cueId: mcqCue.id, response: { choiceIndex: 0 } });

      const res = await request(app)
        .get('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(1);
      expect(res.body[0].userId).toBe(learner.id);

      const otherRes = await request(app)
        .get('/api/attempts')
        .set('authorization', `Bearer ${other.accessToken}`);
      expect(otherRes.status).toBe(200);
      expect(otherRes.body).toHaveLength(1);
      expect(otherRes.body[0].userId).toBe(other.id);
    });

    it('filters by videoId', async () => {
      const app = await getTestApp();
      const { designer, learner, course, mcqCue } = await seedEnrolledScene();
      // Create a second video + cue; submit an attempt on each.
      const v2 = await createVideoDirect(course.id);
      const mcq2 = await createCueDirect(v2.id, { type: 'MCQ', payload: MCQ_PAYLOAD });
      void designer;

      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: mcqCue.id, response: { choiceIndex: 1 } });
      await request(app)
        .post('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ cueId: mcq2.id, response: { choiceIndex: 1 } });

      const all = await request(app)
        .get('/api/attempts')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(all.body).toHaveLength(2);

      const filtered = await request(app)
        .get(`/api/attempts?videoId=${v2.id}`)
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(filtered.body).toHaveLength(1);
      expect(filtered.body[0].videoId).toBe(v2.id);
    });

    it('401 without bearer token', async () => {
      const app = await getTestApp();
      const res = await request(app).get('/api/attempts');
      expect(res.status).toBe(401);
    });
  });
});
