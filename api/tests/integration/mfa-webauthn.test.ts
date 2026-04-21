import request from 'supertest';
import { generate as otpGenerate } from 'otplib';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { prisma } from '@/config/prisma';
import { makeTestAuthenticator } from '@tests/integration/helpers/webauthn-authenticator';

// Slice P7b — WebAuthn integration tests. Uses the in-repo test
// authenticator simulator (`helpers/webauthn-authenticator.ts`) so the
// end-to-end ceremony runs without any real platform credential.
//
// The API's `WEBAUTHN_RP_ID` + `WEBAUTHN_ORIGIN` are pinned to
// `localhost` / `http://localhost:3011` in `api/.env.test`; the
// simulator signs `clientDataJSON` with the same values.

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
// MUST match api/.env.test.
const RP_ID = 'localhost';
const ORIGIN = 'http://localhost:3011';

async function signup(
  email: string,
  password = DEFAULT_PASSWORD,
): Promise<{
  userId: string;
  accessToken: string;
}> {
  const app = await getTestApp();
  const res = await request(app)
    .post('/api/auth/signup')
    .send({ email, password, displayName: 'Webauthn Tester' });
  if (res.status !== 201) {
    throw new Error(
      `signup failed: ${res.status} ${JSON.stringify(res.body)}`,
    );
  }
  return {
    userId: res.body.user.id as string,
    accessToken: res.body.accessToken as string,
  };
}

interface RegisterResult {
  credentialId: string;
  backupCodes?: string[];
  authenticator: ReturnType<typeof makeTestAuthenticator>;
}

async function registerPasskey(accessToken: string): Promise<RegisterResult> {
  const app = await getTestApp();
  const startRes = await request(app)
    .post('/api/me/mfa/webauthn/register/options')
    .set('authorization', `Bearer ${accessToken}`)
    .send({});
  if (startRes.status !== 200) {
    throw new Error(
      `register start failed: ${startRes.status} ${JSON.stringify(startRes.body)}`,
    );
  }
  const options = startRes.body.options;
  const pendingToken = startRes.body.pendingToken as string;
  const authenticator = makeTestAuthenticator();
  const attestationResponse = authenticator.createRegistrationResponse({
    challenge: options.challenge,
    origin: ORIGIN,
    rpId: RP_ID,
  });
  const verifyRes = await request(app)
    .post('/api/me/mfa/webauthn/register/verify')
    .set('authorization', `Bearer ${accessToken}`)
    .send({ pendingToken, attestationResponse, label: 'Test Passkey' });
  if (verifyRes.status !== 200) {
    throw new Error(
      `register verify failed: ${verifyRes.status} ${JSON.stringify(verifyRes.body)}`,
    );
  }
  return {
    credentialId: verifyRes.body.credentialId as string,
    backupCodes: verifyRes.body.backupCodes as string[] | undefined,
    authenticator,
  };
}

describe('MFA WebAuthn (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('registration', () => {
    it('happy path: start → verify with simulated authenticator → credential persisted, mfaEnabled=true, backup codes returned', async () => {
      const { userId, accessToken } = await signup('wa-happy@example.local');
      const res = await registerPasskey(accessToken);

      expect(typeof res.credentialId).toBe('string');
      expect(Array.isArray(res.backupCodes)).toBe(true);
      expect(res.backupCodes).toHaveLength(10);

      const postRow = await prisma.user.findUnique({ where: { id: userId } });
      expect(postRow!.mfaEnabled).toBe(true);
      expect(postRow!.mfaBackupCodes).toHaveLength(10);

      const cred = await prisma.mfaCredential.findFirst({
        where: { userId, kind: 'WEBAUTHN' },
      });
      expect(cred).not.toBeNull();
      expect(cred!.kind).toBe('WEBAUTHN');
      expect(cred!.label).toBe('Test Passkey');
      expect(cred!.credentialId).not.toBeNull();
      expect(cred!.publicKey).not.toBeNull();
    });

    it('second registration on the same user creates a new credential but NOT new backup codes', async () => {
      const { userId, accessToken } = await signup('wa-second@example.local');
      const first = await registerPasskey(accessToken);
      expect(first.backupCodes).toHaveLength(10);

      const app = await getTestApp();
      const startRes = await request(app)
        .post('/api/me/mfa/webauthn/register/options')
        .set('authorization', `Bearer ${accessToken}`)
        .send({});
      expect(startRes.status).toBe(200);
      const second = makeTestAuthenticator();
      const resp = second.createRegistrationResponse({
        challenge: startRes.body.options.challenge,
        origin: ORIGIN,
        rpId: RP_ID,
      });
      const verifyRes = await request(app)
        .post('/api/me/mfa/webauthn/register/verify')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          pendingToken: startRes.body.pendingToken,
          attestationResponse: resp,
          label: 'Second Passkey',
        });
      expect(verifyRes.status).toBe(200);
      // No new backup codes on the second enrolment.
      expect(verifyRes.body.backupCodes).toBeUndefined();

      const creds = await prisma.mfaCredential.findMany({
        where: { userId, kind: 'WEBAUTHN' },
      });
      expect(creds).toHaveLength(2);
    });

    it('duplicate credential id on registration → 409', async () => {
      const { accessToken } = await signup('wa-dup@example.local');
      const first = await registerPasskey(accessToken);

      const app = await getTestApp();
      const startRes = await request(app)
        .post('/api/me/mfa/webauthn/register/options')
        .set('authorization', `Bearer ${accessToken}`)
        .send({});
      expect(startRes.status).toBe(200);
      // Feed the SAME authenticator back — same credentialId.
      const resp = first.authenticator.createRegistrationResponse({
        challenge: startRes.body.options.challenge,
        origin: ORIGIN,
        rpId: RP_ID,
      });
      const verifyRes = await request(app)
        .post('/api/me/mfa/webauthn/register/verify')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          pendingToken: startRes.body.pendingToken,
          attestationResponse: resp,
        });
      expect(verifyRes.status).toBe(409);
    });

    it('tampered pending token → 401', async () => {
      const { accessToken } = await signup('wa-badtok@example.local');
      const app = await getTestApp();
      const startRes = await request(app)
        .post('/api/me/mfa/webauthn/register/options')
        .set('authorization', `Bearer ${accessToken}`)
        .send({});
      expect(startRes.status).toBe(200);
      const auth = makeTestAuthenticator();
      const resp = auth.createRegistrationResponse({
        challenge: startRes.body.options.challenge,
        origin: ORIGIN,
        rpId: RP_ID,
      });
      const verifyRes = await request(app)
        .post('/api/me/mfa/webauthn/register/verify')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          pendingToken: 'not.a.real.jwt',
          attestationResponse: resp,
        });
      expect(verifyRes.status).toBe(401);
    });
  });

  describe('GET /api/me/mfa/webauthn', () => {
    it('returns both registered credentials with label + transports', async () => {
      const { accessToken } = await signup('wa-list@example.local');
      await registerPasskey(accessToken);
      // Register a second one:
      const app = await getTestApp();
      const startRes = await request(app)
        .post('/api/me/mfa/webauthn/register/options')
        .set('authorization', `Bearer ${accessToken}`)
        .send({});
      const second = makeTestAuthenticator();
      await request(app)
        .post('/api/me/mfa/webauthn/register/verify')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          pendingToken: startRes.body.pendingToken,
          attestationResponse: second.createRegistrationResponse({
            challenge: startRes.body.options.challenge,
            origin: ORIGIN,
            rpId: RP_ID,
          }),
          label: 'Work Phone',
        });

      const listRes = await request(app)
        .get('/api/me/mfa/webauthn')
        .set('authorization', `Bearer ${accessToken}`);
      expect(listRes.status).toBe(200);
      expect(Array.isArray(listRes.body)).toBe(true);
      expect(listRes.body.length).toBe(2);
      expect(listRes.body[0]).toHaveProperty('credentialId');
      expect(listRes.body[0]).toHaveProperty('transports');
      expect(listRes.body[0]).toHaveProperty('label');
    });

    it('GET /api/me/mfa reports webauthnCount > 0 after registration', async () => {
      const { accessToken } = await signup('wa-count@example.local');
      await registerPasskey(accessToken);
      const app = await getTestApp();
      const res = await request(app)
        .get('/api/me/mfa')
        .set('authorization', `Bearer ${accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.webauthnCount).toBe(1);
    });
  });

  describe('DELETE /api/me/mfa/webauthn/:credentialId', () => {
    it('requires current password; 401 on wrong password', async () => {
      const { accessToken } = await signup('wa-delpw@example.local');
      await registerPasskey(accessToken);
      const app = await getTestApp();
      const listRes = await request(app)
        .get('/api/me/mfa/webauthn')
        .set('authorization', `Bearer ${accessToken}`);
      const credRowId = listRes.body[0].id as string;

      const res = await request(app)
        .delete(`/api/me/mfa/webauthn/${credRowId}`)
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: 'wrong-password-1234' });
      expect(res.status).toBe(401);
    });

    it('with correct password deletes the credential', async () => {
      const { userId, accessToken } = await signup('wa-del@example.local');
      await registerPasskey(accessToken);
      const app = await getTestApp();
      const listRes = await request(app)
        .get('/api/me/mfa/webauthn')
        .set('authorization', `Bearer ${accessToken}`);
      const credRowId = listRes.body[0].id as string;

      const res = await request(app)
        .delete(`/api/me/mfa/webauthn/${credRowId}`)
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: DEFAULT_PASSWORD });
      expect(res.status).toBe(204);

      const remaining = await prisma.mfaCredential.count({
        where: { userId, kind: 'WEBAUTHN' },
      });
      expect(remaining).toBe(0);
    });

    it('deleting the last credential → mfaEnabled=false, backup codes cleared', async () => {
      const { userId, accessToken } = await signup('wa-last@example.local');
      await registerPasskey(accessToken);
      const app = await getTestApp();
      const listRes = await request(app)
        .get('/api/me/mfa/webauthn')
        .set('authorization', `Bearer ${accessToken}`);
      const credRowId = listRes.body[0].id as string;
      await request(app)
        .delete(`/api/me/mfa/webauthn/${credRowId}`)
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: DEFAULT_PASSWORD });

      const user = await prisma.user.findUnique({ where: { id: userId } });
      expect(user!.mfaEnabled).toBe(false);
      expect(user!.mfaBackupCodes).toEqual([]);
    });

    it('deleting the last WebAuthn credential while TOTP still active → mfaEnabled=true, backup codes retained', async () => {
      // Enrol TOTP first so backup codes exist; then add + remove a passkey.
      const { userId, accessToken } = await signup('wa-totpkept@example.local');
      const app = await getTestApp();
      const totpStart = await request(app)
        .post('/api/me/mfa/totp/enrol')
        .set('authorization', `Bearer ${accessToken}`)
        .send({});
      expect(totpStart.status).toBe(200);
      const totpCode = await otpGenerate({ secret: totpStart.body.secret });
      const totpConfirm = await request(app)
        .post('/api/me/mfa/totp/verify')
        .set('authorization', `Bearer ${accessToken}`)
        .send({
          pendingToken: totpStart.body.pendingEnrolmentToken,
          code: totpCode,
        });
      expect(totpConfirm.status).toBe(200);

      // Passkey reg doesn't re-issue backup codes (TOTP already minted them).
      const pk = await registerPasskey(accessToken);
      expect(pk.backupCodes).toBeUndefined();

      const listRes = await request(app)
        .get('/api/me/mfa/webauthn')
        .set('authorization', `Bearer ${accessToken}`);
      const credRowId = listRes.body[0].id as string;

      await request(app)
        .delete(`/api/me/mfa/webauthn/${credRowId}`)
        .set('authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: DEFAULT_PASSWORD });

      const user = await prisma.user.findUnique({ where: { id: userId } });
      expect(user!.mfaEnabled).toBe(true); // TOTP still active
      expect(user!.mfaBackupCodes.length).toBe(10); // codes retained
    });
  });

  describe('login flow', () => {
    it('availableMethods contains "webauthn" once a credential is registered', async () => {
      const { accessToken } = await signup('wa-methods@example.local');
      await registerPasskey(accessToken);

      const app = await getTestApp();
      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ email: 'wa-methods@example.local', password: DEFAULT_PASSWORD });
      expect(loginRes.status).toBe(200);
      expect(loginRes.body.mfaPending).toBe(true);
      expect(loginRes.body.availableMethods).toEqual(
        expect.arrayContaining(['webauthn', 'backup']),
      );
    });

    it('login options + verify → tokens issued + Session row created', async () => {
      const { userId, accessToken } = await signup('wa-login@example.local');
      const { authenticator } = await registerPasskey(accessToken);

      const app = await getTestApp();
      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ email: 'wa-login@example.local', password: DEFAULT_PASSWORD });
      expect(loginRes.status).toBe(200);
      const mfaToken = loginRes.body.mfaToken as string;

      const optsRes = await request(app)
        .post('/api/auth/login/mfa/webauthn/options')
        .send({ mfaToken });
      expect(optsRes.status).toBe(200);
      const challenge = optsRes.body.options.challenge as string;
      const challengeToken = optsRes.body.challengeToken as string;

      const assertion = authenticator.createAssertionResponse({
        challenge,
        origin: ORIGIN,
        rpId: RP_ID,
      });
      const verifyRes = await request(app)
        .post('/api/auth/login/mfa/webauthn/verify')
        .send({ mfaToken, challengeToken, assertionResponse: assertion });
      expect(verifyRes.status).toBe(200);
      expect(typeof verifyRes.body.accessToken).toBe('string');
      expect(typeof verifyRes.body.refreshToken).toBe('string');
      expect(verifyRes.body.user.id).toBe(userId);

      const sessions = await prisma.session.findMany({ where: { userId } });
      expect(sessions.length).toBeGreaterThanOrEqual(2);

      // Stored signCount should have been bumped.
      const cred = await prisma.mfaCredential.findFirst({
        where: { userId, kind: 'WEBAUTHN' },
      });
      expect((cred!.signCount ?? 0)).toBeGreaterThan(0);
      expect(cred!.lastUsedAt).not.toBeNull();
    });

    it('sign-count regression → 401 and stored counter is NOT updated', async () => {
      const { userId, accessToken } = await signup('wa-clone@example.local');
      const { authenticator } = await registerPasskey(accessToken);

      const app = await getTestApp();
      // 1) Legit login #1 — raises stored counter to 1.
      const loginRes1 = await request(app)
        .post('/api/auth/login')
        .send({ email: 'wa-clone@example.local', password: DEFAULT_PASSWORD });
      const mfaToken1 = loginRes1.body.mfaToken as string;
      const opts1 = await request(app)
        .post('/api/auth/login/mfa/webauthn/options')
        .send({ mfaToken: mfaToken1 });
      const assertion1 = authenticator.createAssertionResponse({
        challenge: opts1.body.options.challenge,
        origin: ORIGIN,
        rpId: RP_ID,
      });
      const v1 = await request(app)
        .post('/api/auth/login/mfa/webauthn/verify')
        .send({
          mfaToken: mfaToken1,
          challengeToken: opts1.body.challengeToken,
          assertionResponse: assertion1,
        });
      expect(v1.status).toBe(200);

      const credAfter1 = await prisma.mfaCredential.findFirst({
        where: { userId, kind: 'WEBAUTHN' },
      });
      const countAfter1 = credAfter1!.signCount ?? 0;
      expect(countAfter1).toBeGreaterThan(0);

      // 2) Now force a regression: produce an assertion with an explicitly
      //    stale counter (< stored). WebAuthn spec: this MUST be rejected.
      const loginRes2 = await request(app)
        .post('/api/auth/login')
        .send({ email: 'wa-clone@example.local', password: DEFAULT_PASSWORD });
      const mfaToken2 = loginRes2.body.mfaToken as string;
      const opts2 = await request(app)
        .post('/api/auth/login/mfa/webauthn/options')
        .send({ mfaToken: mfaToken2 });
      const assertion2 = authenticator.createAssertionResponse({
        challenge: opts2.body.options.challenge,
        origin: ORIGIN,
        rpId: RP_ID,
        signCountOverride: 0, // below stored
      });
      const v2 = await request(app)
        .post('/api/auth/login/mfa/webauthn/verify')
        .send({
          mfaToken: mfaToken2,
          challengeToken: opts2.body.challengeToken,
          assertionResponse: assertion2,
        });
      expect(v2.status).toBe(401);

      const credAfter2 = await prisma.mfaCredential.findFirst({
        where: { userId, kind: 'WEBAUTHN' },
      });
      // Stored counter unchanged — we didn't accept the regressed value.
      expect(credAfter2!.signCount).toBe(countAfter1);
    });
  });

  describe('auth', () => {
    it('401 when unauthenticated on register options', async () => {
      const app = await getTestApp();
      const res = await request(app)
        .post('/api/me/mfa/webauthn/register/options')
        .send({});
      expect(res.status).toBe(401);
    });
  });
});
