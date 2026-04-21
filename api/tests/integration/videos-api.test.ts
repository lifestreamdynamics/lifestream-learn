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
} from '@tests/integration/helpers/factories';

// Mock the transcode queue so POST /api/videos doesn't attempt to enqueue
// against the real BullMQ (these tests aren't exercising the worker path).
jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
  getTranscodeQueue: jest.fn().mockReturnValue({
    client: Promise.resolve({ ping: () => Promise.resolve('PONG') }),
  }),
  TRANSCODE_QUEUE_NAME: 'transcode',
  closeTranscodeQueue: jest.fn().mockResolvedValue(undefined),
}));

describe('Videos API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('POST /api/videos', () => {
    it('returns 201 with videoId, uploadUrl, uploadHeaders when course designer owns the course', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);

      const res = await request(app)
        .post('/api/videos')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ courseId: course.id, title: 'My First Video', orderIndex: 0 });

      expect(res.status).toBe(201);
      expect(res.body.videoId).toEqual(expect.any(String));
      expect(res.body.uploadUrl).toMatch(/\/files$/);
      expect(res.body.uploadHeaders['Tus-Resumable']).toBe('1.0.0');
      expect(res.body.uploadHeaders['Upload-Metadata']).toMatch(/^videoId /);
      expect(res.body.video.status).toBe('UPLOADING');
      expect(res.body.sourceKey).toBe(`uploads/${res.body.videoId}`);
    });

    it('403 when a designer tries to add a video to a course they do not own', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const other = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(owner.id);

      const res = await request(app)
        .post('/api/videos')
        .set('authorization', `Bearer ${other.accessToken}`)
        .send({ courseId: course.id, title: 'Nope', orderIndex: 0 });

      expect(res.status).toBe(403);
      expect(res.body.error).toBe('FORBIDDEN');
    });

    it('403 when a learner tries to create a video', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id);

      const res = await request(app)
        .post('/api/videos')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ courseId: course.id, title: 'Hi', orderIndex: 0 });

      expect(res.status).toBe(403);
    });

    it('201 when an admin creates a video in any course', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);

      const res = await request(app)
        .post('/api/videos')
        .set('authorization', `Bearer ${admin.accessToken}`)
        .send({ courseId: course.id, title: 'Admin override', orderIndex: 1 });

      expect(res.status).toBe(201);
    });

    it('400 on malformed body', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });

      const res = await request(app)
        .post('/api/videos')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ courseId: 'not-a-uuid', title: '', orderIndex: -1 });

      expect(res.status).toBe(400);
      expect(res.body.error).toBe('VALIDATION_ERROR');
    });

    it('401 without bearer token', async () => {
      const app = await getTestApp();
      const res = await request(app).post('/api/videos').send({});
      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/videos/:id', () => {
    it('owner can read their own video', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .get(`/api/videos/${video.id}`)
        .set('authorization', `Bearer ${designer.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.id).toBe(video.id);
      expect(res.body.status).toBe('UPLOADING');
    });

    it('random authenticated user gets 403', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const stranger = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .get(`/api/videos/${video.id}`)
        .set('authorization', `Bearer ${stranger.accessToken}`);

      expect(res.status).toBe(403);
    });

    it('404 for missing video', async () => {
      const app = await getTestApp();
      const user = await createUser({ role: 'ADMIN' });
      const res = await request(app)
        .get('/api/videos/00000000-0000-0000-0000-000000000000')
        .set('authorization', `Bearer ${user.accessToken}`);
      expect(res.status).toBe(404);
    });
  });

  describe('GET /api/videos/:id/playback', () => {
    it('admin gets a signed URL for a READY video', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: `vod/x`,
        durationMs: 3000,
      });

      const res = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${admin.accessToken}`);

      expect(res.status).toBe(200);
      // URL shape: /hls/<sig>/<expires>/<videoId>/master.m3u8
      expect(res.body.masterPlaylistUrl).toMatch(
        /\/hls\/[A-Za-z0-9_-]+\/\d+\/[A-Za-z0-9-]+\/master\.m3u8$/,
      );
      expect(res.body.expiresAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    });

    it('course owner gets a signed URL', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: `vod/x`,
        durationMs: 3000,
      });

      const res = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(res.status).toBe(200);
    });

    it('course collaborator gets a signed URL', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const collab = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(owner.id);
      await addCollaborator(course.id, collab.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: `vod/x`,
        durationMs: 3000,
      });

      const res = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${collab.accessToken}`);
      expect(res.status).toBe(200);
    });

    it('enrolled learner gets a signed URL', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(owner.id);
      await enroll(learner.id, course.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: `vod/x`,
        durationMs: 3000,
      });

      const res = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
    });

    it('random user gets 403', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      const stranger = await createUser({ role: 'LEARNER' });
      const course = await createCourse(owner.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: `vod/x`,
        durationMs: 3000,
      });

      const res = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${stranger.accessToken}`);
      expect(res.status).toBe(403);
    });

    it('409 when status is not READY', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, { status: 'UPLOADING' });

      const res = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${admin.accessToken}`);
      expect(res.status).toBe(409);
    });

    it('404 for missing video', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const res = await request(app)
        .get('/api/videos/00000000-0000-0000-0000-000000000000/playback')
        .set('authorization', `Bearer ${admin.accessToken}`);
      expect(res.status).toBe(404);
    });

    it('IDOR: designer A cannot fetch a playback URL for designer B\'s video', async () => {
      // Two designers each own separate courses. Designer A holds a valid
      // access token but must not be able to swap in designer B's video id
      // and receive a signed URL. Core IDOR regression.
      const app = await getTestApp();
      const designerA = await createUser({ role: 'COURSE_DESIGNER' });
      const designerB = await createUser({ role: 'COURSE_DESIGNER' });
      const courseB = await createCourse(designerB.id);
      const videoB = await createVideoDirect(courseB.id, {
        status: 'READY',
        hlsPrefix: 'vod/b',
        durationMs: 3000,
      });

      const res = await request(app)
        .get(`/api/videos/${videoB.id}/playback`)
        .set('authorization', `Bearer ${designerA.accessToken}`);
      expect(res.status).toBe(403);
    });
  });
});
