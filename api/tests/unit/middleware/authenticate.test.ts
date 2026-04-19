import '@tests/unit/setup';
import type { Request, Response, NextFunction } from 'express';
import { authenticate } from '@/middleware/authenticate';
import { signAccessToken } from '@/utils/jwt';
import { UnauthorizedError } from '@/utils/errors';

function makeReq(headers: Record<string, string> = {}): Request {
  const lower: Record<string, string> = {};
  for (const [k, v] of Object.entries(headers)) lower[k.toLowerCase()] = v;
  return {
    get: (name: string) => lower[name.toLowerCase()],
  } as unknown as Request;
}

describe('authenticate middleware', () => {
  it('calls next with UnauthorizedError when no authorization header', () => {
    const req = makeReq();
    const res = {} as Response;
    const next = jest.fn() as unknown as NextFunction;

    authenticate(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    const err = (next as unknown as jest.Mock).mock.calls[0][0];
    expect(err).toBeInstanceOf(UnauthorizedError);
    expect(err.message).toBe('Missing bearer token');
  });

  it('calls next with UnauthorizedError when scheme is wrong', () => {
    const req = makeReq({ authorization: 'Basic abc123' });
    const res = {} as Response;
    const next = jest.fn() as unknown as NextFunction;

    authenticate(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    const err = (next as unknown as jest.Mock).mock.calls[0][0];
    expect(err).toBeInstanceOf(UnauthorizedError);
  });

  it('calls next with UnauthorizedError on an invalid token', () => {
    const req = makeReq({ authorization: 'Bearer not-a-valid-jwt' });
    const res = {} as Response;
    const next = jest.fn() as unknown as NextFunction;

    authenticate(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    const err = (next as unknown as jest.Mock).mock.calls[0][0];
    expect(err).toBeInstanceOf(UnauthorizedError);
  });

  it('sets req.user and calls next() with no args on a valid token', () => {
    const token = signAccessToken({
      id: 'user-123',
      role: 'LEARNER',
      email: 'u@example.com',
    });
    const req = makeReq({ authorization: `Bearer ${token}` });
    const res = {} as Response;
    const next = jest.fn() as unknown as NextFunction;

    authenticate(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    expect((next as unknown as jest.Mock).mock.calls[0]).toHaveLength(0);
    expect(req.user).toEqual({
      id: 'user-123',
      role: 'LEARNER',
      email: 'u@example.com',
    });
  });

  it('accepts a case-insensitive scheme', () => {
    const token = signAccessToken({ id: 'u', role: 'ADMIN', email: 'a@e.com' });
    const req = makeReq({ authorization: `bearer ${token}` });
    const res = {} as Response;
    const next = jest.fn() as unknown as NextFunction;

    authenticate(req, res, next);

    expect((next as unknown as jest.Mock).mock.calls[0]).toHaveLength(0);
    expect(req.user?.id).toBe('u');
  });
});
