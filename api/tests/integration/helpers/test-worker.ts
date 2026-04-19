import { Worker, type Job } from 'bullmq';
import type IORedis from 'ioredis';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { prisma } from '@/config/prisma';
import { createBullMQConnection } from '@/config/redis';
import { s3Client } from '@/config/s3';
import { createObjectStore } from '@/services/object-store';
import { probeVideo } from '@/services/ffmpeg/probe';
import { runFfmpeg } from '@/services/ffmpeg/run-ffmpeg';
import { buildFfmpegArgs } from '@/services/ffmpeg/build-args';
import { makeJobTmpDir, cleanupJobTmpDir } from '@/utils/tmp-dir';
import { runTranscodePipeline, type PipelineDeps } from '@/workers/transcode.pipeline';
import { TRANSCODE_QUEUE_NAME } from '@/queues/transcode.queue';
import type { TranscodeJobData, TranscodeJobResult } from '@/queues/transcode.types';

export interface TestWorkerHandle {
  worker: Worker<TranscodeJobData, TranscodeJobResult>;
  close: () => Promise<void>;
}

/**
 * Start an in-test BullMQ Worker using the same prefix as the app
 * (`${env.REDIS_KEY_PREFIX}bull` → `learn_test:bull` under .env.test).
 * Caller MUST call `close()` in afterAll/afterEach to free the Redis
 * connection, otherwise jest won't exit cleanly.
 */
export function startTestWorker(): TestWorkerHandle {
  const objectStore = createObjectStore(s3Client);
  const deps: PipelineDeps = {
    prisma,
    objectStore,
    probe: (localPath) => probeVideo(localPath),
    runFfmpeg: (args) => runFfmpeg(args, { logger }),
    buildFfmpegArgs,
    tmp: { makeJobTmpDir, cleanupJobTmpDir },
    uploadBucket: env.S3_UPLOAD_BUCKET,
    vodBucket: env.S3_VOD_BUCKET,
    maxDurationMs: env.VIDEO_MAX_DURATION_MS,
    logger,
  };

  const connection: IORedis = createBullMQConnection();
  const worker = new Worker<TranscodeJobData, TranscodeJobResult>(
    TRANSCODE_QUEUE_NAME,
    async (job: Job<TranscodeJobData, TranscodeJobResult>) =>
      runTranscodePipeline(job.data, deps),
    {
      connection,
      prefix: `${env.REDIS_KEY_PREFIX}bull`,
      concurrency: 1,
    },
  );

  return {
    worker,
    close: async () => {
      await worker.close();
      await connection.quit().catch(() => undefined);
    },
  };
}
