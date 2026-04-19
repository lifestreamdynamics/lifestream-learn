import { Router } from 'express';
import { HeadBucketCommand } from '@aws-sdk/client-s3';
import { prisma } from '@/config/prisma';
import { redis } from '@/config/redis';
import { s3Client } from '@/config/s3';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { asyncHandler } from '@/middleware/async-handler';

export const healthRouter = Router();

/**
 * @openapi
 * /health:
 *   get:
 *     tags: [System]
 *     summary: Report DB, Redis, and object-store connectivity.
 *     responses:
 *       200: { description: All dependencies healthy. }
 *       503: { description: One or more dependencies failing. }
 */
healthRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    const [db, redisPing, s3] = await Promise.allSettled([
      prisma.$queryRaw`SELECT 1`,
      redis.ping(),
      s3Client.send(new HeadBucketCommand({ Bucket: env.S3_UPLOAD_BUCKET })),
    ]);

    const dependencies = {
      database: db.status === 'fulfilled' ? 'ok' : 'error',
      redis: redisPing.status === 'fulfilled' && redisPing.value === 'PONG' ? 'ok' : 'error',
      s3: s3.status === 'fulfilled' ? 'ok' : 'error',
    };

    if (db.status === 'rejected') logger.warn({ err: db.reason }, 'health: database check failed');
    if (redisPing.status === 'rejected') logger.warn({ err: redisPing.reason }, 'health: redis check failed');
    if (s3.status === 'rejected') logger.warn({ err: s3.reason }, 'health: s3 check failed');

    const allOk = Object.values(dependencies).every((v) => v === 'ok');
    res.status(allOk ? 200 : 503).json({
      status: allOk ? 'ok' : 'degraded',
      dependencies,
      timestamp: new Date().toISOString(),
    });
  }),
);

/**
 * @openapi
 * /health/liveness:
 *   get:
 *     tags: [System]
 *     summary: Bare liveness probe (process is alive, no dep checks).
 *     responses:
 *       200: { description: Process is alive. }
 */
healthRouter.get('/liveness', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});
