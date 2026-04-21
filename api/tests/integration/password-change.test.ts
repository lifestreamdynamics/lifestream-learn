import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { prisma } from '@/config/prisma';
import { verifyPassword } from '@/utils/password';

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
  displayName = 'Test User',
  password = DEFAULT_PASSWORD,
): Promise<{
  userId: string;
  accessToken: string;
  refreshToken: string;
}> {
  const app = await getTestApp();
  const res = await request(app)
    .post('/api/auth/signup')
    .send({ email, password, displayName });
  if (res.status !== 201) {
    throw new Error(`signup failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return {
    userId: res.body.user.id as string,
    accessToken: res.body.accessToken as string,
    refreshToken: res.body.refreshToken as string,
  };
}

describe('POST /api/me/password (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    // Clear both the password-change limiter bucket AND the login/refresh
    // ones so back-to-back tests don't trip each other.
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  it('happy path: 204, new password works, old refresh token rejected', async () => {
    const app = await getTestApp();
    const { userId, accessToken, refreshToken } = await signup(
      'happy-pw@example.local',
    );

    const newPassword = 'BrandNewPass5678';
    const changeRes = await request(app)
      .post('/api/me/password')
      .set('authorization', `Bearer ${accessToken}`)
      .send({
        currentPassword: DEFAULT_PASSWORD,
        newPassword,
      });
    expect(changeRes.status).toBe(204);

    // DB persisted a fresh bcrypt hash (not plaintext) and it verifies
    // against the new password.
    const row = await prisma.user.findUnique({ where: { id: userId } });
    expect(row).not.toBeNull();
    expect(row!.passwordHash).not.toBe(newPassword);
    expect(row!.passwordHash).not.toBe(DEFAULT_PASSWORD);
    expect(await verifyPassword(newPassword, row!.passwordHash)).toBe(true);
    expect(row!.passwordChangedAt).toBeInstanceOf(Date);

    // Old refresh token is rejected because its `iat` predates
    // passwordChangedAt.
    const refreshRes = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken });
    expect(refreshRes.status).toBe(401);

    // Login with the NEW password succeeds.
    const loginNewRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'happy-pw@example.local', password: newPassword });
    expect(loginNewRes.status).toBe(200);

    // Login with the OLD password no longer works.
    const loginOldRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'happy-pw@example.local', password: DEFAULT_PASSWORD });
    expect(loginOldRes.status).toBe(401);
  });

  it('401 when current password is wrong (no DB mutation)', async () => {
    const app = await getTestApp();
    const { userId, accessToken } = await signup('wrong-curr@example.local');

    const res = await request(app)
      .post('/api/me/password')
      .set('authorization', `Bearer ${accessToken}`)
      .send({
        currentPassword: 'NotTheRightOne1234',
        newPassword: 'BrandNewPass5678',
      });
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('UNAUTHORIZED');

    const row = await prisma.user.findUnique({ where: { id: userId } });
    expect(row!.passwordChangedAt).toBeNull();
    expect(await verifyPassword(DEFAULT_PASSWORD, row!.passwordHash)).toBe(
      true,
    );
  });

  it('400 when new password is too short', async () => {
    const app = await getTestApp();
    const { accessToken } = await signup('short-new@example.local');

    const res = await request(app)
      .post('/api/me/password')
      .set('authorization', `Bearer ${accessToken}`)
      .send({
        currentPassword: DEFAULT_PASSWORD,
        newPassword: 'short',
      });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('VALIDATION_ERROR');
  });

  it('400 when new password equals current', async () => {
    const app = await getTestApp();
    const { accessToken } = await signup('same-pw@example.local');

    const res = await request(app)
      .post('/api/me/password')
      .set('authorization', `Bearer ${accessToken}`)
      .send({
        currentPassword: DEFAULT_PASSWORD,
        newPassword: DEFAULT_PASSWORD,
      });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('VALIDATION_ERROR');
  });

  it('401 when unauthenticated', async () => {
    const app = await getTestApp();
    const res = await request(app).post('/api/me/password').send({
      currentPassword: DEFAULT_PASSWORD,
      newPassword: 'BrandNewPass5678',
    });
    expect(res.status).toBe(401);
  });

  it('rate limit kicks in after 5 attempts per IP', async () => {
    const app = await getTestApp();
    const { accessToken } = await signup('rl-pw@example.local');

    // 5 wrong-password attempts — all 401 but allowed through the limiter.
    for (let i = 0; i < 5; i++) {
      const res = await request(app)
        .post('/api/me/password')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          currentPassword: 'NotTheRightOne1234',
          newPassword: 'BrandNewPass5678',
        });
      expect(res.status).toBe(401);
    }

    // The 6th attempt should be throttled — even with the CORRECT current
    // password. This proves the limiter wraps the handler rather than
    // sitting inside it.
    const throttled = await request(app)
      .post('/api/me/password')
      .set('authorization', `Bearer ${accessToken}`)
      .send({
        currentPassword: DEFAULT_PASSWORD,
        newPassword: 'BrandNewPass5678',
      });
    expect(throttled.status).toBe(429);
    expect(throttled.body.error).toBe('RATE_LIMITED');
  });
});
