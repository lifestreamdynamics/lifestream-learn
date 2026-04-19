import '@tests/unit/setup';
import type { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { errorHandler } from '@/middleware/error-handler';
import { UnauthorizedError, AppError } from '@/utils/errors';

function makeRes(): Response {
  const res = {} as Response;
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

function makeReq(): Request {
  return { id: 'req-123' } as unknown as Request;
}

describe('errorHandler middleware', () => {
  it('handles ZodError as 400 with issues', () => {
    const schema = z.object({ email: z.string().email() });
    let zerr: z.ZodError | null = null;
    try {
      schema.parse({ email: 'not-an-email' });
    } catch (err) {
      zerr = err as z.ZodError;
    }
    expect(zerr).toBeTruthy();

    const req = makeReq();
    const res = makeRes();
    const next = jest.fn() as unknown as NextFunction;

    errorHandler(zerr, req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: 'VALIDATION_ERROR',
        message: 'Validation failed',
        issues: expect.any(Array),
      }),
    );
  });

  it('handles Prisma P2002 as 409 CONFLICT', () => {
    const err = Object.assign(new Error('unique constraint'), {
      code: 'P2002',
      clientVersion: '7.0.0',
    });
    Object.setPrototypeOf(err, Prisma.PrismaClientKnownRequestError.prototype);

    const req = makeReq();
    const res = makeRes();
    const next = jest.fn() as unknown as NextFunction;

    errorHandler(err, req, res, next);

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith({
      error: 'CONFLICT',
      message: 'Unique constraint violation',
    });
  });

  it('handles AppError subclasses (UnauthorizedError) with statusCode + code', () => {
    const req = makeReq();
    const res = makeRes();
    const next = jest.fn() as unknown as NextFunction;

    errorHandler(new UnauthorizedError('bad creds'), req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      error: 'UNAUTHORIZED',
      message: 'bad creds',
    });
  });

  it('includes details when AppError has details', () => {
    class WithDetails extends AppError {
      constructor() {
        super(422, 'WAT', 'whatever', { foo: 'bar' });
      }
    }
    const req = makeReq();
    const res = makeRes();
    const next = jest.fn() as unknown as NextFunction;

    errorHandler(new WithDetails(), req, res, next);

    expect(res.status).toHaveBeenCalledWith(422);
    expect(res.json).toHaveBeenCalledWith({
      error: 'WAT',
      message: 'whatever',
      details: { foo: 'bar' },
    });
  });

  it('handles generic Error as 500 INTERNAL_ERROR without leaking', () => {
    const req = makeReq();
    const res = makeRes();
    const next = jest.fn() as unknown as NextFunction;

    errorHandler(new Error('secret database password leaked'), req, res, next);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      error: 'INTERNAL_ERROR',
      message: 'Internal server error',
    });
  });
});
