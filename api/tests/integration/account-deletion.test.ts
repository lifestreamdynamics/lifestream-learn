import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { prisma } from '@/config/prisma';

// Mock the transcode queue + object store so mounting the app doesn't open
// live BullMQ / SeaweedFS connections. Matches the pattern used in the
// other integration suites.
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

describe('DELETE /api/me (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  it('happy path: 204, deletedAt persisted, refresh/login rejected', async () => {
    const app = await getTestApp();
    const { userId, accessToken, refreshToken } = await signup(
      'delete-happy@example.local',
    );

    const delRes = await request(app)
      .delete('/api/me')
      .set('authorization', `Bearer ${accessToken}`)
      .send({ currentPassword: DEFAULT_PASSWORD });
    expect(delRes.status).toBe(204);

    // DB state: deletedAt + deletionPurgeAt populated, row NOT removed.
    const row = await prisma.user.findUnique({ where: { id: userId } });
    expect(row).not.toBeNull();
    expect(row!.deletedAt).toBeInstanceOf(Date);
    expect(row!.deletionPurgeAt).toBeInstanceOf(Date);
    // ~30 days between them (tolerate small drift from the two `new Date()`
    // calls in the service).
    const diff =
      row!.deletionPurgeAt!.getTime() - row!.deletedAt!.getTime();
    expect(Math.abs(diff - 30 * 24 * 60 * 60 * 1000)).toBeLessThan(2000);
    // passwordChangedAt bumped too.
    expect(row!.passwordChangedAt).toBeInstanceOf(Date);

    // Refresh token is rejected on next use (both deletedAt AND the
    // iat-vs-passwordChangedAt check apply).
    const refreshRes = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken });
    expect(refreshRes.status).toBe(401);

    // Login with correct credentials fails with the SAME generic message
    // as "wrong password" — must not leak that the account still exists
    // but is deleted.
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'delete-happy@example.local', password: DEFAULT_PASSWORD });
    expect(loginRes.status).toBe(401);
    expect(loginRes.body.message).toBe('Invalid credentials');

    // Same-message property holds against a wrong-password attempt on a
    // *non-existent* email — the two cases are indistinguishable to the
    // client.
    const loginMissing = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'never-existed@example.local',
        password: DEFAULT_PASSWORD,
      });
    expect(loginMissing.status).toBe(401);
    expect(loginMissing.body.message).toBe(loginRes.body.message);
  });

  it('401 when current password is wrong (account NOT deleted)', async () => {
    const app = await getTestApp();
    const { userId, accessToken } = await signup(
      'delete-wrongpw@example.local',
    );

    const res = await request(app)
      .delete('/api/me')
      .set('authorization', `Bearer ${accessToken}`)
      .send({ currentPassword: 'NotTheRightOne1234' });
    expect(res.status).toBe(401);

    const row = await prisma.user.findUnique({ where: { id: userId } });
    expect(row!.deletedAt).toBeNull();
    expect(row!.deletionPurgeAt).toBeNull();
  });

  it('401 when unauthenticated', async () => {
    const app = await getTestApp();
    const res = await request(app)
      .delete('/api/me')
      .send({ currentPassword: DEFAULT_PASSWORD });
    expect(res.status).toBe(401);
  });

  it('400 when currentPassword is missing from body', async () => {
    const app = await getTestApp();
    const { accessToken } = await signup('delete-nobody@example.local');
    const res = await request(app)
      .delete('/api/me')
      .set('authorization', `Bearer ${accessToken}`)
      .send({});
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('VALIDATION_ERROR');
  });
});
