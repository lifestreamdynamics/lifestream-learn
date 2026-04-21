import request from 'supertest';
import { generate as otpGenerate } from 'otplib';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { prisma } from '@/config/prisma';
import { decryptTotpSecret } from '@/services/mfa/crypto';

// Slice P7a — MFA TOTP integration tests. Mirrors the pattern used in
// password-change.test.ts / account-deletion.test.ts: mock the BullMQ
// + S3 surfaces so mounting the app doesn't open sockets, then drive
// the full flow through supertest.

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
    .send({ email, password, displayName: 'MFA Tester' });
  if (res.status !== 201) {
    throw new Error(`signup failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return {
    userId: res.body.user.id as string,
    accessToken: res.body.accessToken as string,
    refreshToken: res.body.refreshToken as string,
  };
}

/**
 * Full enrol flow: start → confirm with a fresh TOTP code. Returns the
 * secret + backup codes so tests can exercise the verify path without
 * re-running the setup boilerplate every time.
 */
async function enrolTotp(
  accessToken: string,
): Promise<{ secret: string; backupCodes: string[] }> {
  const app = await getTestApp();
  const startRes = await request(app)
    .post('/api/me/mfa/totp/enrol')
    .set('authorization', `Bearer ${accessToken}`)
    .send({});
  if (startRes.status !== 200) {
    throw new Error(`start failed: ${startRes.status} ${JSON.stringify(startRes.body)}`);
  }
  const secret = startRes.body.secret as string;
  const pendingToken = startRes.body.pendingEnrolmentToken as string;
  const code = await otpGenerate({ secret });
  const confirmRes = await request(app)
    .post('/api/me/mfa/totp/verify')
    .set('authorization', `Bearer ${accessToken}`)
    .send({ pendingToken, code });
  if (confirmRes.status !== 200) {
    throw new Error(`confirm failed: ${confirmRes.status} ${JSON.stringify(confirmRes.body)}`);
  }
  return { secret, backupCodes: confirmRes.body.backupCodes as string[] };
}

describe('MFA TOTP (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('enrolment', () => {
    it('happy path: start → confirm → mfaEnabled=true → backup codes returned once', async () => {
      const app = await getTestApp();
      const { userId, accessToken } = await signup('enrol-happy@example.local');

      const startRes = await request(app)
        .post('/api/me/mfa/totp/enrol')
        .set('authorization', `Bearer ${accessToken}`)
        .send({});
      expect(startRes.status).toBe(200);
      expect(typeof startRes.body.secret).toBe('string');
      expect(startRes.body.qrDataUrl as string).toMatch(/^data:image\/png;base64,/);
      expect(typeof startRes.body.pendingEnrolmentToken).toBe('string');

      // DB is unchanged at this point — the secret isn't persisted until confirm.
      const preRow = await prisma.user.findUnique({ where: { id: userId } });
      expect(preRow!.mfaEnabled).toBe(false);
      const preCount = await prisma.mfaCredential.count({ where: { userId } });
      expect(preCount).toBe(0);

      const secret = startRes.body.secret as string;
      const code = await otpGenerate({ secret });
      const confirmRes = await request(app)
        .post('/api/me/mfa/totp/verify')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          pendingToken: startRes.body.pendingEnrolmentToken,
          code,
          label: 'Integration Test Device',
        });
      expect(confirmRes.status).toBe(200);
      expect(Array.isArray(confirmRes.body.backupCodes)).toBe(true);
      expect(confirmRes.body.backupCodes).toHaveLength(10);

      // DB reflects the enrolment.
      const postRow = await prisma.user.findUnique({ where: { id: userId } });
      expect(postRow!.mfaEnabled).toBe(true);
      expect(postRow!.mfaBackupCodes).toHaveLength(10);
      // Codes stored as bcrypt hashes, never plaintext.
      for (const h of postRow!.mfaBackupCodes) {
        expect(h).toMatch(/^\$2[aby]\$/);
      }
      const cred = await prisma.mfaCredential.findFirst({ where: { userId } });
      expect(cred).not.toBeNull();
      expect(cred!.kind).toBe('TOTP');
      expect(cred!.label).toBe('Integration Test Device');
      // Encrypted at rest — the stored value is NOT the base32 secret.
      expect(cred!.totpSecretEncrypted).not.toBe(secret);
      expect(decryptTotpSecret(cred!.totpSecretEncrypted!)).toBe(secret);
    });

    it('confirm with the wrong 6-digit code returns 401', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('enrol-wrong@example.local');
      const startRes = await request(app)
        .post('/api/me/mfa/totp/enrol')
        .set('authorization', `Bearer ${accessToken}`)
        .send({});
      expect(startRes.status).toBe(200);

      const confirmRes = await request(app)
        .post('/api/me/mfa/totp/verify')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          pendingToken: startRes.body.pendingEnrolmentToken,
          code: '000000',
        });
      expect(confirmRes.status).toBe(401);
    });

    it('confirm with a tampered / bogus pending token returns 401', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('enrol-badtoken@example.local');
      const confirmRes = await request(app)
        .post('/api/me/mfa/totp/verify')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          pendingToken: 'not.a.real.jwt',
          code: '123456',
        });
      expect(confirmRes.status).toBe(401);
    });

    it('409 when TOTP is already enrolled and the user starts enrolment again', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('enrol-twice@example.local');
      await enrolTotp(accessToken);
      const startAgain = await request(app)
        .post('/api/me/mfa/totp/enrol')
        .set('authorization', `Bearer ${accessToken}`)
        .send({});
      expect(startAgain.status).toBe(409);
    });

    it('401 when caller is unauthenticated', async () => {
      const app = await getTestApp();
      const res = await request(app).post('/api/me/mfa/totp/enrol').send({});
      expect(res.status).toBe(401);
    });
  });

  describe('login with MFA gate', () => {
    it('user without MFA still logs in normally', async () => {
      const app = await getTestApp();
      await signup('noop-mfa@example.local');
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'noop-mfa@example.local', password: DEFAULT_PASSWORD });
      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.mfaPending).toBeUndefined();
    });

    it('user WITH MFA receives mfaPending + mfaToken (no tokens)', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('mfa-on@example.local');
      await enrolTotp(accessToken);

      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'mfa-on@example.local', password: DEFAULT_PASSWORD });
      expect(res.status).toBe(200);
      expect(res.body.mfaPending).toBe(true);
      expect(typeof res.body.mfaToken).toBe('string');
      expect(res.body.accessToken).toBeUndefined();
      expect(res.body.refreshToken).toBeUndefined();
      expect(res.body.availableMethods).toEqual(
        expect.arrayContaining(['totp', 'backup']),
      );
    });

    it('POST /api/auth/login/mfa/totp with the current code mints tokens + Session', async () => {
      const app = await getTestApp();
      const { userId, accessToken } = await signup('mfa-finish@example.local');
      const { secret } = await enrolTotp(accessToken);

      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ email: 'mfa-finish@example.local', password: DEFAULT_PASSWORD });
      expect(loginRes.status).toBe(200);
      expect(loginRes.body.mfaPending).toBe(true);
      const mfaToken = loginRes.body.mfaToken as string;

      const code = await otpGenerate({ secret });
      const finishRes = await request(app)
        .post('/api/auth/login/mfa/totp')
        .send({ mfaToken, code });
      expect(finishRes.status).toBe(200);
      expect(typeof finishRes.body.accessToken).toBe('string');
      expect(typeof finishRes.body.refreshToken).toBe('string');
      expect(finishRes.body.user.id).toBe(userId);

      // Session row exists for the refresh jti the client just received.
      const sessions = await prisma.session.findMany({ where: { userId } });
      // One session from the original signup, one from the MFA-finish login.
      expect(sessions.length).toBeGreaterThanOrEqual(2);
    });

    it('POST /api/auth/login/mfa/totp with the wrong code returns 401', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('mfa-bad@example.local');
      await enrolTotp(accessToken);

      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ email: 'mfa-bad@example.local', password: DEFAULT_PASSWORD });
      const mfaToken = loginRes.body.mfaToken as string;

      const res = await request(app)
        .post('/api/auth/login/mfa/totp')
        .send({ mfaToken, code: '000000' });
      expect(res.status).toBe(401);
    });

    it('POST /api/auth/login/mfa/backup with a valid code issues tokens and burns the code', async () => {
      const app = await getTestApp();
      const { userId, accessToken } = await signup('mfa-backup@example.local');
      const { backupCodes } = await enrolTotp(accessToken);

      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ email: 'mfa-backup@example.local', password: DEFAULT_PASSWORD });
      const mfaToken = loginRes.body.mfaToken as string;

      const codeUsed = backupCodes[0]!;
      const useRes = await request(app)
        .post('/api/auth/login/mfa/backup')
        .send({ mfaToken, code: codeUsed });
      expect(useRes.status).toBe(200);
      expect(typeof useRes.body.accessToken).toBe('string');

      // DB: one fewer backup code hash remains.
      const row = await prisma.user.findUnique({ where: { id: userId } });
      expect(row!.mfaBackupCodes).toHaveLength(9);

      // Reusing the same code (with a fresh login round) fails.
      const login2 = await request(app)
        .post('/api/auth/login')
        .send({ email: 'mfa-backup@example.local', password: DEFAULT_PASSWORD });
      const mfaToken2 = login2.body.mfaToken as string;
      const replay = await request(app)
        .post('/api/auth/login/mfa/backup')
        .send({ mfaToken: mfaToken2, code: codeUsed });
      expect(replay.status).toBe(401);
    });

    it('refresh with the post-mfaPending login attempt fails (no refresh token was issued)', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('mfa-no-refresh@example.local');
      await enrolTotp(accessToken);
      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ email: 'mfa-no-refresh@example.local', password: DEFAULT_PASSWORD });
      expect(loginRes.body.mfaPending).toBe(true);
      // There is no refreshToken to attempt with — the client can only
      // complete via /login/mfa/totp or /login/mfa/backup.
      expect(loginRes.body.refreshToken).toBeUndefined();
    });
  });

  describe('disable', () => {
    it('requires current password AND a current 6-digit code; deletes the credential', async () => {
      const app = await getTestApp();
      const { userId, accessToken } = await signup('mfa-disable@example.local');
      const { secret } = await enrolTotp(accessToken);
      const code = await otpGenerate({ secret });

      const res = await request(app)
        .delete('/api/me/mfa/totp')
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: DEFAULT_PASSWORD, code });
      expect(res.status).toBe(204);

      const row = await prisma.user.findUnique({ where: { id: userId } });
      expect(row!.mfaEnabled).toBe(false);
      expect(row!.mfaBackupCodes).toEqual([]);
      const remainingCreds = await prisma.mfaCredential.count({ where: { userId } });
      expect(remainingCreds).toBe(0);
    });

    it('401 with wrong password', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('mfa-dis-wrongpw@example.local');
      const { secret } = await enrolTotp(accessToken);
      const code = await otpGenerate({ secret });
      const res = await request(app)
        .delete('/api/me/mfa/totp')
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: 'not-the-pw-1234', code });
      expect(res.status).toBe(401);
    });

    it('401 with wrong TOTP code', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('mfa-dis-wrongcode@example.local');
      await enrolTotp(accessToken);
      const res = await request(app)
        .delete('/api/me/mfa/totp')
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: DEFAULT_PASSWORD, code: '000000' });
      expect(res.status).toBe(401);
    });

    it('after disable, next login skips the MFA gate entirely', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('mfa-post-disable@example.local');
      const { secret } = await enrolTotp(accessToken);
      const disableCode = await otpGenerate({ secret });
      const disRes = await request(app)
        .delete('/api/me/mfa/totp')
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: DEFAULT_PASSWORD, code: disableCode });
      expect(disRes.status).toBe(204);

      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'mfa-post-disable@example.local',
          password: DEFAULT_PASSWORD,
        });
      expect(loginRes.status).toBe(200);
      expect(loginRes.body.mfaPending).toBeUndefined();
      expect(typeof loginRes.body.accessToken).toBe('string');
    });
  });

  describe('interaction with password change (P5 cross-slice)', () => {
    it('changing password does NOT disable MFA', async () => {
      const app = await getTestApp();
      const { userId, accessToken } = await signup('mfa-pwchange@example.local');
      await enrolTotp(accessToken);

      const newPw = 'BrandNewPass5678';
      const changeRes = await request(app)
        .post('/api/me/password')
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: DEFAULT_PASSWORD, newPassword: newPw });
      expect(changeRes.status).toBe(204);

      const row = await prisma.user.findUnique({ where: { id: userId } });
      // MFA survives the password change — this is the anti-downgrade
      // guarantee in the plan.
      expect(row!.mfaEnabled).toBe(true);
      const credCount = await prisma.mfaCredential.count({ where: { userId } });
      expect(credCount).toBe(1);

      // Next login still hits the MFA gate.
      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ email: 'mfa-pwchange@example.local', password: newPw });
      expect(loginRes.status).toBe(200);
      expect(loginRes.body.mfaPending).toBe(true);
    });
  });

  describe('GET /api/me/mfa', () => {
    it('reports totp: false before enrolment, totp: true + backupCodesRemaining=10 after', async () => {
      const app = await getTestApp();
      const { accessToken } = await signup('mfa-list@example.local');
      const before = await request(app)
        .get('/api/me/mfa')
        .set('authorization', `Bearer ${accessToken}`);
      expect(before.status).toBe(200);
      expect(before.body).toEqual({
        totp: false,
        webauthnCount: 0,
        hasBackupCodes: false,
        backupCodesRemaining: 0,
      });

      await enrolTotp(accessToken);
      const after = await request(app)
        .get('/api/me/mfa')
        .set('authorization', `Bearer ${accessToken}`);
      expect(after.status).toBe(200);
      expect(after.body.totp).toBe(true);
      expect(after.body.backupCodesRemaining).toBe(10);
      expect(after.body.hasBackupCodes).toBe(true);
    });
  });
});
