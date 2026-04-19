import 'dotenv/config';
import path from 'node:path';
import dotenv from 'dotenv';
import { defineConfig } from '@prisma/config';

// Load .env.local (dev) or .env.test (test) the same way src/config/env.ts does,
// so `prisma migrate dev/deploy` can resolve DATABASE_URL without duplicating secrets.
const envFile = process.env.NODE_ENV === 'test' ? '.env.test' : '.env.local';
dotenv.config({ path: path.resolve(__dirname, envFile) });

export default defineConfig({
  schema: path.resolve(__dirname, 'prisma/schema.prisma'),
  migrations: {
    path: path.resolve(__dirname, 'prisma/migrations'),
  },
  datasource: {
    url: process.env.DATABASE_URL,
  },
});
