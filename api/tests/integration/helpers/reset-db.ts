import { prisma } from '@/config/prisma';
import { redis } from '@/config/redis';

/**
 * Truncate all learn tables between integration tests.
 *
 * Slice P3: `UserAchievement` is truncated along with per-user state;
 * `Achievement` is NOT — it's a seeded catalog and tests that exercise
 * achievements expect the catalog to exist. Integration tests seed the
 * subset of achievements they care about in `beforeEach`.
 */
export async function resetDb(): Promise<void> {
  await prisma.$executeRawUnsafe(
    `TRUNCATE TABLE
      "AnalyticsEvent","Attempt","Enrollment","Cue","Video",
      "CourseCollaborator","Course","DesignerApplication",
      "UserAchievement","Session","User"
      RESTART IDENTITY CASCADE`,
  );
}

/**
 * Clear keys matching the given patterns on the shared Redis. Intended for
 * use between integration tests — `rl:*` for rate-limit buckets, `bull:*`
 * for transcode queue state. Patterns are applied *under* the active
 * ioredis `keyPrefix` so keys are returned with that prefix, and stripped
 * before DEL so `keyPrefix` isn't re-applied twice.
 */
export async function resetRedisKeys(patterns: string[]): Promise<void> {
  const prefix = redis.options.keyPrefix ?? '';
  for (const pat of patterns) {
    const found: string[] = [];
    let cursor = '0';
    do {
      const [next, keys] = (await redis.scan(
        cursor,
        'MATCH',
        `${prefix}${pat}`,
        'COUNT',
        200,
      )) as [string, string[]];
      cursor = next;
      for (const k of keys) {
        found.push(prefix && k.startsWith(prefix) ? k.slice(prefix.length) : k);
      }
    } while (cursor !== '0');
    if (found.length > 0) await redis.del(...found);
  }
}

/**
 * Back-compat alias that clears only rate-limit keys. New tests should call
 * `resetRedisKeys(['rl:*', 'bull:*'])` instead to also clear queue state.
 */
export async function resetRateLimits(): Promise<void> {
  await resetRedisKeys(['rl:*']);
}
