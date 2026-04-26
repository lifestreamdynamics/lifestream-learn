import '@tests/unit/setup';
import jwt from 'jsonwebtoken';
import {
  JWT_AUDIENCE,
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
} from '@/utils/jwt';
import { UnauthorizedError } from '@/utils/errors';
import { getMetrics, resetMetricsForTests } from '@/observability/metrics';

describe('jwt utils', () => {
  const user = { id: 'user-1', role: 'LEARNER' as const, email: 'u@example.com' };

  describe('signAccessToken / verifyAccessToken', () => {
    it('round-trips claims', () => {
      const token = signAccessToken(user);
      const decoded = verifyAccessToken(token);
      expect(decoded.sub).toBe(user.id);
      expect(decoded.role).toBe(user.role);
      expect(decoded.email).toBe(user.email);
      expect(decoded.type).toBe('access');
    });

    it('stamps the learn-api audience', () => {
      const token = signAccessToken(user);
      const raw = jwt.decode(token) as { aud?: string };
      expect(raw.aud).toBe(JWT_AUDIENCE);
    });

    it('rejects tokens signed with the wrong secret', () => {
      const bogus = jwt.sign(
        { sub: user.id, role: user.role, email: user.email, type: 'access' },
        'not-the-right-secret-at-all-xxxxxxxxxxx',
        { audience: JWT_AUDIENCE },
      );
      expect(() => verifyAccessToken(bogus)).toThrow(UnauthorizedError);
      expect(() => verifyAccessToken(bogus)).toThrow('Invalid or expired token');
    });

    it('rejects malformed tokens', () => {
      expect(() => verifyAccessToken('not.a.jwt')).toThrow(UnauthorizedError);
    });

    it('rejects expired tokens', () => {
      const expired = jwt.sign(
        { sub: user.id, role: user.role, email: user.email, type: 'access' },
        process.env.JWT_ACCESS_SECRET as string,
        { expiresIn: '-1s', audience: JWT_AUDIENCE },
      );
      expect(() => verifyAccessToken(expired)).toThrow(UnauthorizedError);
    });

    it('rejects refresh tokens presented as access tokens', () => {
      const { token } = signRefreshToken(user);
      expect(() => verifyAccessToken(token)).toThrow(UnauthorizedError);
    });

    it('rejects access tokens with wrong type claim', () => {
      // Signed with access secret but type='refresh' — should still be rejected.
      const wrongType = jwt.sign(
        { sub: user.id, role: user.role, email: user.email, type: 'refresh' },
        process.env.JWT_ACCESS_SECRET as string,
        { audience: JWT_AUDIENCE },
      );
      expect(() => verifyAccessToken(wrongType)).toThrow(UnauthorizedError);
    });

    it('rejects tokens with a different audience', () => {
      const wrongAud = jwt.sign(
        { sub: user.id, role: user.role, email: user.email, type: 'access' },
        process.env.JWT_ACCESS_SECRET as string,
        { audience: 'some-other-service' },
      );
      expect(() => verifyAccessToken(wrongAud)).toThrow(UnauthorizedError);
    });

    it('rejects tokens missing required claims', () => {
      const missingEmail = jwt.sign(
        { sub: user.id, role: user.role, type: 'access' },
        process.env.JWT_ACCESS_SECRET as string,
        { audience: JWT_AUDIENCE },
      );
      expect(() => verifyAccessToken(missingEmail)).toThrow(UnauthorizedError);
    });

    it('rejects tokens with an empty sub', () => {
      const emptySub = jwt.sign(
        { sub: '', role: user.role, email: user.email, type: 'access' },
        process.env.JWT_ACCESS_SECRET as string,
        { audience: JWT_AUDIENCE },
      );
      expect(() => verifyAccessToken(emptySub)).toThrow(UnauthorizedError);
    });
  });

  describe('signRefreshToken / verifyRefreshToken', () => {
    it('round-trips with a unique jti each call', () => {
      const t1 = signRefreshToken(user);
      const t2 = signRefreshToken(user);
      const d1 = verifyRefreshToken(t1.token);
      const d2 = verifyRefreshToken(t2.token);
      expect(d1.sub).toBe(user.id);
      expect(d1.type).toBe('refresh');
      expect(d1.jti).toBeTruthy();
      expect(d1.jti).not.toBe(d2.jti);
      // Caller-visible jti matches the decoded one so the service can
      // revoke the old token after rotation.
      expect(t1.jti).toBe(d1.jti);
    });

    it('rejects access tokens presented as refresh tokens', () => {
      const access = signAccessToken(user);
      expect(() => verifyRefreshToken(access)).toThrow(UnauthorizedError);
    });

    it('rejects expired refresh tokens', () => {
      const expired = jwt.sign(
        { sub: user.id, type: 'refresh', jti: 'x' },
        process.env.JWT_REFRESH_SECRET as string,
        { expiresIn: '-1s', audience: JWT_AUDIENCE },
      );
      expect(() => verifyRefreshToken(expired)).toThrow(UnauthorizedError);
    });

    it('rejects malformed refresh tokens', () => {
      expect(() => verifyRefreshToken('nope')).toThrow(UnauthorizedError);
    });

    it('rejects refresh tokens with a different audience', () => {
      const wrongAud = jwt.sign(
        { sub: user.id, type: 'refresh', jti: 'x' },
        process.env.JWT_REFRESH_SECRET as string,
        { audience: 'some-other-service' },
      );
      expect(() => verifyRefreshToken(wrongAud)).toThrow(UnauthorizedError);
    });
  });

  /**
   * Phase 8 / ADR 0007 — JWT dual-secret rotation.
   *
   * `verifyAccessToken` / `verifyRefreshToken` accept a signature from
   * EITHER the current secret OR `JWT_*_SECRET_PREVIOUS` (when set), so
   * an operator can rotate without invalidating in-flight tokens. Sign
   * paths are unchanged — they always use the current secret. The
   * fallback only triggers on `'invalid signature'`; expiry/malformed/
   * audience errors must NOT fall through, otherwise an expired token
   * could "win" against a still-valid previous secret.
   */
  describe('JWT dual-secret rotation', () => {
    // Strings deliberately distinct from the unit-setup defaults
    // (`'a'.repeat(48)` for access, `'b'.repeat(48)` for refresh) so a
    // signature from the "previous" secret can't accidentally match the
    // current secret.
    const PREV_ACCESS = 'p'.repeat(48);
    const PREV_REFRESH = 'q'.repeat(48);

    // We import `env` lazily inside the describe so beforeEach can
    // mutate optional fields without leaking into other test suites
    // through module-cache state.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { env } = require('@/config/env') as typeof import('@/config/env');
    type MutableEnv = {
      JWT_ACCESS_SECRET_PREVIOUS?: string;
      JWT_REFRESH_SECRET_PREVIOUS?: string;
    };

    beforeEach(() => {
      // Reset metrics so per-test increment assertions are deterministic.
      resetMetricsForTests();
      // Default to "previous unset" — each test that needs the rotation
      // path sets the field explicitly.
      (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = undefined;
      (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = undefined;
    });

    afterAll(() => {
      (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = undefined;
      (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = undefined;
      resetMetricsForTests();
    });

    function getPreviousMetricValue(tokenType: 'access' | 'refresh'): number {
      const counter = getMetrics().jwtVerifyWithPreviousTotal;
      const internal = counter as unknown as { hashMap?: Record<string, { value: number }> };
      const buckets = internal.hashMap ?? {};
      for (const key of Object.keys(buckets)) {
        if (key.includes(`tokenType:${tokenType}`)) {
          return buckets[key]?.value ?? 0;
        }
      }
      return 0;
    }

    describe('access tokens', () => {
      it('verifies a token signed with the CURRENT secret (existing path)', () => {
        const token = signAccessToken(user);
        const decoded = verifyAccessToken(token);
        expect(decoded.sub).toBe(user.id);
        // Counter must NOT increment on the current-secret happy path.
        expect(getPreviousMetricValue('access')).toBe(0);
      });

      it('verifies a token signed with the PREVIOUS secret and increments the metric', () => {
        (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = PREV_ACCESS;
        const prevSigned = jwt.sign(
          { sub: user.id, role: user.role, email: user.email, type: 'access' },
          PREV_ACCESS,
          { audience: JWT_AUDIENCE, expiresIn: '15m' },
        );

        const decoded = verifyAccessToken(prevSigned);
        expect(decoded.sub).toBe(user.id);
        expect(decoded.role).toBe(user.role);
        expect(getPreviousMetricValue('access')).toBe(1);
        // Refresh metric must remain untouched — labels are scoped per
        // token type so an access fallback can't fire the refresh series.
        expect(getPreviousMetricValue('refresh')).toBe(0);
      });

      it('verifies the previous-signed token in the ambiguous case where current would also reject', () => {
        // The "ambiguous" case is just a second confirmation that the
        // fallback path is what's accepting the token: signed with
        // PREV_ACCESS, current secret is the unit-setup default and
        // would reject this signature outright. This guards against an
        // accidental refactor that drops the fallback into a no-op.
        (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = PREV_ACCESS;
        const prevSigned = jwt.sign(
          { sub: user.id, role: user.role, email: user.email, type: 'access' },
          PREV_ACCESS,
          { audience: JWT_AUDIENCE, expiresIn: '15m' },
        );

        // Sanity: with the fallback disabled, current rejects.
        (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = undefined;
        expect(() => verifyAccessToken(prevSigned)).toThrow(UnauthorizedError);

        // Re-enable the fallback and the SAME token now verifies.
        (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = PREV_ACCESS;
        expect(() => verifyAccessToken(prevSigned)).not.toThrow();
      });

      it('rejects a previous-signed token when JWT_ACCESS_SECRET_PREVIOUS is unset', () => {
        // Default state from beforeEach — previous is undefined.
        const prevSigned = jwt.sign(
          { sub: user.id, role: user.role, email: user.email, type: 'access' },
          PREV_ACCESS,
          { audience: JWT_AUDIENCE, expiresIn: '15m' },
        );
        expect(() => verifyAccessToken(prevSigned)).toThrow(UnauthorizedError);
        expect(() => verifyAccessToken(prevSigned)).toThrow('Invalid or expired token');
        // Counter must NOT increment when the fallback path was never taken.
        expect(getPreviousMetricValue('access')).toBe(0);
      });

      it('does NOT fall through to previous on an expired token', () => {
        // An expired token signed with the PREVIOUS secret must still
        // reject. Falling through here would let an attacker with a
        // stolen-but-expired token replay it whenever a rotation
        // window is open.
        (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = PREV_ACCESS;
        const expired = jwt.sign(
          { sub: user.id, role: user.role, email: user.email, type: 'access' },
          PREV_ACCESS,
          { audience: JWT_AUDIENCE, expiresIn: '-1s' },
        );
        expect(() => verifyAccessToken(expired)).toThrow(UnauthorizedError);
        // Crucially the metric stayed at zero — the fallback never fired
        // for an expired token even though previous-secret matches.
        expect(getPreviousMetricValue('access')).toBe(0);
      });

      it('also does not fall through on an expired token signed with the CURRENT secret', () => {
        (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = PREV_ACCESS;
        const expiredCurrent = jwt.sign(
          { sub: user.id, role: user.role, email: user.email, type: 'access' },
          process.env.JWT_ACCESS_SECRET as string,
          { audience: JWT_AUDIENCE, expiresIn: '-1s' },
        );
        expect(() => verifyAccessToken(expiredCurrent)).toThrow(UnauthorizedError);
        expect(getPreviousMetricValue('access')).toBe(0);
      });

      it('rejects malformed tokens without indicating which secret rejected', () => {
        (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = PREV_ACCESS;
        // Both calls assert the same generic message — no leakage.
        const errorMessages = ['not.a.jwt', 'totally-malformed', 'a.b.c'].map((bad) => {
          try {
            verifyAccessToken(bad);
            return 'NO THROW';
          } catch (e) {
            return (e as Error).message;
          }
        });
        for (const msg of errorMessages) {
          expect(msg).toBe('Invalid or expired token');
        }
        expect(getPreviousMetricValue('access')).toBe(0);
      });

      it('does NOT fall through to previous on an audience mismatch', () => {
        (env as MutableEnv).JWT_ACCESS_SECRET_PREVIOUS = PREV_ACCESS;
        // Signed with the previous secret BUT with the wrong audience.
        // jsonwebtoken raises "jwt audience invalid" before the
        // signature check can even matter; we must reject without
        // leaking that the previous-secret signature was valid.
        const wrongAud = jwt.sign(
          { sub: user.id, role: user.role, email: user.email, type: 'access' },
          PREV_ACCESS,
          { audience: 'some-other-service', expiresIn: '15m' },
        );
        expect(() => verifyAccessToken(wrongAud)).toThrow(UnauthorizedError);
      });
    });

    describe('refresh tokens', () => {
      it('verifies a token signed with the CURRENT secret (existing path)', () => {
        const { token } = signRefreshToken(user);
        const decoded = verifyRefreshToken(token);
        expect(decoded.sub).toBe(user.id);
        expect(getPreviousMetricValue('refresh')).toBe(0);
      });

      it('verifies a token signed with the PREVIOUS secret and increments the metric', () => {
        (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = PREV_REFRESH;
        const prevSigned = jwt.sign(
          { sub: user.id, type: 'refresh', jti: 'rotated-jti' },
          PREV_REFRESH,
          { audience: JWT_AUDIENCE, expiresIn: '30d' },
        );

        const decoded = verifyRefreshToken(prevSigned);
        expect(decoded.sub).toBe(user.id);
        expect(decoded.jti).toBe('rotated-jti');
        expect(getPreviousMetricValue('refresh')).toBe(1);
        // Access counter is independent.
        expect(getPreviousMetricValue('access')).toBe(0);
      });

      it('verifies in the ambiguous case where current would also reject', () => {
        (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = PREV_REFRESH;
        const prevSigned = jwt.sign(
          { sub: user.id, type: 'refresh', jti: 'rot-2' },
          PREV_REFRESH,
          { audience: JWT_AUDIENCE, expiresIn: '30d' },
        );
        (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = undefined;
        expect(() => verifyRefreshToken(prevSigned)).toThrow(UnauthorizedError);
        (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = PREV_REFRESH;
        expect(() => verifyRefreshToken(prevSigned)).not.toThrow();
      });

      it('rejects a previous-signed token when JWT_REFRESH_SECRET_PREVIOUS is unset', () => {
        const prevSigned = jwt.sign(
          { sub: user.id, type: 'refresh', jti: 'unset-test' },
          PREV_REFRESH,
          { audience: JWT_AUDIENCE, expiresIn: '30d' },
        );
        expect(() => verifyRefreshToken(prevSigned)).toThrow(UnauthorizedError);
        expect(() => verifyRefreshToken(prevSigned)).toThrow('Invalid or expired token');
        expect(getPreviousMetricValue('refresh')).toBe(0);
      });

      it('does NOT fall through to previous on an expired refresh token', () => {
        (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = PREV_REFRESH;
        const expired = jwt.sign(
          { sub: user.id, type: 'refresh', jti: 'expired' },
          PREV_REFRESH,
          { audience: JWT_AUDIENCE, expiresIn: '-1s' },
        );
        expect(() => verifyRefreshToken(expired)).toThrow(UnauthorizedError);
        expect(getPreviousMetricValue('refresh')).toBe(0);
      });

      it('rejects malformed refresh tokens without leaking which secret rejected', () => {
        (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = PREV_REFRESH;
        const messages = ['nope', 'a.b.c', 'definitely-not-a-jwt'].map((bad) => {
          try {
            verifyRefreshToken(bad);
            return 'NO THROW';
          } catch (e) {
            return (e as Error).message;
          }
        });
        for (const msg of messages) {
          expect(msg).toBe('Invalid or expired token');
        }
        expect(getPreviousMetricValue('refresh')).toBe(0);
      });

      it('does NOT cross-verify: refresh-PREVIOUS does not validate access tokens', () => {
        // Sanity check that the rotation seam is keyed by token type:
        // setting the refresh-previous secret must NOT let an access
        // token signed with that secret slip through verifyAccessToken.
        (env as MutableEnv).JWT_REFRESH_SECRET_PREVIOUS = PREV_REFRESH;
        const wrongPrev = jwt.sign(
          { sub: user.id, role: user.role, email: user.email, type: 'access' },
          PREV_REFRESH,
          { audience: JWT_AUDIENCE, expiresIn: '15m' },
        );
        expect(() => verifyAccessToken(wrongPrev)).toThrow(UnauthorizedError);
        expect(getPreviousMetricValue('access')).toBe(0);
      });
    });
  });
});
