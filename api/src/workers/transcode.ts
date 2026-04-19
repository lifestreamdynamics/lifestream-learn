import { logger } from '@/config/logger';

/**
 * Phase 2 placeholder. The real BullMQ Worker consuming `learn:transcode`
 * and running FFmpeg ladders lands in Phase 3 per IMPLEMENTATION_PLAN.md §5.
 */
function main(): void {
  logger.info('transcode worker: phase 2 placeholder — Phase 3 will implement');
  process.exit(0);
}

main();
