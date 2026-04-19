import '@tests/unit/setup';
import jwt from 'jsonwebtoken';
import {
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

    it('rejects tokens signed with the wrong secret', () => {
      const bogus = jwt.sign({ sub: user.id, role: user.role, email: user.email, type: 'access' }, 'not-the-right-secret-at-all-xxxxxxxxxxx');
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
        { expiresIn: '-1s' },
      );
      expect(() => verifyAccessToken(expired)).toThrow(UnauthorizedError);
    });

    it('rejects refresh tokens presented as access tokens', () => {
      const refresh = signRefreshToken(user);
      expect(() => verifyAccessToken(refresh)).toThrow(UnauthorizedError);
    });

    it('rejects access tokens with wrong type claim', () => {
      // Signed with access secret but type='refresh' — should still be rejected.
      const wrongType = jwt.sign(
        { sub: user.id, role: user.role, email: user.email, type: 'refresh' },
        process.env.JWT_ACCESS_SECRET as string,
      );
      expect(() => verifyAccessToken(wrongType)).toThrow(UnauthorizedError);
    });
  });

  describe('signRefreshToken / verifyRefreshToken', () => {
    it('round-trips with a unique jti each call', () => {
      const t1 = signRefreshToken(user);
      const t2 = signRefreshToken(user);
      const d1 = verifyRefreshToken(t1);
      const d2 = verifyRefreshToken(t2);
      expect(d1.sub).toBe(user.id);
      expect(d1.type).toBe('refresh');
      expect(d1.jti).toBeTruthy();
      expect(d1.jti).not.toBe(d2.jti);
    });

    it('rejects access tokens presented as refresh tokens', () => {
      const access = signAccessToken(user);
      expect(() => verifyRefreshToken(access)).toThrow(UnauthorizedError);
    });

    it('rejects expired refresh tokens', () => {
      const expired = jwt.sign(
        { sub: user.id, type: 'refresh', jti: 'x' },
        process.env.JWT_REFRESH_SECRET as string,
        { expiresIn: '-1s' },
      );
      expect(() => verifyRefreshToken(expired)).toThrow(UnauthorizedError);
    });

    it('rejects malformed refresh tokens', () => {
      expect(() => verifyRefreshToken('nope')).toThrow(UnauthorizedError);
    });
  });
});
