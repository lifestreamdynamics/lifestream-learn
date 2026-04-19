import { prisma } from '@/config/prisma';
import { redis } from '@/config/redis';

/** Truncate all learn tables between integration tests. */
export async function resetDb(): Promise<void> {
  await prisma.$executeRawUnsafe(
    `TRUNCATE TABLE
      "AnalyticsEvent","Attempt","Enrollment","Cue","Video",
      "CourseCollaborator","Course","DesignerApplication","User"
      RESTART IDENTITY CASCADE`,
  );
}

/** Clear the rate-limit keys on the shared Redis between tests. */
export async function resetRateLimits(): Promise<void> {
  // ioredis keyPrefix ("learn_test:") is applied automatically on every call,
  // including SCAN args. So matching "rl:*" here targets keys stored as
  // "learn_test:rl:*" in Postgres terms — and returns them *with* that prefix
  // in the response. We need to strip the prefix before DEL because DEL will
  // re-apply it.
  const prefix = redis.options.keyPrefix ?? '';
  const found: string[] = [];
  let cursor = '0';
  do {
    const [next, keys] = (await redis.scan(cursor, 'MATCH', `${prefix}rl:*`, 'COUNT', 200)) as [
      string,
      string[],
    ];
    cursor = next;
    for (const k of keys) found.push(prefix && k.startsWith(prefix) ? k.slice(prefix.length) : k);
  } while (cursor !== '0');
  if (found.length > 0) await redis.del(...found);
}
