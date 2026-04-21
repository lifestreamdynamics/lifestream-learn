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
});
