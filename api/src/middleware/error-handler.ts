import type { ErrorRequestHandler } from 'express';
import { ZodError } from 'zod';
import { Prisma } from '@prisma/client';
import { AppError } from '@/utils/errors';
import { logger } from '@/config/logger';
import { getDoctorReporter } from '@/observability/doctor-reporter';

export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  if (err instanceof ZodError) {
    res.status(400).json({
      error: 'VALIDATION_ERROR',
      message: 'Validation failed',
      issues: err.issues,
    });
    return;
  }
  if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
    res.status(409).json({ error: 'CONFLICT', message: 'Unique constraint violation' });
    return;
  }
  if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
    res.status(404).json({ error: 'NOT_FOUND', message: 'Record not found' });
    return;
  }
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: err.code,
      message: err.message,
      ...(err.details ? { details: err.details } : {}),
    });
    return;
  }
  logger.error({ err, reqId: req.id }, 'unhandled error');
  // Forward to the crash-reporting seam. When CRASH_REPORTING_ENABLED is
  // false (the default, including tests) this is a no-op beyond a debug log
  // line — no network call, no exception escape.
  getDoctorReporter().captureException(err, {
    reqId: typeof req.id === 'string' || typeof req.id === 'number' ? req.id : undefined,
  });
  res.status(500).json({ error: 'INTERNAL_ERROR', message: 'Internal server error' });
};
