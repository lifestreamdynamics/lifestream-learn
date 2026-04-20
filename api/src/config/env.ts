import os from 'node:os';
import path from 'node:path';
import dotenv from 'dotenv';
import { z } from 'zod';

const cwd = process.cwd();
const envFile = process.env.NODE_ENV === 'test' ? '.env.test' : '.env.local';
dotenv.config({ path: path.resolve(cwd, envFile) });
dotenv.config({ path: path.resolve(cwd, '.env') });

const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3011),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),

  DATABASE_URL: z.string().url(),

  REDIS_URL: z.string().url(),
  REDIS_KEY_PREFIX: z.string().default('learn:'),

  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  JWT_ACCESS_TTL: z.string().default('15m'),
  JWT_REFRESH_TTL: z.string().default('30d'),

  S3_ENDPOINT: z.string().url(),
  S3_REGION: z.string().default('us-east-1'),
  S3_ACCESS_KEY: z.string().min(1),
  S3_SECRET_KEY: z.string().min(1),
  S3_UPLOAD_BUCKET: z.string().default('learn-uploads'),
  S3_VOD_BUCKET: z.string().default('learn-vod'),
  S3_FORCE_PATH_STYLE: z.coerce.boolean().default(true),

  TUSD_PUBLIC_URL: z.string().url(),

  HLS_BASE_URL: z.string().url(),
  HLS_SIGNING_SECRET: z.string().min(16),
  HLS_SIGNING_TTL_SECONDS: z.coerce.number().int().positive().default(7200),

  CORS_ALLOWED_ORIGINS: z
    .string()
    .default('')
    .transform((s) => s.split(',').map((x) => x.trim()).filter(Boolean)),

  SEED_ADMIN_EMAIL: z.string().email().default('admin@example.local'),
  SEED_ADMIN_PASSWORD: z.string().min(12).optional(),

  TUSD_HOOK_SECRET: z.string().min(16),
  TRANSCODE_CONCURRENCY: z.coerce.number().int().positive().default(1),
  TRANSCODE_TMP_DIR: z.string().default(path.join(os.tmpdir(), 'learn-transcode')),
  FFMPEG_BIN: z.string().default('ffmpeg'),
  FFPROBE_BIN: z.string().default('ffprobe'),
  VIDEO_MAX_DURATION_MS: z.coerce.number().int().positive().default(180_000),

  // ---------- Observability (Slice G1) ----------
  // Both flags default false so the test suite + fresh dev clones open no
  // network sockets and expose no new surface until an operator opts in.
  METRICS_ENABLED: z.coerce.boolean().default(false),
  CRASH_REPORTING_ENABLED: z.coerce.boolean().default(false),
  LEARN_CRASH_API_KEY: z.string().default(''),
  LEARN_CRASH_ENDPOINT: z.string().default(''),

  // ---------- HTTP server tuning (Slice G2) ----------
  // Node's default `server.keepAliveTimeout` is 5s, which is shorter than
  // nginx's default upstream keepalive (75s). Requests that land in the
  // gap cause nginx to mint a new TCP connection on every call — fine at
  // low load, murder at 200 VUs. Bump both to sit above the reverse-proxy
  // keepalive. `headersTimeout` must be > keepAliveTimeout or Node rejects
  // the config.
  HTTP_KEEPALIVE_MS: z.coerce.number().int().positive().default(65_000),
  HTTP_HEADERS_TIMEOUT_MS: z.coerce.number().int().positive().default(66_000),

  // ---------- Auth rate-limit ceilings (Slice G2) ----------
  // Prod defaults (keep these modest — they exist to throttle credential
  // stuffing). Operators running k6 from a single loopback IP will need
  // to raise RATE_LIMIT_LOGIN_MAX for the duration of the baseline run.
  // See api/load/README.md §3 for the mechanics.
  RATE_LIMIT_SIGNUP_MAX: z.coerce.number().int().positive().default(10),
  RATE_LIMIT_SIGNUP_WINDOW_MS: z.coerce.number().int().positive().default(10 * 60 * 1000),
  RATE_LIMIT_LOGIN_MAX: z.coerce.number().int().positive().default(5),
  RATE_LIMIT_LOGIN_WINDOW_MS: z.coerce.number().int().positive().default(5 * 60 * 1000),
  RATE_LIMIT_REFRESH_MAX: z.coerce.number().int().positive().default(30),
  RATE_LIMIT_REFRESH_WINDOW_MS: z.coerce.number().int().positive().default(5 * 60 * 1000),
});

const parsed = EnvSchema.safeParse(process.env);
if (!parsed.success) {
   
  console.error('Invalid environment configuration:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export type Env = typeof env;
