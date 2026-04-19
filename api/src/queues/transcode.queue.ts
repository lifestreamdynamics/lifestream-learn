import { Queue, type JobsOptions } from 'bullmq';
import type IORedis from 'ioredis';
import { env } from '@/config/env';
import { createBullMQConnection } from '@/config/redis';
import type {
  TranscodeJobData,
  TranscodeJobResult,
} from '@/queues/transcode.types';

export const TRANSCODE_QUEUE_NAME = 'transcode';

const DEFAULT_JOB_OPTIONS: JobsOptions = {
  attempts: 3,
  backoff: { type: 'exponential', delay: 2000 },
  removeOnComplete: 100,
  removeOnFail: 500,
};

let queue: Queue<TranscodeJobData, TranscodeJobResult> | null = null;
let connection: IORedis | null = null;

/**
 * Lazy singleton accessor for the transcode queue. The connection is created
 * on first call so that importing this module (e.g. inside the express
 * process) does not establish a Redis connection until something actually
 * needs to enqueue work.
 */
export function getTranscodeQueue(): Queue<TranscodeJobData, TranscodeJobResult> {
  if (queue) return queue;
  connection = createBullMQConnection();
  queue = new Queue<TranscodeJobData, TranscodeJobResult>(TRANSCODE_QUEUE_NAME, {
    connection,
    prefix: `${env.REDIS_KEY_PREFIX}bull`,
    defaultJobOptions: DEFAULT_JOB_OPTIONS,
  });
  return queue;
}

/**
 * Enqueue a transcode job. The job id is set to the videoId so that retries
 * of the tusd hook (or duplicate hook deliveries) collapse into a single job
 * rather than racing each other.
 */
export async function enqueueTranscode(data: TranscodeJobData): Promise<void> {
  const q = getTranscodeQueue();
  await q.add(TRANSCODE_QUEUE_NAME, data, { jobId: data.videoId });
}

/**
 * Close the queue and its underlying Redis connection. Tests call this in
 * `afterAll`; the worker process calls it during graceful shutdown.
 */
export async function closeTranscodeQueue(): Promise<void> {
  if (queue) {
    await queue.close();
    queue = null;
  }
  if (connection) {
    await connection.quit().catch(() => undefined);
    connection = null;
  }
}
