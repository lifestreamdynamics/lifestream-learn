import crypto from 'node:crypto';
import bcrypt from 'bcrypt';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { prisma } from '@/config/prisma';

async function main(): Promise<void> {
  const email = env.SEED_ADMIN_EMAIL;
  const providedPassword = env.SEED_ADMIN_PASSWORD;
  const generated = providedPassword === undefined;
  const password = providedPassword ?? crypto.randomBytes(12).toString('base64url');
  const passwordHash = await bcrypt.hash(password, 12);

  try {
    await prisma.user.upsert({
      where: { email },
      update: {},
      create: {
        email,
        passwordHash,
        role: 'ADMIN',
        displayName: 'Admin',
      },
    });

    if (generated) {
      logger.warn(
        { email, password },
        'seed: generated admin password (save this — it will not be shown again)',
      );
    } else {
      logger.info({ email }, 'seed: admin user upserted');
    }
  } finally {
    await prisma.$disconnect();
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    logger.error({ err }, 'seed failed');
    process.exit(1);
  });
