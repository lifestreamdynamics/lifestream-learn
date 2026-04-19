import fs from 'node:fs/promises';
import path from 'node:path';
import { env } from '@/config/env';

/**
 * Create (and ensure existence of) a per-job scratch directory under
 * `TRANSCODE_TMP_DIR`. Safe to call repeatedly.
 */
export async function makeJobTmpDir(jobId: string): Promise<string> {
  const dir = path.join(env.TRANSCODE_TMP_DIR, jobId);
  await fs.mkdir(dir, { recursive: true });
  return dir;
}

/**
 * Recursively remove a job tmp directory. Never throws — used in `finally`
 * blocks where we don't want cleanup failures to mask the original error.
 */
export async function cleanupJobTmpDir(dir: string): Promise<void> {
  await fs.rm(dir, { recursive: true, force: true });
}
