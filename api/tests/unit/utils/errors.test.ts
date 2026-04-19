import '@tests/unit/setup';
import {
  AppError,
  ValidationError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
  NotImplementedError,
} from '@/utils/errors';

describe('AppError subclasses', () => {
  it.each([
    [new ValidationError(), 400, 'VALIDATION_ERROR'],
    [new UnauthorizedError(), 401, 'UNAUTHORIZED'],
    [new ForbiddenError(), 403, 'FORBIDDEN'],
    [new NotFoundError(), 404, 'NOT_FOUND'],
    [new ConflictError(), 409, 'CONFLICT'],
    [new NotImplementedError(), 501, 'NOT_IMPLEMENTED'],
  ])('%o has correct status and code', (err, status, code) => {
    expect(err).toBeInstanceOf(AppError);
    expect(err.statusCode).toBe(status);
    expect(err.code).toBe(code);
  });

  it('carries custom message and details', () => {
    const err = new ValidationError('bad input', { field: 'email' });
    expect(err.message).toBe('bad input');
    expect(err.details).toEqual({ field: 'email' });
  });

  it('AppError captures stack', () => {
    const err = new AppError(418, 'TEAPOT', 'short and stout');
    expect(err.stack).toBeDefined();
    expect(err.name).toBe('AppError');
  });
});
