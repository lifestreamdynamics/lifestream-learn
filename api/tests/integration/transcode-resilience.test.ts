import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { Worker, type Job } from 'bullmq';
import { HeadObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import type IORedis from 'ioredis';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { createCourse, createUser, createVideoDirect } from '@tests/integration/helpers/factories';
import { prisma } from '@/config/prisma';
import { logger } from '@/config/logger';
import { createBullMQConnection } from '@/config/redis';
import { s3Client } from '@/config/s3';
import { createObjectStore } from '@/services/object-store';
import { probeVideo } from '@/services/ffmpeg/probe';
import { runFfmpeg } from '@/services/ffmpeg/run-ffmpeg';
import { buildFfmpegArgs } from '@/services/ffmpeg/build-args';
import { makeJobTmpDir, cleanupJobTmpDir } from '@/utils/tmp-dir';
import { runTranscodePipeline, type PipelineDeps } from '@/workers/transcode.pipeline';
import {
  TRANSCODE_QUEUE_NAME,
  closeTranscodeQueue,
  enqueueTranscode,
  getTranscodeQueue,
} from '@/queues/transcode.queue';
import type { TranscodeJobData, TranscodeJobResult } from '@/queues/transcode.types';
import { env } from '@/config/env';

// Phase 3 exit criterion: "Transcode worker survives a simulated kill mid-job
// and resumes cleanly on restart without data corruption." The pipeline is
// already idempotent by construction:
//   - UPLOADING -> TRANSCODING transition tolerates Prisma P2025 (a retry can
//     race against an earlier attempt's transition).
//   - The READY commit only accepts UPLOADING|TRANSCODING -> READY, so a
//     stale retry can't resurrect a video the operator marked FAILED.
//   - HLS output keys are derived from `videoId`, so the second run's S3 PUTs
//     overwrite the first run's partial output deterministically.
// This test asserts those properties end-to-end.

const FIXTURE = path.resolve(__dirname, '..', 'fixtures', 'sample-3s.mp4');

function buildPipelineDeps(
  runFfmpegImpl: (args: string[]) => Promise<void> = (args) => runFfmpeg(args, { logger }),
): PipelineDeps {
  return {
    prisma,
    objectStore: createObjectStore(s3Client),
    probe: (localPath) => probeVideo(localPath),
    runFfmpeg: runFfmpegImpl,
    buildFfmpegArgs,
    tmp: { makeJobTmpDir, cleanupJobTmpDir },
    uploadBucket: env.S3_UPLOAD_BUCKET,
    vodBucket: env.S3_VOD_BUCKET,
    maxDurationMs: env.VIDEO_MAX_DURATION_MS,
    inputPolicy: {
      maxBytes: env.VIDEO_MAX_BYTES,
      maxDurationMs: env.VIDEO_MAX_DURATION_MS,
      allowedContainers: env.VIDEO_ALLOWED_CONTAINERS,
      allowedVideoCodecs: env.VIDEO_ALLOWED_VIDEO_CODECS,
      allowedAudioCodecs: env.VIDEO_ALLOWED_AUDIO_CODECS,
    },
    logger,
  };
}

function startWorker(
  deps: PipelineDeps,
  opts: { stalledInterval?: number; maxStalledCount?: number } = {},
): { worker: Worker<TranscodeJobData, TranscodeJobResult>; connection: IORedis } {
  const connection = createBullMQConnection();
  const worker = new Worker<TranscodeJobData, TranscodeJobResult>(
    TRANSCODE_QUEUE_NAME,
    async (job: Job<TranscodeJobData, TranscodeJobResult>) =>
      runTranscodePipeline(job.data, deps),
    {
      connection,
      prefix: `${env.REDIS_KEY_PREFIX}bull`,
      concurrency: 1,
      // Tight stalled-job detection so the second worker reclaims the job in
      // single-digit seconds rather than the 30s default — without this the
      // test would have to wait for the stock interval to elapse.
      stalledInterval: opts.stalledInterval ?? 1000,
      maxStalledCount: opts.maxStalledCount ?? 1,
    },
  );
  return { worker, connection };
}

async function closeWorker(
  handle: { worker: Worker<TranscodeJobData, TranscodeJobResult>; connection: IORedis },
  force: boolean,
): Promise<void> {
  await handle.worker.close(force);
  await handle.connection.quit().catch(() => undefined);
}

async function uploadFixtureSource(videoId: string): Promise<string> {
  const sourceKey = `uploads/${videoId}`;
  const bytes = await readFile(FIXTURE);
  await s3Client.send(
    new PutObjectCommand({
      Bucket: env.S3_UPLOAD_BUCKET,
      Key: sourceKey,
      Body: bytes,
      ContentType: 'video/mp4',
    }),
  );
  return sourceKey;
}

describe('Transcode worker resilience (kill and resume)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeTranscodeQueue();
    await closeConnections();
  }, 30_000);

  it(
    'second worker resumes a job whose first worker was force-killed mid-ffmpeg',
    async () => {
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);
      const video = await createVideoDirect(course.id, { status: 'UPLOADING' });
      const sourceKey = await uploadFixtureSource(video.id);

      // First worker: replace runFfmpeg with a stub that hangs forever so we
      // can guarantee the job is in-flight (i.e. ffmpeg is "running") at the
      // moment we kill the worker. Pin it on a deferred promise that the test
      // never resolves; we'll force-close before it has a chance to.
      let firstFfmpegStarted: () => void = () => undefined;
      const firstFfmpegStartedPromise = new Promise<void>((resolve) => {
        firstFfmpegStarted = resolve;
      });
      const hangingFfmpeg = (): Promise<void> =>
        new Promise<void>((_resolve, _reject) => {
          firstFfmpegStarted();
          // Never resolves. Force-close will discard this promise.
        });

      const firstHandle = startWorker(buildPipelineDeps(hangingFfmpeg));

      await enqueueTranscode({ videoId: video.id, sourceKey });
      // Wait until the worker has actually entered our hanging ffmpeg call —
      // i.e. the source has been downloaded and the row has transitioned to
      // TRANSCODING. Anything earlier would mean the kill happened before the
      // job was meaningfully in-flight.
      await firstFfmpegStartedPromise;

      const midState = await prisma.video.findUnique({ where: { id: video.id } });
      expect(midState?.status).toBe('TRANSCODING');

      // Force-close: drop the active job on the floor. BullMQ will detect it
      // as stalled (per our 1s interval) and re-queue it for the next worker.
      await closeWorker(firstHandle, /* force */ true);

      // Second worker: real ffmpeg, real upload. Should pick up the stalled
      // job, transcode the 3s fixture, and commit READY.
      const secondHandle = startWorker(buildPipelineDeps());

      try {
        await new Promise<void>((resolve, reject) => {
          const deadline = Date.now() + 75_000;
          const tick = async (): Promise<void> => {
            if (Date.now() > deadline) {
              reject(new Error('timeout waiting for second worker to mark video READY'));
              return;
            }
            const v = await prisma.video.findUnique({ where: { id: video.id } });
            if (v?.status === 'READY') {
              resolve();
              return;
            }
            if (v?.status === 'FAILED') {
              reject(new Error('video transitioned to FAILED'));
              return;
            }
            setTimeout(() => {
              tick().catch(reject);
            }, 500);
          };
          tick().catch(reject);
        });

        const finalState = await prisma.video.findUnique({ where: { id: video.id } });
        expect(finalState?.status).toBe('READY');
        expect(finalState?.hlsPrefix).toBe(`vod/${video.id}`);
        expect(finalState?.durationMs).toBeGreaterThan(0);

        // The READY commit's where-clause guards against status drift. Verify
        // the master playlist exists in the VOD bucket — proves the second
        // run's uploadDirectory produced a coherent HLS tree, not just that
        // the DB row flipped.
        const head = await s3Client.send(
          new HeadObjectCommand({
            Bucket: env.S3_VOD_BUCKET,
            Key: `vod/${video.id}/master.m3u8`,
          }),
        );
        expect(head.$metadata.httpStatusCode).toBe(200);

        // BullMQ should show no remaining waiting/active/delayed work for this
        // job — the second worker drove it to completion.
        const queue = getTranscodeQueue();
        const counts = await queue.getJobCounts('waiting', 'active', 'delayed', 'failed');
        expect(counts.active).toBe(0);
        expect(counts.waiting).toBe(0);
        expect(counts.delayed).toBe(0);
      } finally {
        await closeWorker(secondHandle, /* force */ false);
      }
    },
    120_000,
  );
});
