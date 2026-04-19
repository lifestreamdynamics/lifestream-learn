import '@tests/unit/setup';
import type { NextFunction, Request, Response } from 'express';
import { optionalAuthenticate } from '@/middleware/optional-authenticate';
import { signAccessToken } from '@/utils/jwt';
import { UnauthorizedError } from '@/utils/errors';

function makeReq(header?: string): Request {
  return {
    get: (name: string) =>
      name.toLowerCase() === 'authorization' ? header : undefined,
  } as unknown as Request;
}

describe('optionalAuthenticate', () => {
  it('no header → pass-through with no req.user', (done) => {
    const req = makeReq();
    const res = {} as Response;
    const next: NextFunction = (err) => {
      expect(err).toBeUndefined();
      expect((req as Request & { user?: unknown }).user).toBeUndefined();
      done();
    };
    optionalAuthenticate(req, res, next);
  });

  it('non-bearer header → pass-through', (done) => {
    const req = makeReq('Basic foo');
    const res = {} as Response;
    const next: NextFunction = (err) => {
      expect(err).toBeUndefined();
      expect((req as Request & { user?: unknown }).user).toBeUndefined();
      done();
    };
    optionalAuthenticate(req, res, next);
  });

  it('valid bearer → sets req.user', (done) => {
    const token = signAccessToken({
      id: '11111111-1111-4111-8111-111111111111',
      email: 'u@example.local',
      role: 'LEARNER',
    });
    const req = makeReq(`Bearer ${token}`);
    const res = {} as Response;
    const next: NextFunction = (err) => {
      expect(err).toBeUndefined();
      expect((req as Request & { user?: { role: string } }).user?.role).toBe(
        'LEARNER',
      );
      done();
    };
    optionalAuthenticate(req, res, next);
  });

  it('malformed bearer → forwards error', (done) => {
    const req = makeReq('Bearer not-a-jwt');
    const res = {} as Response;
    const next: NextFunction = (err) => {
      expect(err).toBeDefined();
      done();
    };
    optionalAuthenticate(req, res, next);
  });

  it('works for UnauthorizedError type check', () => {
    // Sanity: the error class still exports.
    expect(new UnauthorizedError()).toBeInstanceOf(UnauthorizedError);
  });
});
