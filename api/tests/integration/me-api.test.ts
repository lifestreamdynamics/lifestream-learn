import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { createUser } from '@tests/integration/helpers/factories';
import { prisma } from '@/config/prisma';

// Mock the transcode queue so mounting the app doesn't open a live BullMQ
// connection — matches the pattern used in the other integration suites.
jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
  getTranscodeQueue: jest.fn().mockReturnValue({
    client: Promise.resolve({ ping: () => Promise.resolve('PONG') }),
  }),
  TRANSCODE_QUEUE_NAME: 'transcode',
  closeTranscodeQueue: jest.fn().mockResolvedValue(undefined),
}));

// Mock the object-store at the module level so the avatar upload path
// doesn't require a live SeaweedFS bucket. We're exercising the HTTP
// boundary + Prisma persistence; the S3 client is covered by its own
// tests in `tests/unit/services/object-store.test.ts`.
jest.mock('@/services/object-store', () => {
  const uploadFile = jest.fn().mockResolvedValue(undefined);
  const downloadToFile = jest.fn().mockResolvedValue(undefined);
  const uploadDirectory = jest.fn().mockResolvedValue({ uploaded: 0 });
  const deleteObject = jest.fn().mockResolvedValue(undefined);
  const putObject = jest.fn().mockResolvedValue(undefined);
  return {
    createObjectStore: jest.fn(),
    objectStore: {
      uploadFile,
      downloadToFile,
      uploadDirectory,
      deleteObject,
      putObject,
    },
  };
});

describe('Me API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
    jest.clearAllMocks();
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('PATCH /api/me', () => {
    it('happy path: updates displayName and reflects in response', async () => {
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER', displayName: 'Before' });

      const res = await request(app)
        .patch('/api/me')
        .set('authorization', `Bearer ${user.accessToken}`)
        .send({ displayName: 'After' });

      expect(res.status).toBe(200);
      expect(res.body.displayName).toBe('After');
      expect(res.body.id).toBe(user.id);
      expect(res.body.email).toBe(user.email);
      // Profile fields flow through.
      expect(res.body).toHaveProperty('avatarKey', null);
      expect(res.body).toHaveProperty('useGravatar', false);
      expect(res.body).toHaveProperty('preferences', null);

      // DB persisted the change.
      const row = await prisma.user.findUnique({ where: { id: user.id } });
      expect(row?.displayName).toBe('After');
    });

    it('updates useGravatar + preferences together', async () => {
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });

      const res = await request(app)
        .patch('/api/me')
        .set('authorization', `Bearer ${user.accessToken}`)
        .send({
          useGravatar: true,
          preferences: { theme: 'dark', playbackSpeed: 1.5 },
        });

      expect(res.status).toBe(200);
      expect(res.body.useGravatar).toBe(true);
      expect(res.body.preferences).toEqual({
        theme: 'dark',
        playbackSpeed: 1.5,
      });
    });

    it('401 when unauthenticated', async () => {
      const app = await getTestApp();
      const res = await request(app)
        .patch('/api/me')
        .send({ displayName: 'Attempt' });
      expect(res.status).toBe(401);
    });

    it('400 when displayName is too long', async () => {
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });

      const tooLong = 'x'.repeat(81);
      const res = await request(app)
        .patch('/api/me')
        .set('authorization', `Bearer ${user.accessToken}`)
        .send({ displayName: tooLong });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('VALIDATION_ERROR');
    });

    it('400 + strict: unknown keys rejected (email, role, passwordHash)', async () => {
      // `.strict()` on the Zod schema rejects unknown keys outright — a
      // stronger guarantee than "silently stripped". A client attempting
      // to set `role` or `email` gets a clear 400 rather than a masked
      // silent drop.
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });

      const res = await request(app)
        .patch('/api/me')
        .set('authorization', `Bearer ${user.accessToken}`)
        .send({
          displayName: 'Fine',
          email: 'hack@example.local',
          role: 'ADMIN',
        });
      expect(res.status).toBe(400);

      // Ensure DB was NOT mutated at all.
      const row = await prisma.user.findUnique({ where: { id: user.id } });
      expect(row?.email).toBe(user.email);
      expect(row?.role).toBe('LEARNER');
      expect(row?.displayName).toBe('Test User');
    });
  });

  describe('POST /api/me/avatar', () => {
    it('happy path: accepts PNG, persists key, returns avatarKey', async () => {
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });
      // Minimal PNG header so our content-type gate is the only thing
      // this test exercises — the object-store is mocked.
      const pngHeader = Buffer.from([
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
      ]);

      const res = await request(app)
        .post('/api/me/avatar')
        .set('authorization', `Bearer ${user.accessToken}`)
        .set('content-type', 'image/png')
        .send(pngHeader);

      expect(res.status).toBe(200);
      expect(res.body.avatarKey).toMatch(
        new RegExp(`^avatars/${user.id}/[0-9a-f-]+\\.png$`),
      );
      expect(res.body.avatarUrl).toBeNull();

      const row = await prisma.user.findUnique({ where: { id: user.id } });
      expect(row?.avatarKey).toBe(res.body.avatarKey);
    });

    it('415 when content-type is not an image', async () => {
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .post('/api/me/avatar')
        .set('authorization', `Bearer ${user.accessToken}`)
        .set('content-type', 'application/pdf')
        .send(Buffer.from('not an image'));
      // `express.raw({ type: 'image/*' })` ignores non-image bodies,
      // leaving `req.body` as an empty object which the controller maps
      // to 415 via its content-type check.
      expect(res.status).toBe(415);
    });

    it('413 when payload exceeds 2 MB', async () => {
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });
      // 2 MB + a byte. `express.raw({ limit: 2*1024*1024 + 1 })` lets
      // one extra byte through on the wire so our controller can return
      // a clean 413 — but bodies beyond that hit express's own limiter.
      // Either way the caller gets a 4xx; we assert 413 specifically.
      const tooBig = Buffer.alloc(2 * 1024 * 1024 + 1, 0xff);
      const res = await request(app)
        .post('/api/me/avatar')
        .set('authorization', `Bearer ${user.accessToken}`)
        .set('content-type', 'image/jpeg')
        .send(tooBig);
      // `express.raw` returns a generic error envelope at its own limit;
      // we accept either 413 or the express-emitted 413 shape.
      expect([413]).toContain(res.status);
    });

    it('401 when unauthenticated', async () => {
      const app = await getTestApp();
      const res = await request(app)
        .post('/api/me/avatar')
        .set('content-type', 'image/png')
        .send(Buffer.from('png'));
      expect(res.status).toBe(401);
    });
  });
});
