import '@tests/unit/setup';
import type { Request, Response, NextFunction } from 'express';
import { requireRole } from '@/middleware/require-role';
import { UnauthorizedError, ForbiddenError } from '@/utils/errors';

function makeReq(user?: { id: string; role: 'LEARNER' | 'COURSE_DESIGNER' | 'ADMIN'; email: string }): Request {
  return { user } as unknown as Request;
}

describe('requireRole middleware', () => {
  it('calls next with UnauthorizedError when req.user is not set', () => {
    const req = makeReq();
    const res = {} as Response;
    const next = jest.fn() as unknown as NextFunction;

    requireRole('ADMIN')(req, res, next);

    const err = (next as unknown as jest.Mock).mock.calls[0][0];
    expect(err).toBeInstanceOf(UnauthorizedError);
  });

  it('calls next with ForbiddenError when role is not permitted', () => {
    const req = makeReq({ id: 'u', role: 'LEARNER', email: 'u@e.com' });
    const res = {} as Response;
    const next = jest.fn() as unknown as NextFunction;

    requireRole('ADMIN')(req, res, next);

    const err = (next as unknown as jest.Mock).mock.calls[0][0];
    expect(err).toBeInstanceOf(ForbiddenError);
    expect(err.message).toBe('Insufficient role');
  });

  it('calls next() with no args when role matches', () => {
    const req = makeReq({ id: 'u', role: 'ADMIN', email: 'u@e.com' });
    const res = {} as Response;
    const next = jest.fn() as unknown as NextFunction;

    requireRole('ADMIN', 'COURSE_DESIGNER')(req, res, next);

    expect((next as unknown as jest.Mock).mock.calls[0]).toHaveLength(0);
  });

  it('accepts any of multiple roles', () => {
    const req = makeReq({ id: 'u', role: 'COURSE_DESIGNER', email: 'u@e.com' });
    const res = {} as Response;
    const next = jest.fn() as unknown as NextFunction;

    requireRole('ADMIN', 'COURSE_DESIGNER')(req, res, next);

    expect((next as unknown as jest.Mock).mock.calls[0]).toHaveLength(0);
  });
});
