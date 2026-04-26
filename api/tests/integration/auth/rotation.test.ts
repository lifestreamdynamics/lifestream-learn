import jwt from 'jsonwebtoken';
import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { createUser } from '@tests/integration/helpers/factories';
import { env } from '@/config/env';
import { JWT_AUDIENCE } from '@/utils/jwt';

/**
 * Phase 8 / ADR 0007 — JWT dual-secret rotation, end-to-end through
 * the live HTTP surface.
 *
 * The unit suites under `tests/unit/utils/jwt.test.ts` and
 * `tests/unit/services/auth.service.test.ts` cover the verify-helper
 * logic in detail. This integration test confirms that two real
 * Express endpoints — `GET /api/auth/me` (access-token verify) and
 * `POST /api/auth/refresh` (refresh-token verify) — honour the
 * rotation env vars when forwarded HTTP requests carry tokens minted
 * under the *_PREVIOUS secret.
 */

type MutableEnv = {
  JWT_ACCESS_SECRET_PREVIOUS?: string;
  JWT_REFRESH_SECRET_PREVIOUS?: string;
};

const PREV_ACCESS = 'P'.repeat(48);
const PREV_REFRESH = 'Q'.repeat(48);

describe('JWT dual-secret rotation (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    // Wipe any leftover refresh-revocation entries so the refresh-flow
    // assertions don't bleed across tests.
    await resetRedisKeys(['rl:*', 'refresh-revoked:*']);
    // Default to "previous unset" — every test that needs the rotation
    // path opts in explicitly.
    (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = undefined;
    (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = undefined;
  });

  afterAll(async () => {
    (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = undefined;
    (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = undefined;
    await closeConnections();
  });

  describe('access tokens (GET /api/auth/me)', () => {
    it('accepts a token signed with JWT_ACCESS_SECRET_PREVIOUS when configured', async () => {
      (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = PREV_ACCESS;
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });

      // Sign with the *previous* secret directly — simulates a token
      // minted just before the rotation step that bumped JWT_ACCESS_SECRET
      // to a fresh value.
      const prevSigned = jwt.sign(
        { sub: user.id, role: user.role, email: user.email, type: 'access' },
        PREV_ACCESS,
        { audience: JWT_AUDIENCE, expiresIn: '15m' },
      );

      const res = await request(app)
        .get('/api/auth/me')
        .set('authorization', `Bearer ${prevSigned}`);
      expect(res.status).toBe(200);
      expect(res.body.id).toBe(user.id);
      expect(res.body.email).toBe(user.email);
    });

    it('rejects a previous-signed token (401) when JWT_ACCESS_SECRET_PREVIOUS is unset', async () => {
      // beforeEach already cleared previous; assert explicitly for clarity.
      (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = undefined;
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });

      const prevSigned = jwt.sign(
        { sub: user.id, role: user.role, email: user.email, type: 'access' },
        PREV_ACCESS,
        { audience: JWT_AUDIENCE, expiresIn: '15m' },
      );
      const res = await request(app)
        .get('/api/auth/me')
        .set('authorization', `Bearer ${prevSigned}`);
      expect(res.status).toBe(401);
    });

    it('rejects a garbage / unrecognised-secret signed token (401) regardless of rotation state', async () => {
      // With previous configured but garbage doesn't match either secret,
      // the request must still 401 — not silently succeed via fallback.
      (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = PREV_ACCESS;
      const app = await getTestApp();
      const user = await createUser({ role: 'LEARNER' });

      const garbage = jwt.sign(
        { sub: user.id, role: user.role, email: user.email, type: 'access' },
        'garbage-secret-that-is-also-long-enough-to-pass-zod-floor',
        { audience: JWT_AUDIENCE, expiresIn: '15m' },
      );
      const res = await request(app)
        .get('/api/auth/me')
        .set('authorization', `Bearer ${garbage}`);
      expect(res.status).toBe(401);
    });
  });

  describe('refresh tokens (POST /api/auth/refresh)', () => {
    it('accepts a refresh token signed with JWT_REFRESH_SECRET_PREVIOUS, and the new pair is signed with the CURRENT secret', async () => {
      (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = PREV_REFRESH;
      const app = await getTestApp();

      // Sign up a user the normal way so their Session row + jti
      // bookkeeping exist. The refresh handler calls
      // `sessions.rotate(userId, oldJti, newJti)` which requires the
      // old jti to point at a non-revoked Session row — we cannot
      // fabricate the jti.
      const signup = await request(app).post('/api/auth/signup').send({
        email: `rotation-${Date.now()}@example.local`,
        password: 'CorrectHorseBattery1',
        displayName: 'Rotation User',
      });
      expect(signup.status).toBe(201);
      const issuedRefresh = signup.body.refreshToken as string;

      // Decode the issued refresh token to harvest its claims (sub +
      // jti + iat). `jwt.decode` does NOT verify the signature — that's
      // exactly what we want: the claims represent a real Session row,
      // and we re-sign them with the PREVIOUS secret to simulate "this
      // token was minted under the secret we're rotating away from."
      const claims = jwt.decode(issuedRefresh) as {
        sub: string;
        type: string;
        jti: string;
        iat: number;
        exp: number;
      };

      const oldRefresh = jwt.sign(
        {
          sub: claims.sub,
          type: 'refresh',
          jti: claims.jti,
          iat: claims.iat,
        },
        PREV_REFRESH,
        { audience: JWT_AUDIENCE, expiresIn: '30d', noTimestamp: true },
      );

      const res = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: oldRefresh });
      expect(res.status).toBe(200);
      expect(res.body.accessToken).toEqual(expect.any(String));
      expect(res.body.refreshToken).toEqual(expect.any(String));

      // The new pair MUST verify against the CURRENT secret without any
      // fallback. Clear the previous secret first to make the assertion
      // strict — if the new tokens were accidentally signed under
      // PREVIOUS we'd see a JsonWebTokenError here.
      (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = undefined;
      expect(() =>
        jwt.verify(res.body.refreshToken, env.JWT_REFRESH_SECRET, {
          audience: JWT_AUDIENCE,
        }),
      ).not.toThrow();
      expect(() =>
        jwt.verify(res.body.accessToken, env.JWT_ACCESS_SECRET, {
          audience: JWT_AUDIENCE,
        }),
      ).not.toThrow();
    });

    it('rejects a previous-signed refresh token (401) when JWT_REFRESH_SECRET_PREVIOUS is unset', async () => {
      (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = undefined;
      const app = await getTestApp();
      const signup = await request(app).post('/api/auth/signup').send({
        email: `rotation-noprev-${Date.now()}@example.local`,
        password: 'CorrectHorseBattery1',
        displayName: 'NoPrev User',
      });
      expect(signup.status).toBe(201);
      const userId = signup.body.user.id as string;

      const oldRefresh = jwt.sign(
        { sub: userId, type: 'refresh', jti: `noprev-${Date.now()}` },
        PREV_REFRESH,
        { audience: JWT_AUDIENCE, expiresIn: '30d' },
      );
      const res = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: oldRefresh });
      expect(res.status).toBe(401);
    });

    it('rejects a garbage refresh token regardless of rotation state', async () => {
      (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = PREV_REFRESH;
      const app = await getTestApp();
      const signup = await request(app).post('/api/auth/signup').send({
        email: `rotation-garbage-${Date.now()}@example.local`,
        password: 'CorrectHorseBattery1',
        displayName: 'Garbage User',
      });
      expect(signup.status).toBe(201);
      const userId = signup.body.user.id as string;

      const garbage = jwt.sign(
        { sub: userId, type: 'refresh', jti: `garbage-${Date.now()}` },
        'completely-wrong-refresh-secret-still-32-chars-plus',
        { audience: JWT_AUDIENCE, expiresIn: '30d' },
      );
      const res = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: garbage });
      expect(res.status).toBe(401);
    });
  });
});
