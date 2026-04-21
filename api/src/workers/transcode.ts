import { Worker, type Job } from 'bullmq';
import type IORedis from 'ioredis';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { prisma } from '@/config/prisma';
import { redis, createBullMQConnection } from '@/config/redis';
import { s3Client } from '@/config/s3';
import { createObjectStore } from '@/services/object-store';
import { probeVideo } from '@/services/ffmpeg/probe';
import { runFfmpeg } from '@/services/ffmpeg/run-ffmpeg';
import { buildFfmpegArgs } from '@/services/ffmpeg/build-args';
import { logFfmpegVersion } from '@/services/ffmpeg/version-check';
import { makeJobTmpDir, cleanupJobTmpDir } from '@/utils/tmp-dir';
import { runTranscodePipeline, type PipelineDeps } from '@/workers/transcode.pipeline';
import { TRANSCODE_QUEUE_NAME, closeTranscodeQueue } from '@/queues/transcode.queue';
import type {
  TranscodeJobData,
  TranscodeJobResult,
} from '@/queues/transcode.types';

/**
 * Standalone BullMQ worker process: pulls `learn:transcode` jobs, downloads
 * the source from SeaweedFS, runs an FFmpeg HLS+fMP4 ABR transcode, uploads
 * the outputs, and flips the Video row to READY (or FAILED on terminal
 * failure).
 */
function main(): void {
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

  const workerConnection: IORedis = createBullMQConnection();

  const worker = new Worker<TranscodeJobData, TranscodeJobResult>(
    TRANSCODE_QUEUE_NAME,
    async (job: Job<TranscodeJobData, TranscodeJobResult>) =>
      runTranscodePipeline(job.data, deps),
    {
      connection: workerConnection,
      prefix: `${env.REDIS_KEY_PREFIX}bull`,
      concurrency: env.TRANSCODE_CONCURRENCY,
    },
  );

  worker.on('completed', (job, result) => {
    logger.info(
      { jobId: job.id, videoId: job.data.videoId, result },
      'transcode completed',
    );
  });

  worker.on('error', (err) => {
    logger.error({ err }, 'transcode worker error');
  });

  worker.on('failed', async (job, err) => {
    if (!job) {
      logger.warn({ err }, 'transcode job failed (no job context)');
      return;
    }
    const maxAttempts = job.opts.attempts ?? 3;
    logger.warn(
      {
        err,
        jobId: job.id,
        videoId: job.data.videoId,
        attemptsMade: job.attemptsMade,
        maxAttempts,
      },
      'transcode job failed',
    );
    if (job.attemptsMade >= maxAttempts) {
      try {
        await prisma.video.update({
          where: { id: job.data.videoId },
          data: { status: 'FAILED' },
        });
      } catch (e) {
        logger.error(
          { err: e, videoId: job.data.videoId },
          'could not mark video FAILED',
        );
      }
    }
  });

  const shutdown = async (signal: string): Promise<void> => {
    logger.info({ signal }, 'transcode worker shutting down');
    try {
      await worker.close();
      await closeTranscodeQueue();
      await workerConnection.quit().catch(() => undefined);
      await prisma.$disconnect();
      await redis.quit().catch(() => undefined);
    } catch (err) {
      logger.error({ err }, 'error during transcode worker shutdown');
    }
    process.exit(0);
  };

  process.on('SIGTERM', () => {
    void shutdown('SIGTERM');
  });
  process.on('SIGINT', () => {
    void shutdown('SIGINT');
  });

  logger.info(
    { concurrency: env.TRANSCODE_CONCURRENCY },
    'transcode worker started',
  );

  // Fire-and-forget version check. Doesn't gate boot because we'd rather
  // fail the first job loudly than refuse to start a worker on a slightly
  // old-but-possibly-workable FFmpeg in dev.
  void logFfmpegVersion(logger);
}

try {
  main();
} catch (err) {
  logger.fatal({ err }, 'transcode worker failed to start');
  process.exit(1);
}
