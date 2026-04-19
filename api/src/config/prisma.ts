import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { env } from '@/config/env';
import { logger } from '@/config/logger';

function buildClient() {
  const adapter = new PrismaPg({ connectionString: env.DATABASE_URL });
  return new PrismaClient({
    adapter,
    log: [
      { emit: 'event', level: 'query' },
      { emit: 'event', level: 'warn' },
      { emit: 'event', level: 'error' },
    ] as const,
  });
}

type Prismatic = ReturnType<typeof buildClient>;

declare global {
   
  var __prisma: Prismatic | undefined;
}

export const prisma: Prismatic = global.__prisma ?? buildClient();

prisma.$on('warn', (e) => logger.warn({ prisma: e }, 'prisma warn'));
prisma.$on('error', (e) => logger.error({ prisma: e }, 'prisma error'));

if (env.NODE_ENV !== 'production') {
  prisma.$on('query', (e) => logger.debug({ prisma: e }, 'prisma query'));
  global.__prisma = prisma;
}
