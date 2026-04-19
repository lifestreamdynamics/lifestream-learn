import '@tests/unit/setup';
import request from 'supertest';
import express from 'express';

jest.mock('@/config/prisma', () => ({
  prisma: { $queryRaw: jest.fn() },
}));
jest.mock('@/config/redis', () => ({
  redis: { ping: jest.fn() },
}));
jest.mock('@/config/s3', () => ({
  s3Client: { send: jest.fn() },
}));

import { prisma } from '@/config/prisma';
import { redis } from '@/config/redis';
import { s3Client } from '@/config/s3';
import { healthRouter } from '@/routes/health.routes';
import { errorHandler } from '@/middleware/error-handler';

function buildApp() {
  const app = express();
  app.use('/health', healthRouter);
  app.use(errorHandler);
  return app;
}

describe('GET /health', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns 200 with all deps ok', async () => {
    (prisma.$queryRaw as jest.Mock).mockResolvedValue([{ '?column?': 1 }]);
    (redis.ping as jest.Mock).mockResolvedValue('PONG');
    (s3Client.send as jest.Mock).mockResolvedValue({});

    const res = await request(buildApp()).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.dependencies).toEqual({ database: 'ok', redis: 'ok', s3: 'ok' });
  });

  it('returns 503 when the database is unreachable', async () => {
    (prisma.$queryRaw as jest.Mock).mockRejectedValue(new Error('ECONNREFUSED'));
    (redis.ping as jest.Mock).mockResolvedValue('PONG');
    (s3Client.send as jest.Mock).mockResolvedValue({});

    const res = await request(buildApp()).get('/health');
    expect(res.status).toBe(503);
    expect(res.body.status).toBe('degraded');
    expect(res.body.dependencies.database).toBe('error');
    expect(res.body.dependencies.redis).toBe('ok');
  });

  it('returns 503 when redis ping is unexpected', async () => {
    (prisma.$queryRaw as jest.Mock).mockResolvedValue([{ '?column?': 1 }]);
    (redis.ping as jest.Mock).mockResolvedValue('WAT');
    (s3Client.send as jest.Mock).mockResolvedValue({});

    const res = await request(buildApp()).get('/health');
    expect(res.status).toBe(503);
    expect(res.body.dependencies.redis).toBe('error');
  });

  it('returns 503 when the upload bucket is missing', async () => {
    (prisma.$queryRaw as jest.Mock).mockResolvedValue([{ '?column?': 1 }]);
    (redis.ping as jest.Mock).mockResolvedValue('PONG');
    (s3Client.send as jest.Mock).mockRejectedValue(new Error('NoSuchBucket'));

    const res = await request(buildApp()).get('/health');
    expect(res.status).toBe(503);
    expect(res.body.dependencies.s3).toBe('error');
  });

  it('liveness returns 200', async () => {
    const res = await request(buildApp()).get('/health/liveness');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});
