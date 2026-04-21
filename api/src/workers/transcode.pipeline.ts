import fs from 'node:fs/promises';
import path from 'node:path';
import type { PrismaClient } from '@prisma/client';
import type { Logger } from 'pino';
import { selectLadder } from '@/services/ffmpeg/ladder';
import {
  assertInputAcceptable,
  VideoPolicyError,
  type InputPolicy,
  type VideoFailureReason,
} from '@/services/ffmpeg/input-policy';
import {
  buildPosterArgs,
  POSTER_FILENAME,
  posterKey as buildPosterKey,
} from '@/services/ffmpeg/poster';
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
  uploadFile(
    bucket: string,
    key: string,
    localPath: string,
    contentType: string,
  ): Promise<void>;
  deleteObject(bucket: string, key: string): Promise<void>;
}

export interface BuildArgsCall {
  (
    ladder: LadderRung[],
    inputPath: string,
    outputDir: string,
    opts?: { rotationDegrees?: 0 | 90 | 180 | 270; hasAudio?: boolean },
  ): string[];
}

export interface PipelineDeps {
  prisma: PrismaClient;
  objectStore: PipelineObjectStore;
  probe: (localPath: string) => Promise<ProbeResult>;
  /**
   * Main ffmpeg invocation (the HLS ladder). Separate from the poster
   * run so a unit test can simulate "transcode succeeded, poster
   * failed" and assert that the video still lands READY.
   */
  runFfmpeg: (args: string[]) => Promise<void>;
  /**
   * Optional poster invocation. Same argv-based shape as `runFfmpeg`.
   * Defaults to running ffmpeg via the same implementation; only useful
   * to override in tests.
   */
  runFfmpegPoster?: (args: string[]) => Promise<void>;
  buildFfmpegArgs: BuildArgsCall;
  tmp: {
    makeJobTmpDir: (jobId: string) => Promise<string>;
    cleanupJobTmpDir: (dir: string) => Promise<void>;
  };
  uploadBucket: string;
  vodBucket: string;
  maxDurationMs: number;
  /**
   * Slice V1 input policy. The caller constructs this from env vars in
   * the worker bootstrap; leaving it on `PipelineDeps` means unit tests
   * can hand in a tailor-made policy per scenario without mutating
   * process.env.
   */
  inputPolicy: InputPolicy;
  /**
   * Optional file-size getter. Injected so unit tests can stub the
   * downloaded-file size check without touching the filesystem.
   * Defaults to `fs.stat(path).size`.
   */
  statSizeBytes?: (localPath: string) => Promise<number>;
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
    const sizeBytes = deps.statSizeBytes
      ? await deps.statSizeBytes(sourceFile)
      : (await fs.stat(sourceFile)).size;

    // Slice V1: fail fast on inputs outside policy. This throws a
    // `VideoPolicyError` whose stable `reason` code is persisted on
    // Video.failureReason so the UI can map it to a friendly message
    // without re-parsing stderr. The legacy inline duration check below
    // is retained for belt-and-braces against out-of-band callers of
    // the pipeline that pass a hand-crafted policy.
    try {
      assertInputAcceptable(probe, sizeBytes, deps.inputPolicy);
    } catch (err) {
      if (err instanceof VideoPolicyError) {
        await markVideoFailed(deps.prisma, data.videoId, err.reason);
      }
      throw err;
    }

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

    const args = deps.buildFfmpegArgs(ladder, sourceFile, outputDir, {
      rotationDegrees: probe.rotationDegrees,
      hasAudio: probe.hasAudio,
    });
    try {
      await deps.runFfmpeg(args);
    } catch (err) {
      // Any ffmpeg error at the transcode stage is persistent — the source
      // made it through probe + policy but ffmpeg still couldn't handle it.
      // Mark TRANSCODE_FAILED so the UI can show a different message than
      // "you uploaded something we don't support" (which is what the
      // UNSUPPORTED_* codes communicate).
      await markVideoFailed(deps.prisma, data.videoId, 'TRANSCODE_FAILED');
      throw err;
    }

    const hlsPrefix = `vod/${data.videoId}`;
    await deps.objectStore.uploadDirectory(deps.vodBucket, hlsPrefix, outputDir);

    // Poster generation is best-effort. A missing poster degrades the
    // feed UX (no thumbnail on the pre-load card) but does not block
    // playback; a video with audio/visual content that ffmpeg can still
    // decode for HLS but chokes on a single-frame extract is rare but
    // possible. Prefer a working video with no poster over marking the
    // whole job FAILED.
    let posterKeyOnReady: string | null = null;
    try {
      const posterLocal = path.join(outputDir, POSTER_FILENAME);
      const posterArgs = buildPosterArgs(sourceFile, posterLocal);
      const runPoster = deps.runFfmpegPoster ?? deps.runFfmpeg;
      await runPoster(posterArgs);
      const key = buildPosterKey(data.videoId);
      await deps.objectStore.uploadFile(
        deps.vodBucket,
        key,
        posterLocal,
        'image/jpeg',
      );
      posterKeyOnReady = key;
    } catch (err) {
      deps.logger.warn(
        { err, videoId: data.videoId },
        'poster generation failed — continuing without a poster',
      );
    }

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
        posterKey: posterKeyOnReady,
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

/**
 * Persist a terminal failure with its reason. Tolerant of P2025 so a
 * race against a concurrent update doesn't crash the worker right when
 * it's already trying to surface a user-visible error.
 */
async function markVideoFailed(
  prisma: PrismaClient,
  videoId: string,
  reason: VideoFailureReason,
): Promise<void> {
  try {
    await prisma.video.update({
      where: { id: videoId },
      data: { status: 'FAILED', failureReason: reason },
    });
  } catch (err) {
    if (!isPrismaNotFound(err)) throw err;
  }
}
