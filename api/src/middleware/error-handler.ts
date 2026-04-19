import type { ErrorRequestHandler } from 'express';
import { ZodError } from 'zod';
import { Prisma } from '@prisma/client';
import { AppError } from '@/utils/errors';
import { logger } from '@/config/logger';

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
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: err.code,
      message: err.message,
      ...(err.details ? { details: err.details } : {}),
    });
    return;
  }
  logger.error({ err, reqId: req.id }, 'unhandled error');
  res.status(500).json({ error: 'INTERNAL_ERROR', message: 'Internal server error' });
};
