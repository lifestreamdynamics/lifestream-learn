import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import {
  createAnalyticsEvent,
  createCourse,
  createCueDirect,
  createUser,
  createVideoDirect,
  enroll,
} from '@tests/integration/helpers/factories';
import { prisma } from '@/config/prisma';

// Mock the transcode queue + object store so mounting the app doesn't
// open live BullMQ / SeaweedFS connections. Matches the pattern used
// in the other integration suites.
jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
  getTranscodeQueue: jest.fn().mockReturnValue({
    client: Promise.resolve({ ping: () => Promise.resolve('PONG') }),
  }),
  TRANSCODE_QUEUE_NAME: 'transcode',
  closeTranscodeQueue: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('@/services/object-store', () => ({
  createObjectStore: jest.fn(),
  objectStore: {
    uploadFile: jest.fn().mockResolvedValue(undefined),
    downloadToFile: jest.fn().mockResolvedValue(undefined),
    uploadDirectory: jest.fn().mockResolvedValue({ uploaded: 0 }),
    deleteObject: jest.fn().mockResolvedValue(undefined),
    putObject: jest.fn().mockResolvedValue(undefined),
  },
}));

const DEFAULT_PASSWORD = 'CorrectHorse1234';

async function signup(
  email: string,
  password = DEFAULT_PASSWORD,
): Promise<{
  userId: string;
  accessToken: string;
  refreshToken: string;
}> {
  const app = await getTestApp();
  const res = await request(app)
    .post('/api/auth/signup')
    .send({ email, password, displayName: 'Test User' });
  if (res.status !== 201) {
    throw new Error(`signup failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return {
    userId: res.body.user.id as string,
    accessToken: res.body.accessToken as string,
    refreshToken: res.body.refreshToken as string,
  };
}

describe('GET /api/me/export (integration) — Slice P8', () => {
  beforeEach(async () => {
    await resetDb();
    // rl:me:export:* is the per-user bucket for this limiter; the P8 rate
    // limit is 1/24h so every test starts from a clean slate.
    await resetRedisKeys(['rl:*', 'bull:*', 'refresh-revoked:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  it('happy path: returns shape with user enrollments / attempts / analytics', async () => {
    const app = await getTestApp();
    const { userId, accessToken } = await signup('export-happy@example.local');

    // Seed some state the export should include.
    const designer = await createUser({ role: 'COURSE_DESIGNER' });
    const course = await createCourse(designer.id, {
      title: 'Export Test Course',
      published: true,
    });
    const video = await createVideoDirect(course.id, {
      status: 'READY',
      hlsPrefix: `vod/${course.id}/v1/`,
    });
    const cue = await createCueDirect(video.id, {
      type: 'MCQ',
      atMs: 1000,
      payload: {
        prompt: 'q',
        options: [{ text: 'a', correct: true }, { text: 'b', correct: false }],
      },
    });
    await enroll(userId, course.id);
    await prisma.attempt.create({
      data: {
        userId,
        videoId: video.id,
        cueId: cue.id,
        correct: true,
        scoreJson: { score: 1 },
      },
    });
    await createAnalyticsEvent(userId, {
      eventType: 'video_view',
      videoId: video.id,
      occurredAt: new Date('2026-04-15T00:00:00Z'),
      payload: { playerState: 'foreground' },
    });

    const res = await request(app)
      .get('/api/me/export')
      .set('authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);
    // Attachment headers so browsers and share-sheets save rather than render.
    expect(res.headers['content-type']).toMatch(/^application\/json/);
    expect(res.headers['content-disposition']).toMatch(
      /^attachment; filename="lifestream-learn-export-/,
    );
    expect(res.headers['cache-control']).toBe('no-store');

    const body = res.body as Record<string, unknown>;
    expect(body.schemaVersion).toBe(1);
    expect(typeof body.exportedAt).toBe('string');
    // Shape check — every documented key present.
    for (const key of [
      'user',
      'enrollments',
      'attempts',
      'analyticsEvents',
      'analyticsEventsTruncated',
      'achievements',
      'sessions',
      'ownedCoursesCount',
      'collaboratorCoursesCount',
    ]) {
      expect(body).toHaveProperty(key);
    }

    // User block has the allowed fields.
    const user = body.user as Record<string, unknown>;
    expect(user.id).toBe(userId);
    expect(user.email).toBe('export-happy@example.local');
    expect(user.role).toBe('LEARNER');
    expect(user.mfaEnabled).toBe(false);
    // Credentials MUST NOT appear anywhere in the payload.
    const serialized = JSON.stringify(body);
    expect(serialized).not.toContain('passwordHash');
    expect(serialized).not.toContain('mfaBackupCodes');
    expect(serialized).not.toContain('mfaSecretEncrypted');

    // Collections wired up.
    const enrollments = body.enrollments as Array<Record<string, unknown>>;
    expect(enrollments).toHaveLength(1);
    expect(enrollments[0].courseId).toBe(course.id);
    expect(enrollments[0].courseTitle).toBe('Export Test Course');

    const attempts = body.attempts as Array<Record<string, unknown>>;
    expect(attempts).toHaveLength(1);
    expect(attempts[0].cueId).toBe(cue.id);
    expect(attempts[0].correct).toBe(true);

    const events = body.analyticsEvents as Array<Record<string, unknown>>;
    expect(events.length).toBeGreaterThanOrEqual(1);
    // Seeded event is present.
    const videoViewEvent = events.find((e) => e.eventType === 'video_view');
    expect(videoViewEvent).toBeDefined();

    expect(body.analyticsEventsTruncated).toBe(false);
    expect(body.ownedCoursesCount).toBe(0);
    expect(body.collaboratorCoursesCount).toBe(0);
  });

  it('sessions in the export redact ipHash to an 8-char prefix', async () => {
    const app = await getTestApp();
    const { accessToken } = await signup('export-sessions@example.local');

    const res = await request(app)
      .get('/api/me/export')
      .set('authorization', `Bearer ${accessToken}`);
    expect(res.status).toBe(200);

    const sessions = res.body.sessions as Array<Record<string, unknown>>;
    expect(sessions.length).toBeGreaterThanOrEqual(1);
    for (const s of sessions) {
      // 8 hex chars OR null. We explicitly NEVER emit the full 32-char hash.
      if (s.ipHashPrefix != null) {
        expect(s.ipHashPrefix).toMatch(/^[0-9a-f]{8}$/);
      }
      // The full ipHash field must not appear.
      expect(s).not.toHaveProperty('ipHash');
    }
  });

  it('401 when unauthenticated', async () => {
    const app = await getTestApp();
    const res = await request(app).get('/api/me/export');
    expect(res.status).toBe(401);
  });

  it('403 for a soft-deleted user (within the 15-min access-token grace window)', async () => {
    const app = await getTestApp();
    const { userId, accessToken } = await signup('export-deleted@example.local');

    // Soft-delete directly in the DB (bypassing the user.service.softDelete
    // path so this test doesn't depend on the P5 flow). The access token
    // was minted before the flip so it stays JWT-valid until its TTL
    // expires — this is exactly the grace-window case we need to gate.
    await prisma.user.update({
      where: { id: userId },
      data: {
        deletedAt: new Date(),
        deletionPurgeAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    });

    const res = await request(app)
      .get('/api/me/export')
      .set('authorization', `Bearer ${accessToken}`);
    expect(res.status).toBe(403);
    expect(res.body.error).toBe('ACCOUNT_DELETED');
  });

  it('429 on a second call within the 24h window', async () => {
    const app = await getTestApp();
    const { accessToken } = await signup('export-ratelimit@example.local');

    const first = await request(app)
      .get('/api/me/export')
      .set('authorization', `Bearer ${accessToken}`);
    expect(first.status).toBe(200);

    const second = await request(app)
      .get('/api/me/export')
      .set('authorization', `Bearer ${accessToken}`);
    expect(second.status).toBe(429);
    expect(second.body.error).toBe('RATE_LIMITED');
    // draft-7 standardHeaders: RateLimit + Retry-After on 429s.
    // Retry-After is required for the client to compute a "try again
    // in X hours" message.
    expect(second.headers['retry-after']).toBeDefined();
  });

  it('rate-limit bucket is keyed PER USER, not per IP', async () => {
    // Alice and Bob share a test IP (supertest uses 127.0.0.1 for all
    // connections). Alice exports once — Bob should still be able to
    // export because the limiter bucket is scoped to Alice's userId.
    const app = await getTestApp();
    const alice = await signup('export-alice@example.local');
    const bob = await signup('export-bob@example.local');

    const aliceRes = await request(app)
      .get('/api/me/export')
      .set('authorization', `Bearer ${alice.accessToken}`);
    expect(aliceRes.status).toBe(200);

    const bobRes = await request(app)
      .get('/api/me/export')
      .set('authorization', `Bearer ${bob.accessToken}`);
    expect(bobRes.status).toBe(200);
  });
});
