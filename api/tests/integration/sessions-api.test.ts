import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { prisma } from '@/config/prisma';

// Mock the transcode queue + object store so mounting the app doesn't
// open live BullMQ / SeaweedFS connections (same pattern as the other
// integration suites — the sessions code path doesn't actually touch
// either, but `createApp()` registers the queue wiring at import time).
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

interface SignupResult {
  userId: string;
  accessToken: string;
  refreshToken: string;
}

async function signup(
  email: string,
  userAgent: string = 'Mozilla/5.0 (Linux; Android 14; Pixel 7)',
): Promise<SignupResult> {
  const app = await getTestApp();
  const res = await request(app)
    .post('/api/auth/signup')
    .set('user-agent', userAgent)
    .send({ email, password: DEFAULT_PASSWORD, displayName: 'Test User' });
  if (res.status !== 201) {
    throw new Error(`signup failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return {
    userId: res.body.user.id as string,
    accessToken: res.body.accessToken as string,
    refreshToken: res.body.refreshToken as string,
  };
}

async function login(
  email: string,
  userAgent: string,
  password: string = DEFAULT_PASSWORD,
): Promise<SignupResult> {
  const app = await getTestApp();
  const res = await request(app)
    .post('/api/auth/login')
    .set('user-agent', userAgent)
    .send({ email, password });
  if (res.status !== 200) {
    throw new Error(`login failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return {
    userId: res.body.user.id as string,
    accessToken: res.body.accessToken as string,
    refreshToken: res.body.refreshToken as string,
  };
}

describe('Sessions API (integration) — Slice P6', () => {
  beforeEach(async () => {
    await resetDb();
    // rl:* covers the per-IP rate limiters; refresh-revoked:* covers the
    // stale jti revocation set between tests.
    await resetRedisKeys(['rl:*', 'bull:*', 'refresh-revoked:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('signup creates a Session row', () => {
    it('persists deviceLabel parsed from User-Agent', async () => {
      const { userId } = await signup(
        'android-user@example.local',
        'Mozilla/5.0 (Linux; Android 14; Pixel 7)',
      );

      const rows = await prisma.session.findMany({ where: { userId } });
      expect(rows).toHaveLength(1);
      expect(rows[0].deviceLabel).toBe('Android');
      expect(rows[0].revokedAt).toBeNull();
      expect(rows[0].ipHash).toMatch(/^[0-9a-f]{32}$/);
    });

    it('handles missing User-Agent gracefully', async () => {
      const app = await getTestApp();
      const res = await request(app)
        .post('/api/auth/signup')
        // No user-agent header set.
        .unset('User-Agent')
        .send({
          email: 'no-ua@example.local',
          password: DEFAULT_PASSWORD,
          displayName: 'U',
        });
      // Supertest injects its own UA when none is provided — some test
      // runners keep the default, so we just check that the row lands
      // without erroring. The deviceLabel may be 'Linux' (supertest
      // default UA contains "node") or a 60-char slice.
      expect(res.status).toBe(201);
      const rows = await prisma.session.findMany({
        where: { userId: res.body.user.id },
      });
      expect(rows).toHaveLength(1);
    });
  });

  describe('GET /api/me/sessions', () => {
    it('returns 1 session after signup, 2 after a second login', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('multi-device@example.local');
      const firstList = await request(app)
        .get('/api/me/sessions')
        .set('authorization', `Bearer ${accessToken}`);
      expect(firstList.status).toBe(200);
      expect(firstList.body).toHaveLength(1);
      expect(firstList.body[0].current).toBe(true);

      // Login a second time (different UA) — should NOT revoke the
      // first session.
      const second = await login(
        'multi-device@example.local',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15)',
      );
      const secondList = await request(app)
        .get('/api/me/sessions')
        .set('authorization', `Bearer ${second.accessToken}`);
      expect(secondList.status).toBe(200);
      expect(secondList.body).toHaveLength(2);
      // Exactly one row has current: true (the one matching the caller's sid).
      const current = secondList.body.filter(
        (r: { current: boolean }) => r.current,
      );
      expect(current).toHaveLength(1);
      // Device labels reflect the distinct UAs.
      const labels = secondList.body.map(
        (r: { deviceLabel: string | null }) => r.deviceLabel,
      );
      expect(labels).toEqual(expect.arrayContaining(['Android', 'macOS']));
    });

    it('401 when unauthenticated', async () => {
      const app = await getTestApp();
      const res = await request(app).get('/api/me/sessions');
      expect(res.status).toBe(401);
    });

    it('returns empty list after revoking both sessions', async () => {
      const app = await getTestApp();
      await signup('empty-after@example.local');
      const second = await login(
        'empty-after@example.local',
        'Mozilla/5.0 (Macintosh)',
      );

      // Revoke everything via the "all for user" seam (change password,
      // which bumps passwordChangedAt + revokes all sessions).
      const changeRes = await request(app)
        .post('/api/me/password')
        .set('authorization', `Bearer ${second.accessToken}`)
        .send({
          currentPassword: DEFAULT_PASSWORD,
          newPassword: 'BrandNewPass5678',
        });
      expect(changeRes.status).toBe(204);

      // The access token is still valid for 15 minutes so the listing
      // endpoint itself still authorises — the LIST should be empty
      // because every Session row is now revoked.
      const listRes = await request(app)
        .get('/api/me/sessions')
        .set('authorization', `Bearer ${second.accessToken}`);
      expect(listRes.status).toBe(200);
      expect(listRes.body).toHaveLength(0);
    });
  });

  describe('DELETE /api/me/sessions/:id', () => {
    it('revoke first session: its refresh token 401s on rotation', async () => {
      const app = await getTestApp();
      const first = await signup('revoke-one-b@example.local');
      const second = await login(
        'revoke-one-b@example.local',
        'Mozilla/5.0 (iPhone)',
      );

      // Find first session's id (the non-current one from second's POV).
      const listRes = await request(app)
        .get('/api/me/sessions')
        .set('authorization', `Bearer ${second.accessToken}`);
      const firstSessionId = (listRes.body as Array<{ id: string; current: boolean }>)
        .find((r) => !r.current)!.id;

      // Delete it.
      const delRes = await request(app)
        .delete(`/api/me/sessions/${firstSessionId}`)
        .set('authorization', `Bearer ${second.accessToken}`);
      expect(delRes.status).toBe(204);

      // DB row is marked revoked.
      const row = await prisma.session.findUnique({ where: { id: firstSessionId } });
      expect(row!.revokedAt).toBeInstanceOf(Date);

      // First session's refresh token no longer works.
      const refreshRes = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: first.refreshToken });
      expect(refreshRes.status).toBe(401);
    });

    it('404 when revoking a session that belongs to another user', async () => {
      const app = await getTestApp();
      const alice = await signup('alice-xss@example.local');
      const bob = await signup('bob-xss@example.local');

      // Alice tries to revoke Bob's session by id.
      const bobRow = await prisma.session.findFirst({
        where: { userId: bob.userId },
      });
      const res = await request(app)
        .delete(`/api/me/sessions/${bobRow!.id}`)
        .set('authorization', `Bearer ${alice.accessToken}`);
      expect(res.status).toBe(404);
      // Bob's session is untouched.
      const stillActive = await prisma.session.findUnique({
        where: { id: bobRow!.id },
      });
      expect(stillActive!.revokedAt).toBeNull();
    });
  });

  describe('DELETE /api/me/sessions (sign out all others)', () => {
    it('revokes every other session, leaves current alive, still refreshes', async () => {
      const app = await getTestApp();
      await signup('all-others@example.local');
      const b = await login(
        'all-others@example.local',
        'Mozilla/5.0 (Macintosh)',
      );
      await login(
        'all-others@example.local',
        'Mozilla/5.0 (Windows NT 10.0)',
      );

      // Sanity: 3 sessions now.
      const beforeList = await request(app)
        .get('/api/me/sessions')
        .set('authorization', `Bearer ${b.accessToken}`);
      expect(beforeList.body).toHaveLength(3);

      const revokeAllRes = await request(app)
        .delete('/api/me/sessions')
        .set('authorization', `Bearer ${b.accessToken}`);
      expect(revokeAllRes.status).toBe(204);

      // Caller's own session survives.
      const afterList = await request(app)
        .get('/api/me/sessions')
        .set('authorization', `Bearer ${b.accessToken}`);
      expect(afterList.body).toHaveLength(1);
      expect(afterList.body[0].current).toBe(true);

      // Caller's refresh token still works.
      const refreshRes = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: b.refreshToken });
      expect(refreshRes.status).toBe(200);
    });
  });

  describe('POST /api/auth/logout', () => {
    it('revokes the session row and the refresh jti', async () => {
      const app = await getTestApp();
      const { userId, refreshToken } = await signup('logout@example.local');

      const logoutRes = await request(app)
        .post('/api/auth/logout')
        .send({ refreshToken });
      expect(logoutRes.status).toBe(204);

      const rows = await prisma.session.findMany({ where: { userId } });
      expect(rows).toHaveLength(1);
      expect(rows[0].revokedAt).toBeInstanceOf(Date);

      // Subsequent refresh with that token fails.
      const refreshRes = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken });
      expect(refreshRes.status).toBe(401);
    });

    it('is idempotent even on a bogus token (204)', async () => {
      const app = await getTestApp();
      const res = await request(app)
        .post('/api/auth/logout')
        .send({ refreshToken: 'definitely-not-a-real-jwt' });
      expect(res.status).toBe(204);
    });
  });

  describe('password change revokes all sessions', () => {
    it('GET /api/me/sessions returns empty immediately after change', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('pw-revoke@example.local');
      await login('pw-revoke@example.local', 'Mozilla/5.0 (Macintosh)');

      const changeRes = await request(app)
        .post('/api/me/password')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          currentPassword: DEFAULT_PASSWORD,
          newPassword: 'BrandNewPass5678',
        });
      expect(changeRes.status).toBe(204);

      const listRes = await request(app)
        .get('/api/me/sessions')
        .set('authorization', `Bearer ${accessToken}`);
      expect(listRes.status).toBe(200);
      expect(listRes.body).toHaveLength(0);
    });
  });

  describe('account deletion revokes all sessions', () => {
    it('every Session row for the deleted user is revoked', async () => {
      const app = await getTestApp();
      const { userId, accessToken } = await signup('delete-revoke@example.local');
      await login('delete-revoke@example.local', 'Mozilla/5.0 (Macintosh)');

      // Sanity: 2 active sessions.
      let active = await prisma.session.findMany({
        where: { userId, revokedAt: null },
      });
      expect(active).toHaveLength(2);

      const delRes = await request(app)
        .delete('/api/me')
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: DEFAULT_PASSWORD });
      expect(delRes.status).toBe(204);

      active = await prisma.session.findMany({
        where: { userId, revokedAt: null },
      });
      expect(active).toHaveLength(0);
    });
  });
});
