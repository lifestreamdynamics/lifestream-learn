import '@tests/unit/setup';

jest.mock('@/services/auth.service', () => ({
  authService: {
    signup: jest.fn(),
    login: jest.fn(),
    refresh: jest.fn(),
    findById: jest.fn(),
  },
}));

jest.mock('@/utils/jwt', () => ({
  signAccessToken: jest.fn(),
  signRefreshToken: jest.fn(),
  verifyAccessToken: jest.fn(),
  verifyRefreshToken: jest.fn(),
}));

import type { Request, Response } from 'express';
import { ZodError } from 'zod';
import * as authController from '@/controllers/auth.controller';
import { authService } from '@/services/auth.service';
import { verifyRefreshToken } from '@/utils/jwt';
import { UnauthorizedError } from '@/utils/errors';

function makeRes(): Response {
  const res = {} as Response;
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.send = jest.fn().mockReturnValue(res);
  return res;
}

// Slice P6 — auth controllers now read `req.get('user-agent')` + `req.ip`
// to thread a RequestContext through to the session service. The
// controller tests don't care about the exact values — they just need
// the functions to exist so the call doesn't throw.
function makeReq(body: Record<string, unknown>): Request {
  return {
    body,
    get: jest.fn().mockReturnValue(undefined),
    ip: '127.0.0.1',
  } as unknown as Request;
}

describe('auth.controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('signup', () => {
    it('returns 201 with user + tokens on success', async () => {
      const fakeResult = {
        user: {
          id: 'u1',
          email: 'new@example.com',
          role: 'LEARNER' as const,
          displayName: 'New',
          createdAt: new Date(),
        },
        accessToken: 'a-tok',
        refreshToken: 'r-tok',
      };
      (authService.signup as jest.Mock).mockResolvedValueOnce(fakeResult);

      const req = makeReq({
        email: 'new@example.com',
        password: 'correct-horse-battery',
        displayName: 'New',
      });
      const res = makeRes();

      await authController.signup(req, res);

      expect(authService.signup).toHaveBeenCalledWith(
        expect.objectContaining({
          email: 'new@example.com',
          password: 'correct-horse-battery',
          displayName: 'New',
        }),
      );
      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(fakeResult);
    });

    it('throws ZodError synchronously for invalid body', async () => {
      const req = makeReq({ email: 'not-email', password: 'x', displayName: '' });
      const res = makeRes();

      await expect(authController.signup(req, res)).rejects.toBeInstanceOf(ZodError);
      expect(authService.signup).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('returns 200 with user + tokens on success', async () => {
      const fakeResult = {
        user: {
          id: 'u1',
          email: 'x@example.com',
          role: 'LEARNER' as const,
          displayName: 'X',
          createdAt: new Date(),
        },
        accessToken: 'a',
        refreshToken: 'r',
      };
      (authService.login as jest.Mock).mockResolvedValueOnce(fakeResult);

      const req = makeReq({ email: 'x@example.com', password: 'pw' });
      const res = makeRes();

      await authController.login(req, res);

      expect(authService.login).toHaveBeenCalledWith(
        expect.objectContaining({ email: 'x@example.com', password: 'pw' }),
      );
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(fakeResult);
    });
  });

  describe('refresh', () => {
    it('verifies the refresh token, asks service for new tokens, returns 200', async () => {
      (verifyRefreshToken as jest.Mock).mockReturnValueOnce({ sub: 'u-42', type: 'refresh', jti: 'j' });
      const fakeTokens = { accessToken: 'new-a', refreshToken: 'new-r' };
      (authService.refresh as jest.Mock).mockResolvedValueOnce(fakeTokens);

      const req = makeReq({ refreshToken: 'some-refresh-token' });
      const res = makeRes();

      await authController.refresh(req, res);

      expect(verifyRefreshToken).toHaveBeenCalledWith('some-refresh-token');
      expect(authService.refresh).toHaveBeenCalledWith(
        expect.objectContaining({ userId: 'u-42', oldJti: 'j' }),
      );
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(fakeTokens);
    });

    it('throws ZodError when body is missing refreshToken', async () => {
      const req = makeReq({});
      const res = makeRes();

      await expect(authController.refresh(req, res)).rejects.toBeInstanceOf(ZodError);
      expect(verifyRefreshToken).not.toHaveBeenCalled();
    });
  });

  describe('me', () => {
    it('returns 200 with public user when req.user is set', async () => {
      const publicUser = {
        id: 'u1',
        email: 'a@e.com',
        role: 'LEARNER' as const,
        displayName: 'A',
        createdAt: new Date(),
      };
      (authService.findById as jest.Mock).mockResolvedValueOnce(publicUser);

      const req = {
        user: { id: 'u1', role: 'LEARNER', email: 'a@e.com' },
      } as unknown as Request;
      const res = makeRes();

      await authController.me(req, res);

      expect(authService.findById).toHaveBeenCalledWith('u1');
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(publicUser);
    });

    it('throws UnauthorizedError when req.user is not set', async () => {
      const req = {} as Request;
      const res = makeRes();

      await expect(authController.me(req, res)).rejects.toBeInstanceOf(UnauthorizedError);
      expect(authService.findById).not.toHaveBeenCalled();
    });
  });
});
