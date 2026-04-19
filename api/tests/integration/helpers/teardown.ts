import { prisma } from '@/config/prisma';
import { redis } from '@/config/redis';

/** Close shared long-lived connections so jest can exit cleanly. */
export async function closeConnections(): Promise<void> {
  await Promise.allSettled([prisma.$disconnect(), redis.quit()]);
}
