/**
 * Loaded before ts-jest in every worker so @/config/env sees a sane,
 * test-shaped environment with DATABASE_URL pointing at learn_api_test.
 * Integration tests need a real Postgres, Redis, and SeaweedFS reachable on
 * localhost per infra/README.md.
 */
import path from 'node:path';
import dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '..', '..', '.env.test') });
process.env.NODE_ENV = 'test';
