import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { prisma } from '@/config/prisma';
import {
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

const MCQ_PAYLOAD = {
  question: 'q?',
  choices: ['a', 'b'],
  answerIndex: 0,
};

describe('Feed API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  it('empty feed for fresh learner', async () => {
    const app = await getTestApp();
    const learner = await createUser({ role: 'LEARNER' });
    const res = await request(app)
      .get('/api/feed')
      .set('authorization', `Bearer ${learner.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toEqual([]);
    expect(res.body.hasMore).toBe(false);
  });

  it('401 unauthenticated', async () => {
    const app = await getTestApp();
    const res = await request(app).get('/api/feed');
    expect(res.status).toBe(401);
  });

  it('stitches cueCount and hasAttempted correctly', async () => {
    const app = await getTestApp();
    const designer = await createUser({ role: 'COURSE_DESIGNER' });
    const learner = await createUser({ role: 'LEARNER' });
    const course = await createCourse(designer.id, { slug: 'c', published: true });
    const v0 = await createVideoDirect(course.id, {
      orderIndex: 0,
      status: 'READY',
      hlsPrefix: 'x',
    });
    const v1 = await createVideoDirect(course.id, {
      orderIndex: 1,
      status: 'READY',
      hlsPrefix: 'x',
    });
    const cueV0 = await createCueDirect(v0.id, {
      type: 'MCQ',
      payload: MCQ_PAYLOAD,
      atMs: 100,
    });
    // v0 gets 2 cues; v1 gets 0 cues
    await createCueDirect(v0.id, {
      type: 'MCQ',
      payload: MCQ_PAYLOAD,
      atMs: 200,
      orderIndex: 1,
    });
    await enroll(learner.id, course.id);
    // Learner attempts the cue on v0 (directly via prisma to keep the test
    // focused on the feed endpoint, not the attempts endpoint).
    await prisma.attempt.create({
      data: {
        userId: learner.id,
        videoId: v0.id,
        cueId: cueV0.id,
        correct: true,
      },
    });

    const res = await request(app)
      .get('/api/feed')
      .set('authorization', `Bearer ${learner.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(2);
    // Ordering: same enrollment startedAt → by orderIndex asc (v0 first).
    const [first, second] = res.body.items;
    expect(first.video.id).toBe(v0.id);
    expect(first.cueCount).toBe(2);
    expect(first.hasAttempted).toBe(true);
    expect(second.video.id).toBe(v1.id);
    expect(second.cueCount).toBe(0);
    expect(second.hasAttempted).toBe(false);
  });

  it('ordering: newer enrollment first, then video orderIndex asc', async () => {
    const app = await getTestApp();
    const designer = await createUser({ role: 'COURSE_DESIGNER' });
    const learner = await createUser({ role: 'LEARNER' });
    const older = await createCourse(designer.id, { slug: 'a', published: true });
    const newer = await createCourse(designer.id, { slug: 'b', published: true });
    await createVideoDirect(older.id, {
      orderIndex: 0,
      status: 'READY',
      hlsPrefix: 'x',
    });
    await createVideoDirect(newer.id, {
      orderIndex: 0,
      status: 'READY',
      hlsPrefix: 'x',
    });

    await enroll(learner.id, older.id);
    await new Promise((r) => setTimeout(r, 15));
    await enroll(learner.id, newer.id);

    const res = await request(app)
      .get('/api/feed')
      .set('authorization', `Bearer ${learner.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(2);
    expect(res.body.items[0].course.id).toBe(newer.id);
    expect(res.body.items[1].course.id).toBe(older.id);
  });

  it('skips non-READY videos', async () => {
    const app = await getTestApp();
    const designer = await createUser({ role: 'COURSE_DESIGNER' });
    const learner = await createUser({ role: 'LEARNER' });
    const course = await createCourse(designer.id, { slug: 'cc', published: true });
    await createVideoDirect(course.id, { orderIndex: 0, status: 'UPLOADING' });
    await createVideoDirect(course.id, { orderIndex: 1, status: 'TRANSCODING' });
    await createVideoDirect(course.id, {
      orderIndex: 2,
      status: 'READY',
      hlsPrefix: 'x',
    });
    await enroll(learner.id, course.id);

    const res = await request(app)
      .get('/api/feed')
      .set('authorization', `Bearer ${learner.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0].video.status).toBe('READY');
  });

  it('pagination cursor round-trip', async () => {
    const app = await getTestApp();
    const designer = await createUser({ role: 'COURSE_DESIGNER' });
    const learner = await createUser({ role: 'LEARNER' });
    const course = await createCourse(designer.id, {
      slug: 'page',
      published: true,
    });
    for (let i = 0; i < 3; i += 1) {
      await createVideoDirect(course.id, {
        orderIndex: i,
        status: 'READY',
        hlsPrefix: 'x',
      });
    }
    await enroll(learner.id, course.id);

    const p1 = await request(app)
      .get('/api/feed?limit=2')
      .set('authorization', `Bearer ${learner.accessToken}`);
    expect(p1.status).toBe(200);
    expect(p1.body.items).toHaveLength(2);
    expect(p1.body.hasMore).toBe(true);

    const p2 = await request(app)
      .get(`/api/feed?limit=2&cursor=${encodeURIComponent(p1.body.nextCursor)}`)
      .set('authorization', `Bearer ${learner.accessToken}`);
    expect(p2.status).toBe(200);
    expect(p2.body.items).toHaveLength(1);
    expect(p2.body.hasMore).toBe(false);
    // All 3 distinct videoIds once concatenated
    const ids = [...p1.body.items, ...p2.body.items].map(
      (e: { video: { id: string } }) => e.video.id,
    );
    expect(new Set(ids).size).toBe(3);
  });
});
