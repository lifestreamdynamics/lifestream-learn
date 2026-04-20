import { getTranscodeQueue } from '@/queues/transcode.queue';
import { logger } from '@/config/logger';
import { getMetrics } from '@/observability/metrics';

const SAMPLE_INTERVAL_MS = 15_000;

let timer: NodeJS.Timeout | null = null;

async function sampleOnce(): Promise<void> {
  const queue = getTranscodeQueue();
  const counts = await queue.getJobCounts('waiting', 'active', 'delayed', 'failed');
  const { transcodeQueueDepth } = getMetrics();
  for (const [state, n] of Object.entries(counts)) {
    transcodeQueueDepth.set({ state }, n);
  }
}

/**
 * Start periodic BullMQ queue-depth sampling. Idempotent — a second call is
 * a no-op. `stopQueueDepthSampler` clears the timer during shutdown so Node
 * can exit.
 *
 * Only called from the API process when METRICS_ENABLED is true; the
 * transcode worker process has its own BullMQ events and does not need to
 * poll the queue to drive a gauge.
 */
export function startQueueDepthSampler(): void {
  if (timer) return;
  // Prime the gauge immediately so scrapes right after startup aren't empty.
  void sampleOnce().catch((err) => {
    logger.warn({ err }, 'queue-depth sampler: initial sample failed');
  });
  timer = setInterval(() => {
    void sampleOnce().catch((err) => {
      logger.warn({ err }, 'queue-depth sampler: sample failed');
    });
  }, SAMPLE_INTERVAL_MS);
  // Don't keep the event loop alive for the sampler — the HTTP server is
  // the lifetime holder.
  timer.unref();
}

export function stopQueueDepthSampler(): void {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}
