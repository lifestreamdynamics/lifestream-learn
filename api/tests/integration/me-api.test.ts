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
      // Media-serving route shipped; upload now returns the relative URL
      // clients compose against their API base URL.
      expect(res.body.avatarUrl).toBe('/api/me/avatar');

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

  describe('GET /api/me/avatar', () => {
    it('streams bytes + content-type when avatarKey is set', async () => {
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });
      await prisma.user.update({
        where: { id: user.id },
        data: { avatarKey: 'avatars/u/abc.png' },
      });

      // Stub the object-store read with a tiny PNG payload.
      const { Readable } = await import('node:stream');
      const bytes = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const store = require('@/services/object-store').objectStore;
      store.getObjectStream.mockResolvedValueOnce({
        stream: Readable.from([bytes]),
        contentType: 'image/png',
        contentLength: bytes.byteLength,
      });

      const res = await request(app)
        .get('/api/me/avatar')
        .set('authorization', `Bearer ${user.accessToken}`)
        .buffer(true)
        .parse((r, cb) => {
          const chunks: Buffer[] = [];
          r.on('data', (c: Buffer) => chunks.push(c));
          r.on('end', () => cb(null, Buffer.concat(chunks)));
        });

      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toBe('image/png');
      expect(res.headers['cache-control']).toBe('private, max-age=300');
      expect(Buffer.isBuffer(res.body)).toBe(true);
      expect((res.body as Buffer).equals(bytes)).toBe(true);

      expect(store.getObjectStream).toHaveBeenCalledWith(
        expect.any(String),
        'avatars/u/abc.png',
      );
    });

    it('204 when caller has no avatar set', async () => {
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get('/api/me/avatar')
        .set('authorization', `Bearer ${user.accessToken}`);
      expect(res.status).toBe(204);
    });

    it('401 when unauthenticated', async () => {
      const app = await getTestApp();
      const res = await request(app).get('/api/me/avatar');
      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/users/:id/avatar', () => {
    it('streams another user\'s avatar bytes', async () => {
      const app = await getTestApp();
      const caller = await createUser({ role: 'LEARNER' });
      const target = await createUser({ role: 'LEARNER' });
      await prisma.user.update({
        where: { id: target.id },
        data: { avatarKey: `avatars/${target.id}/xyz.webp` },
      });

      const { Readable } = await import('node:stream');
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const store = require('@/services/object-store').objectStore;
      store.getObjectStream.mockResolvedValueOnce({
        stream: Readable.from([Buffer.from('webp-bytes')]),
        contentType: 'image/webp',
        contentLength: 10,
      });

      const res = await request(app)
        .get(`/api/users/${target.id}/avatar`)
        .set('authorization', `Bearer ${caller.accessToken}`)
        .buffer(true)
        .parse((r, cb) => {
          const chunks: Buffer[] = [];
          r.on('data', (c: Buffer) => chunks.push(c));
          r.on('end', () => cb(null, Buffer.concat(chunks)));
        });

      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toBe('image/webp');
    });

    it('302 redirects to /api/me/avatar when id matches the caller', async () => {
      const app = await getTestApp();
      const caller = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get(`/api/users/${caller.id}/avatar`)
        .set('authorization', `Bearer ${caller.accessToken}`)
        .redirects(0);
      expect(res.status).toBe(302);
      expect(res.headers.location).toBe('/api/me/avatar');
    });

    it('204 when target user exists but has no avatar', async () => {
      const app = await getTestApp();
      const caller = await createUser({ role: 'LEARNER' });
      const target = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get(`/api/users/${target.id}/avatar`)
        .set('authorization', `Bearer ${caller.accessToken}`);
      expect(res.status).toBe(204);
    });

    it('404 when target user does not exist', async () => {
      const app = await getTestApp();
      const caller = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get('/api/users/00000000-0000-4000-8000-000000000000/avatar')
        .set('authorization', `Bearer ${caller.accessToken}`);
      expect(res.status).toBe(404);
    });

    it('401 when unauthenticated', async () => {
      const app = await getTestApp();
      const res = await request(app).get('/api/users/anything/avatar');
      expect(res.status).toBe(401);
    });
  });
});
