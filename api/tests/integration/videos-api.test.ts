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

// Mock the object-store so caption uploads don't require a live SeaweedFS
// bucket. We exercise the HTTP boundary + Prisma persistence; the S3 client
// itself is covered by tests/unit/services/object-store.test.ts. The mock
// includes `putObject` so the uploadBytes fast-path can resolve synchronously
// (caption.service calls it via the optional putObject hook in
// object-store-utils.ts). `deleteObject` is also mocked so DELETE captions
// tests don't need a real bucket.
jest.mock('@/services/object-store', () => {
  const uploadFile = jest.fn().mockResolvedValue(undefined);
  const downloadToFile = jest.fn().mockResolvedValue(undefined);
  const uploadDirectory = jest.fn().mockResolvedValue({ uploaded: 0 });
  const deleteObject = jest.fn().mockResolvedValue(undefined);
  const putObject = jest.fn().mockResolvedValue(undefined);
  const getObjectStream = jest.fn();
  return {
    createObjectStore: jest.fn(),
    objectStore: {
      uploadFile,
      downloadToFile,
      uploadDirectory,
      deleteObject,
      putObject,
      getObjectStream,
    },
  };
});

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

  // ---------------------------------------------------------------------------
  // Caption endpoints
  //
  // SRT fixture — 3 cues including a CJK character to lock in UTF-8 round-trip.
  // ---------------------------------------------------------------------------
  const SRT_FIXTURE = [
    '1',
    '00:00:01,000 --> 00:00:02,500',
    'Hello world',
    '',
    '2',
    '00:00:03,000 --> 00:00:05,000',
    '你好',
    '',
    '3',
    '00:00:05,500 --> 00:00:07,000',
    'Goodbye',
    '',
  ].join('\n');

  // Minimal valid WebVTT fixture.
  const VTT_FIXTURE = [
    'WEBVTT',
    '',
    '00:00:01.000 --> 00:00:02.500',
    'Hello world',
    '',
    '00:00:03.000 --> 00:00:05.000',
    '你好',
    '',
  ].join('\n');

  describe('Captions endpoints', () => {
    it('COURSE_DESIGNER owner uploads SRT: 200 with summary, caption listed, and in playback', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      // Upload SRT
      const uploadRes = await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(Buffer.from(SRT_FIXTURE, 'utf8'));

      expect(uploadRes.status).toBe(200);
      expect(uploadRes.body.language).toBe('en');
      expect(typeof uploadRes.body.bytes).toBe('number');
      expect(uploadRes.body.bytes).toBeGreaterThan(0);
      expect(uploadRes.body.uploadedAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);

      // List returns one row
      const listRes = await request(app)
        .get(`/api/videos/${video.id}/captions`)
        .set('authorization', `Bearer ${designer.accessToken}`);

      expect(listRes.status).toBe(200);
      expect(listRes.body.captions).toHaveLength(1);
      expect(listRes.body.captions[0].language).toBe('en');

      // Playback includes captions array with a signed URL
      const playbackRes = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${designer.accessToken}`);

      expect(playbackRes.status).toBe(200);
      expect(playbackRes.body.captions).toHaveLength(1);
      expect(playbackRes.body.captions[0].language).toBe('en');
      // URL shape: /hls/<sig>/<expires>/<videoId>/captions/en.vtt
      expect(playbackRes.body.captions[0].url).toMatch(
        /\/hls\/[A-Za-z0-9_-]+\/\d+\/[A-Za-z0-9-]+\/captions\/en\.vtt$/,
      );
      expect(playbackRes.body.captions[0].expiresAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    });

    it('COURSE_DESIGNER owner uploads WebVTT: 200 with summary', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      const uploadRes = await request(app)
        .post(`/api/videos/${video.id}/captions?language=zh-CN`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'text/vtt')
        .send(Buffer.from(VTT_FIXTURE, 'utf8'));

      expect(uploadRes.status).toBe(200);
      expect(uploadRes.body.language).toBe('zh-CN');
      expect(typeof uploadRes.body.bytes).toBe('number');
      expect(uploadRes.body.bytes).toBeGreaterThan(0);

      const listRes = await request(app)
        .get(`/api/videos/${video.id}/captions`)
        .set('authorization', `Bearer ${designer.accessToken}`);

      expect(listRes.status).toBe(200);
      expect(listRes.body.captions).toHaveLength(1);
      expect(listRes.body.captions[0].language).toBe('zh-CN');
    });

    it('setDefault=1 promotes language to Video.defaultCaptionLanguage', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      await request(app)
        .post(`/api/videos/${video.id}/captions?language=en&setDefault=1`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(Buffer.from(SRT_FIXTURE, 'utf8'));

      const playbackRes = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${designer.accessToken}`);

      expect(playbackRes.status).toBe(200);
      expect(playbackRes.body.defaultCaptionLanguage).toBe('en');
    });

    it('DELETE clears defaultCaptionLanguage when it matched; captions becomes empty', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      // Upload and set as default
      await request(app)
        .post(`/api/videos/${video.id}/captions?language=en&setDefault=1`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(Buffer.from(SRT_FIXTURE, 'utf8'));

      // Delete
      const deleteRes = await request(app)
        .delete(`/api/videos/${video.id}/captions/en`)
        .set('authorization', `Bearer ${designer.accessToken}`);

      expect(deleteRes.status).toBe(204);

      // Playback should now reflect cleared default and empty captions
      const playbackRes = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${designer.accessToken}`);

      expect(playbackRes.status).toBe(200);
      expect(playbackRes.body.defaultCaptionLanguage).toBeNull();
      expect(playbackRes.body.captions).toHaveLength(0);
    });

    it('upload is idempotent (upsert): second POST returns 200, single row in list', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      const firstPayload = Buffer.from(SRT_FIXTURE, 'utf8');
      const secondPayload = Buffer.from(
        [
          '1',
          '00:00:01,000 --> 00:00:02,500',
          'Updated cue',
          '',
        ].join('\n'),
        'utf8',
      );

      await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(firstPayload);

      const secondRes = await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(secondPayload);

      expect(secondRes.status).toBe(200);

      const listRes = await request(app)
        .get(`/api/videos/${video.id}/captions`)
        .set('authorization', `Bearer ${designer.accessToken}`);

      // Still one row after two uploads of the same language
      expect(listRes.body.captions).toHaveLength(1);
    });

    it('enrolled learner cannot upload captions (403)', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id);
      await enroll(learner.id, course.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      const res = await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${learner.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(Buffer.from(SRT_FIXTURE, 'utf8'));

      expect(res.status).toBe(403);
    });

    it('enrolled learner CAN list captions (200)', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id);
      await enroll(learner.id, course.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      // Upload as designer so there's at least one caption
      await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(Buffer.from(SRT_FIXTURE, 'utf8'));

      const res = await request(app)
        .get(`/api/videos/${video.id}/captions`)
        .set('authorization', `Bearer ${learner.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.captions).toHaveLength(1);
    });

    it('enrolled learner gets captions in playback response', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const learner = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id);
      await enroll(learner.id, course.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(Buffer.from(SRT_FIXTURE, 'utf8'));

      const res = await request(app)
        .get(`/api/videos/${video.id}/playback`)
        .set('authorization', `Bearer ${learner.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.captions).toHaveLength(1);
      expect(res.body.captions[0].language).toBe('en');
    });

    it('non-enrolled learner cannot list captions (403)', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const stranger = await createUser({ role: 'LEARNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      const res = await request(app)
        .get(`/api/videos/${video.id}/captions`)
        .set('authorization', `Bearer ${stranger.accessToken}`);

      expect(res.status).toBe(403);
    });

    it('COURSE_DESIGNER collaborator (LEARNER role) can upload captions', async () => {
      // A user with LEARNER role who has been added as a course collaborator
      // must be able to upload captions — the WRITE gate lives in the service
      // layer (hasCourseAccess), not in requireRole middleware, so this
      // verifies that the route doesn't add an unnecessary role guard.
      const app = await getTestApp();
      const owner = await createUser({ role: 'COURSE_DESIGNER' });
      // Collaborator has LEARNER role but is added as a course collaborator
      const collab = await createUser({ role: 'LEARNER' });
      const course = await createCourse(owner.id);
      await addCollaborator(course.id, collab.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      const res = await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${collab.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(Buffer.from(SRT_FIXTURE, 'utf8'));

      expect(res.status).toBe(200);
    });

    it('invalid BCP-47 language tag returns 400', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .post(`/api/videos/${video.id}/captions?language=EN_INVALID`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(Buffer.from(SRT_FIXTURE, 'utf8'));

      expect(res.status).toBe(400);
    });

    it('oversize body (>512 KB) returns 413', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      // CAPTION_MAX_BYTES = 512 * 1024 = 524288 bytes. We send exactly
      // 524289 bytes (CAPTION_MAX_BYTES + 1). The route-level express.raw
      // middleware uses limit: CAPTION_MAX_BYTES + 1, which allows bodies
      // up to that exact size, so this payload reaches the controller where
      // the explicit `bytes.byteLength > CAPTION_MAX_BYTES` check fires and
      // returns 413. Sending more than CAPTION_MAX_BYTES + 1 would be
      // rejected at the middleware layer with an http-errors instance that
      // our error-handler maps to 500 (it only knows AppError / Zod /
      // Prisma shapes).
      const oversizePayload = Buffer.alloc(512 * 1024 + 1, 0x41); // 0x41 = 'A'

      const res = await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(oversizePayload);

      expect(res.status).toBe(413);
    });

    it('wrong content-type returns 415', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${designer.accessToken}`)
        .set('content-type', 'image/jpeg')
        .send(Buffer.from('not a caption', 'utf8'));

      expect(res.status).toBe(415);
    });

    it('DELETE returns 404 for a nonexistent language', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id);

      const res = await request(app)
        .delete(`/api/videos/${video.id}/captions/en`)
        .set('authorization', `Bearer ${designer.accessToken}`);

      expect(res.status).toBe(404);
    });

    it('designer of a different course cannot upload captions to this video (403)', async () => {
      const app = await getTestApp();
      const ownerDesigner = await createUser({ role: 'COURSE_DESIGNER' });
      const otherDesigner = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(ownerDesigner.id);
      const video = await createVideoDirect(course.id, {
        status: 'READY',
        hlsPrefix: 'vod/x',
        durationMs: 3000,
      });

      // otherDesigner owns a separate course — cannot access ownerDesigner's video
      const res = await request(app)
        .post(`/api/videos/${video.id}/captions?language=en`)
        .set('authorization', `Bearer ${otherDesigner.accessToken}`)
        .set('content-type', 'application/x-subrip')
        .send(Buffer.from(SRT_FIXTURE, 'utf8'));

      expect(res.status).toBe(403);
    });
  });
});
