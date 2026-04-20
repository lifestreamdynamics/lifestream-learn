import { createApp } from '@/app';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { prisma } from '@/config/prisma';
import { redis } from '@/config/redis';
import {
  startQueueDepthSampler,
  stopQueueDepthSampler,
} from '@/observability/queue-depth-sampler';

async function main(): Promise<void> {
  await prisma.$connect();
  await redis.ping();

  const app = createApp();
  const server = app.listen(env.PORT, () => {
    logger.info({ port: env.PORT, env: env.NODE_ENV }, 'learn-api listening');
  });
  // Bump Node's defaults so nginx can actually re-use upstream sockets.
  // See HTTP_KEEPALIVE_MS / HTTP_HEADERS_TIMEOUT_MS in config/env.ts.
  server.keepAliveTimeout = env.HTTP_KEEPALIVE_MS;
  server.headersTimeout = env.HTTP_HEADERS_TIMEOUT_MS;

  if (env.METRICS_ENABLED) {
    startQueueDepthSampler();
  }

  const shutdown = async (signal: string): Promise<void> => {
    logger.info({ signal }, 'shutting down');
    stopQueueDepthSampler();
    server.close();
    await Promise.allSettled([prisma.$disconnect(), redis.quit()]);
    process.exit(0);
  };

  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  process.on('SIGINT', () => void shutdown('SIGINT'));
}

main().catch((err) => {
  logger.fatal({ err }, 'fatal startup error');
  process.exit(1);
});
