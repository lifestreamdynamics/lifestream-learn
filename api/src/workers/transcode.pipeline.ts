import fs from 'node:fs/promises';
import path from 'node:path';
import type { PrismaClient } from '@prisma/client';
import type { Logger } from 'pino';
import { selectLadder } from '@/services/ffmpeg/ladder';
import type {
  LadderRung,
  ProbeResult,
  TranscodeJobData,
  TranscodeJobResult,
} from '@/queues/transcode.types';

/**
 * Slim object-store surface the pipeline consumes — keeps the dep contract
 * tight so unit tests can stub with no S3 client at all.
 */
export interface PipelineObjectStore {
  downloadToFile(bucket: string, key: string, localPath: string): Promise<void>;
  uploadDirectory(
    bucket: string,
    keyPrefix: string,
    localDir: string,
    opts?: { concurrency?: number },
  ): Promise<{ uploaded: number }>;
  deleteObject(bucket: string, key: string): Promise<void>;
}

export interface PipelineDeps {
  prisma: PrismaClient;
  objectStore: PipelineObjectStore;
  probe: (localPath: string) => Promise<ProbeResult>;
  runFfmpeg: (args: string[]) => Promise<void>;
  buildFfmpegArgs: (ladder: LadderRung[], inputPath: string, outputDir: string) => string[];
  tmp: {
    makeJobTmpDir: (jobId: string) => Promise<string>;
    cleanupJobTmpDir: (dir: string) => Promise<void>;
  };
  uploadBucket: string;
  vodBucket: string;
  maxDurationMs: number;
  logger: Logger;
}

// Prisma "no rows matched the where clause" error code. We swallow this in
// places where a parallel update may have legitimately moved the row out
// from under us (idempotent retry).
const PRISMA_NOT_FOUND = 'P2025';

function isPrismaNotFound(err: unknown): boolean {
  if (!err || typeof err !== 'object') return false;
  const code = (err as { code?: unknown }).code;
  return code === PRISMA_NOT_FOUND;
}

/**
 * End-to-end transcode pipeline for a single Video. All side effects are
 * injected through `deps` so unit tests cover this without spawning ffmpeg or
 * touching S3 / Postgres.
 */
export async function runTranscodePipeline(
  data: TranscodeJobData,
  deps: PipelineDeps,
): Promise<TranscodeJobResult> {
  const tmp = await deps.tmp.makeJobTmpDir(data.videoId);
  try {
    const sourceFile = path.join(tmp, 'source');
    await deps.objectStore.downloadToFile(deps.uploadBucket, data.sourceKey, sourceFile);

    const probe = await deps.probe(sourceFile);
    if (probe.durationMs > deps.maxDurationMs) {
      throw new Error(
        `source duration ${probe.durationMs}ms exceeds cap ${deps.maxDurationMs}ms`,
      );
    }

    const ladder = selectLadder(probe);
    const outputDir = path.join(tmp, 'out');
    await fs.mkdir(outputDir, { recursive: true });
    // Pre-create per-variant subdirs because ffmpeg's `%v` expansion does not
    // create them itself and will fail to open `v_<i>/seg_001.m4s`.
    await Promise.all(
      ladder.map((_, i) => fs.mkdir(path.join(outputDir, `v_${i}`), { recursive: true })),
    );

    // Flip status UPLOADING -> TRANSCODING. Tolerate P2025 because a retry
    // may legitimately race against an earlier attempt that already moved
    // the row to TRANSCODING.
    try {
      await deps.prisma.video.update({
        where: { id: data.videoId, status: 'UPLOADING' },
        data: { status: 'TRANSCODING' },
      });
    } catch (err) {
      if (!isPrismaNotFound(err)) throw err;
      deps.logger.debug(
        { videoId: data.videoId },
        'video not in UPLOADING state; assuming retry, continuing',
      );
    }

    const args = deps.buildFfmpegArgs(ladder, sourceFile, outputDir);
    await deps.runFfmpeg(args);

    const hlsPrefix = `vod/${data.videoId}`;
    await deps.objectStore.uploadDirectory(deps.vodBucket, hlsPrefix, outputDir);

    // Commit READY. We only allow the transition from UPLOADING or
    // TRANSCODING — never from READY/FAILED — so a stale retry can't
    // resurrect a video the operator marked FAILED. Re-throw all errors
    // here; this is the canonical commit point.
    await deps.prisma.video.update({
      where: { id: data.videoId, status: { in: ['UPLOADING', 'TRANSCODING'] } },
      data: {
        status: 'READY',
        hlsPrefix,
        durationMs: probe.durationMs,
      },
    });

    // Best-effort source delete (ADR 0006 — we don't keep raw uploads after
    // a successful transcode). Failure here is logged but doesn't fail the
    // job.
    try {
      await deps.objectStore.deleteObject(deps.uploadBucket, data.sourceKey);
    } catch (err) {
      deps.logger.warn(
        { err, videoId: data.videoId, sourceKey: data.sourceKey },
        'failed to delete raw upload after transcode',
      );
    }

    return { hlsPrefix, durationMs: probe.durationMs, rungCount: ladder.length };
  } finally {
    await deps.tmp.cleanupJobTmpDir(tmp);
  }
}
