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

  S3_ENDPOINT: z
    .string()
    .url()
    .refine(
      (url) => {
        // In production, reject link-local / loopback / metadata-service
        // hostnames so a misconfigured env var can't turn the ObjectStore
        // into an SSRF gadget pointed at 169.254.169.254 (AWS metadata),
        // ::1, 127.0.0.1, etc. Local dev still needs http://localhost and
        // http://seaweedfs:8333, so this gate is prod-only.
        if (process.env.NODE_ENV !== 'production') return true;
        try {
          const host = new URL(url).hostname;
          if (host === 'localhost' || host === '127.0.0.1' || host === '::1') return false;
          if (/^169\.254\./.test(host)) return false;
          if (/^10\./.test(host)) return false; // private — opt in by removing this if genuinely needed
          if (/^172\.(1[6-9]|2\d|3[01])\./.test(host)) return false;
          if (/^192\.168\./.test(host)) return false;
          return true;
        } catch {
          return false;
        }
      },
      { message: 'S3_ENDPOINT may not resolve to a loopback/link-local/private subnet in production' },
    ),
  S3_REGION: z.string().default('us-east-1'),
  S3_ACCESS_KEY: z.string().min(1),
  S3_SECRET_KEY: z.string().min(1),
  S3_UPLOAD_BUCKET: z.string().default('learn-uploads'),
  S3_VOD_BUCKET: z.string().default('learn-vod'),
  S3_FORCE_PATH_STYLE: z.coerce.boolean().default(true),

  TUSD_PUBLIC_URL: z.string().url(),

  HLS_BASE_URL: z.string().url(),
  // 32 bytes (256 bits) minimum. Generate with `openssl rand -base64 48`.
  // The signer is MD5-based per ADR 0002; strength is gated on the secret.
  HLS_SIGNING_SECRET: z.string().min(32),
  HLS_SIGNING_TTL_SECONDS: z.coerce.number().int().positive().default(7200),

  CORS_ALLOWED_ORIGINS: z
    .string()
    .default('')
    .transform((s) => s.split(',').map((x) => x.trim()).filter(Boolean)),

  SEED_ADMIN_EMAIL: z.string().email().default('admin@example.local'),
  SEED_ADMIN_PASSWORD: z.string().min(12).optional(),
  SEED_DESIGNER_EMAIL: z.string().email().default('designer@example.local'),
  SEED_LEARNER_EMAIL: z.string().email().default('learner@example.local'),
  // Shared password for the designer + learner dev users. The admin keeps its
  // own variable so an operator can rotate it independently. Optional —
  // when omitted, seed.ts generates a per-user random password and logs it once.
  SEED_DEV_USER_PASSWORD: z.string().min(12).optional(),
  // When true (default), `npm run prisma:seed` creates a "Dev Sample 101"
  // course owned by the seeded designer and uploads + transcodes a sample
  // video. Requires the transcode worker to be running. Set to false to
  // keep the seed DB-only.
  SEED_SAMPLE_VIDEO: z.coerce.boolean().default(true),

  TUSD_HOOK_SECRET: z.string().min(16),
  TRANSCODE_CONCURRENCY: z.coerce.number().int().positive().default(1),
  TRANSCODE_TMP_DIR: z.string().default(path.join(os.tmpdir(), 'learn-transcode')),
  FFMPEG_BIN: z.string().default('ffmpeg'),
  FFPROBE_BIN: z.string().default('ffprobe'),
  VIDEO_MAX_DURATION_MS: z.coerce.number().int().positive().default(180_000),

  // ---------- Video input policy (Slice V1) ----------
  // Upper bound on raw upload byte size. tusd enforces this at the
  // network edge via `-max-size`; the pipeline re-validates the actual
  // downloaded file against the same cap as a belt-and-braces check.
  // Default: 2 GiB — covers a 180s 4K source at ~100 Mbps with headroom.
  VIDEO_MAX_BYTES: z.coerce.number().int().positive().default(2 * 1024 * 1024 * 1024),
  // Comma-separated ffprobe `codec_name` tokens we will hand to ffmpeg.
  // Everything else is rejected up-front as UNSUPPORTED_CODEC — ffmpeg's
  // decoder parsers are CVE-heavy, so the whitelist is the trust boundary
  // between "bytes we received" and "bytes we decode".
  VIDEO_ALLOWED_VIDEO_CODECS: z
    .string()
    .default('h264,hevc,vp8,vp9,av1,mpeg4,mpeg2video')
    .transform((s) => s.split(',').map((x) => x.trim().toLowerCase()).filter(Boolean)),
  VIDEO_ALLOWED_AUDIO_CODECS: z
    .string()
    .default('aac,mp3,opus,vorbis,pcm_s16le,pcm_s16be,ac3,eac3,flac')
    .transform((s) => s.split(',').map((x) => x.trim().toLowerCase()).filter(Boolean)),
  // ffprobe `format.format_name` tokens. The MP4/MOV family surfaces as
  // the compound `mov,mp4,m4a,3gp,3g2,mj2`; matroska/webm as `matroska,webm`.
  // Match by substring (comma-split), so `mp4` accepts the compound.
  VIDEO_ALLOWED_CONTAINERS: z
    .string()
    .default('mov,mp4,m4a,3gp,3g2,mj2,matroska,webm,avi')
    .transform((s) => s.split(',').map((x) => x.trim().toLowerCase()).filter(Boolean)),

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

  // tusd-hook limiter. A leaked or brute-forced shared secret should not
  // translate into unbounded BullMQ enqueues — the limit caps per-IP hook
  // traffic so one compromised caller can't flood the transcode pipeline.
  // Pre-finish events are paced by tusd (one per completed upload) so 60/min
  // leaves plenty of headroom for legitimate traffic and load tests.
  RATE_LIMIT_TUSD_HOOK_MAX: z.coerce.number().int().positive().default(60),
  RATE_LIMIT_TUSD_HOOK_WINDOW_MS: z.coerce.number().int().positive().default(60 * 1000),
});

const parsed = EnvSchema.safeParse(process.env);
if (!parsed.success) {
   
  console.error('Invalid environment configuration:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export type Env = typeof env;
