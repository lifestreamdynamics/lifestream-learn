import path from 'node:path';
import { execSync } from 'node:child_process';
import dotenv from 'dotenv';

/**
 * Jest globalSetup: run once before the integration suite.
 * Loads `.env.test` (for DATABASE_URL pointing at learn_api_test) and applies
 * pending Prisma migrations so `tests/integration/helpers/reset-db.ts` has
 * tables to truncate.
 */
export default async function globalSetup(): Promise<void> {
  dotenv.config({ path: path.resolve(__dirname, '..', '..', '.env.test') });
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL must be set for integration tests (via .env.test)');
  }
  execSync('npx prisma migrate deploy', { stdio: 'inherit' });
}
