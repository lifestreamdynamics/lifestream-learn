import IORedis from 'ioredis';
import { env } from '@/config/env';
import { logger } from '@/config/logger';

/**
 * Shared application Redis client.
 * - Prefixed with `learn:` so every app key is isolated on the shared Redis.
 * - Used directly by app code and by rate-limit-redis.
 * - NOT usable for BullMQ because BullMQ manages its own prefix.
 */
export const redis = new IORedis(env.REDIS_URL, {
  keyPrefix: env.REDIS_KEY_PREFIX,
  maxRetriesPerRequest: null,
  enableReadyCheck: false,
  lazyConnect: false,
});

redis.on('error', (err) => logger.warn({ err }, 'redis connection error'));

/**
 * BullMQ-compatible connection factory.
 * BullMQ requires `maxRetriesPerRequest: null` for blocking commands
 * and manages its own key prefix via `Queue({ prefix })`. Do NOT set
 * `keyPrefix` on this connection — that would double-prefix keys.
 */
export function createBullMQConnection(): IORedis {
  return new IORedis(env.REDIS_URL, {
    maxRetriesPerRequest: null,
    enableReadyCheck: false,
  });
}
