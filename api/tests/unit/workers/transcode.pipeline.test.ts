import '@tests/unit/setup';
import path from 'node:path';
import pino from 'pino';
import type { PrismaClient } from '@prisma/client';
import { runTranscodePipeline, type PipelineDeps } from '@/workers/transcode.pipeline';
import type { ProbeResult, TranscodeJobData } from '@/queues/transcode.types';

const VIDEO_ID = '11111111-1111-1111-1111-111111111111';
const SOURCE_KEY = 'src/upload-abc';

const data: TranscodeJobData = { videoId: VIDEO_ID, sourceKey: SOURCE_KEY };

const silentLogger = pino({ level: 'silent' });

interface CallTrace {
  order: string[];
}

function buildDeps(overrides: Partial<PipelineDeps> = {}): { deps: PipelineDeps; trace: CallTrace; mocks: {
  download: jest.Mock;
  uploadDirectory: jest.Mock;
  uploadFile: jest.Mock;
  deleteObject: jest.Mock;
  probe: jest.Mock;
  runFfmpeg: jest.Mock;
  buildArgs: jest.Mock;
  prismaUpdate: jest.Mock;
  makeTmp: jest.Mock;
  cleanupTmp: jest.Mock;
} } {
  const trace: CallTrace = { order: [] };
  const probeResult: ProbeResult = {
    durationMs: 12_000,
    width: 1280,
    height: 720,
    audioSampleRate: 48000,
    hasAudio: true,
    containerFormat: 'mov,mp4,m4a,3gp,3g2,mj2',
    videoCodec: 'h264',
    audioCodec: 'aac',
    rotationDegrees: 0,
  };
  const download = jest.fn(async (_b: string, _k: string, _p: string) => {
    trace.order.push('download');
  });
  const probe = jest.fn(async (_p: string) => {
    trace.order.push('probe');
    return probeResult;
  });
  const buildArgs = jest.fn((_l, _i, _o) => {
    trace.order.push('buildArgs');
    return ['-y', '-i', _i, '-f', 'hls', _o];
  });
  const runFfmpeg = jest.fn(async (_a: string[]) => {
    trace.order.push('runFfmpeg');
  });
  const uploadDirectory = jest.fn(async (_b: string, _k: string, _d: string) => {
    trace.order.push('uploadDirectory');
    return { uploaded: 5 };
  });
  const deleteObject = jest.fn(async (_b: string, _k: string) => {
    trace.order.push('deleteObject');
  });
  const uploadFile = jest.fn(async (_b: string, _k: string, _p: string, _c: string) => {
    trace.order.push('uploadFile');
  });
  const prismaUpdate = jest.fn(async (args: unknown) => {
    trace.order.push(`prisma.update:${JSON.stringify((args as { data: { status: string } }).data.status)}`);
    return {};
  });
  const makeTmp = jest.fn(async (id: string) => {
    trace.order.push('makeTmp');
    return path.join('/tmp/jobs', id);
  });
  const cleanupTmp = jest.fn(async (_d: string) => {
    trace.order.push('cleanupTmp');
  });

  const deps: PipelineDeps = {
    prisma: { video: { update: prismaUpdate } } as unknown as PrismaClient,
    objectStore: {
      downloadToFile: download,
      uploadDirectory,
      uploadFile,
      deleteObject,
    },
    probe,
    runFfmpeg,
    buildFfmpegArgs: buildArgs,
    tmp: { makeJobTmpDir: makeTmp, cleanupJobTmpDir: cleanupTmp },
    uploadBucket: 'learn-uploads',
    vodBucket: 'learn-vod',
    maxDurationMs: 180_000,
    // Generous default policy so existing happy-path tests pass without
    // rewriting every probe shape. Individual tests that need to trip the
    // policy override this field via the `overrides` argument.
    inputPolicy: {
      maxBytes: 10 * 1024 * 1024 * 1024,
      maxDurationMs: 180_000,
      allowedContainers: ['mov', 'mp4', 'matroska', 'webm'],
      allowedVideoCodecs: ['h264', 'hevc', 'vp8', 'vp9', 'av1'],
      allowedAudioCodecs: ['aac', 'mp3', 'opus', 'vorbis'],
    },
    // Pipeline unit tests never touch the real filesystem; stub the
    // file-size probe so assertInputAcceptable gets a sane value.
    statSizeBytes: async () => 12_345_678,
    logger: silentLogger,
    ...overrides,
  };

  return {
    deps,
    trace,
    mocks: {
      download,
      uploadDirectory,
      uploadFile,
      deleteObject,
      probe,
      runFfmpeg,
      buildArgs,
      prismaUpdate,
      makeTmp,
      cleanupTmp,
    },
  };
}

describe('runTranscodePipeline', () => {
  beforeEach(() => {
    // Mock fs.mkdir to avoid touching the real filesystem in this unit test.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    jest.spyOn(require('node:fs/promises'), 'mkdir').mockResolvedValue(undefined as never);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('runs the happy path in the expected order and returns the result', async () => {
    const { deps, trace, mocks } = buildDeps();

    const result = await runTranscodePipeline(data, deps);

    expect(result).toEqual({
      hlsPrefix: `vod/${VIDEO_ID}`,
      durationMs: 12_000,
      rungCount: 3, // height=720 → 360p+540p+720p
    });

    // Strict order: makeTmp → download → probe → prisma TRANSCODING →
    // buildArgs → runFfmpeg → uploadDirectory → runFfmpeg (poster) →
    // uploadFile (poster) → prisma READY → deleteObject → cleanupTmp.
    // The second `runFfmpeg` is the poster extraction — the happy-path
    // `buildDeps` doesn't override `runFfmpegPoster` so the pipeline
    // falls back to `runFfmpeg` for the poster call.
    expect(trace.order).toEqual([
      'makeTmp',
      'download',
      'probe',
      'prisma.update:"TRANSCODING"',
      'buildArgs',
      'runFfmpeg',
      'uploadDirectory',
      'runFfmpeg',
      'uploadFile',
      'prisma.update:"READY"',
      'deleteObject',
      'cleanupTmp',
    ]);

    // Verify uploadDirectory got the canonical hlsPrefix.
    expect(mocks.uploadDirectory).toHaveBeenCalledWith(
      'learn-vod',
      `vod/${VIDEO_ID}`,
      expect.stringContaining(VIDEO_ID),
    );

    // Verify READY update payload.
    const readyCall = mocks.prismaUpdate.mock.calls.find(
      (c: unknown[]) => (c[0] as { data: { status: string } }).data.status === 'READY',
    )?.[0] as { data: { hlsPrefix: string; durationMs: number } };
    expect(readyCall.data.hlsPrefix).toBe(`vod/${VIDEO_ID}`);
    expect(readyCall.data.durationMs).toBe(12_000);
  });

  it('cleans up tmp on success', async () => {
    const { deps, mocks } = buildDeps();
    await runTranscodePipeline(data, deps);
    expect(mocks.cleanupTmp).toHaveBeenCalledTimes(1);
    expect(mocks.cleanupTmp).toHaveBeenCalledWith(path.join('/tmp/jobs', VIDEO_ID));
  });

  it('cleans up tmp even when ffmpeg fails', async () => {
    const { deps, mocks } = buildDeps({
      runFfmpeg: jest.fn(async () => { throw new Error('boom'); }),
    });

    await expect(runTranscodePipeline(data, deps)).rejects.toThrow(/boom/);
    expect(mocks.cleanupTmp).toHaveBeenCalledTimes(1);
    // No upload should have happened.
    expect(mocks.uploadDirectory).not.toHaveBeenCalled();
    expect(mocks.deleteObject).not.toHaveBeenCalled();
  });

  it('rejects when source duration exceeds the cap and never invokes ffmpeg', async () => {
    const longProbe: ProbeResult = {
      durationMs: 200_000,
      width: 1920,
      height: 1080,
      audioSampleRate: 48000,
      hasAudio: true,
      containerFormat: 'mov,mp4,m4a,3gp,3g2,mj2',
      videoCodec: 'h264',
      audioCodec: 'aac',
      rotationDegrees: 0,
    };
    const { deps, mocks } = buildDeps({
      probe: jest.fn(async () => longProbe),
    });

    await expect(runTranscodePipeline(data, deps)).rejects.toThrow(/exceeds cap/);
    expect(mocks.runFfmpeg).not.toHaveBeenCalled();
    expect(mocks.uploadDirectory).not.toHaveBeenCalled();
    expect(mocks.cleanupTmp).toHaveBeenCalledTimes(1);
  });

  it('persists UNSUPPORTED_VIDEO_CODEC and never invokes ffmpeg when probe reports a disallowed codec', async () => {
    const disallowed: ProbeResult = {
      durationMs: 12_000,
      width: 1280,
      height: 720,
      audioSampleRate: 48000,
      hasAudio: true,
      containerFormat: 'mov,mp4',
      videoCodec: 'prores',
      audioCodec: 'aac',
      rotationDegrees: 0,
    };
    const { deps, mocks } = buildDeps({
      probe: jest.fn(async () => disallowed),
    });

    await expect(runTranscodePipeline(data, deps)).rejects.toThrow(/allow-list/);
    expect(mocks.runFfmpeg).not.toHaveBeenCalled();
    expect(mocks.uploadDirectory).not.toHaveBeenCalled();

    const failedCall = mocks.prismaUpdate.mock.calls.find(
      (c: unknown[]) => (c[0] as { data: { status: string } }).data.status === 'FAILED',
    )?.[0] as { data: { failureReason: string } };
    expect(failedCall.data.failureReason).toBe('UNSUPPORTED_VIDEO_CODEC');
  });

  it('persists INPUT_TOO_LARGE when the downloaded file exceeds maxBytes', async () => {
    const { deps, mocks } = buildDeps({
      statSizeBytes: async () => 5 * 1024 * 1024 * 1024,
      inputPolicy: {
        maxBytes: 1024 * 1024 * 1024,
        maxDurationMs: 180_000,
        allowedContainers: ['mp4'],
        allowedVideoCodecs: ['h264'],
        allowedAudioCodecs: ['aac'],
      },
    });

    await expect(runTranscodePipeline(data, deps)).rejects.toThrow(/exceeds cap/);
    const failedCall = mocks.prismaUpdate.mock.calls.find(
      (c: unknown[]) => (c[0] as { data: { status: string } }).data.status === 'FAILED',
    )?.[0] as { data: { failureReason: string } };
    expect(failedCall.data.failureReason).toBe('INPUT_TOO_LARGE');
  });

  it('persists TRANSCODE_FAILED when ffmpeg itself errors after policy passed', async () => {
    const { deps, mocks } = buildDeps({
      runFfmpeg: jest.fn(async () => { throw new Error('x264 bad input'); }),
    });

    await expect(runTranscodePipeline(data, deps)).rejects.toThrow(/x264/);

    const failedCall = mocks.prismaUpdate.mock.calls.find(
      (c: unknown[]) => (c[0] as { data: { status: string } }).data.status === 'FAILED',
    )?.[0] as { data: { failureReason: string } };
    expect(failedCall.data.failureReason).toBe('TRANSCODE_FAILED');
  });

  it('generates a poster after transcode and persists the posterKey on READY', async () => {
    const { deps, mocks } = buildDeps();

    await runTranscodePipeline(data, deps);

    expect(mocks.uploadFile).toHaveBeenCalledTimes(1);
    const [bucket, key, , contentType] = mocks.uploadFile.mock.calls[0] as [
      string,
      string,
      string,
      string,
    ];
    expect(bucket).toBe('learn-vod');
    expect(key).toBe(`vod/${VIDEO_ID}/poster.jpg`);
    expect(contentType).toBe('image/jpeg');

    const readyCall = mocks.prismaUpdate.mock.calls.find(
      (c: unknown[]) => (c[0] as { data: { status: string } }).data.status === 'READY',
    )?.[0] as { data: { posterKey: string | null } };
    expect(readyCall.data.posterKey).toBe(`vod/${VIDEO_ID}/poster.jpg`);
  });

  it('still commits READY when the poster extraction itself fails', async () => {
    // Two ffmpeg invocations happen: the main transcode and the poster.
    // Fail only the second. The existing `runFfmpeg` mock covers the main
    // transcode; `runFfmpegPoster` targets the poster-specific path.
    const { deps, mocks } = buildDeps({
      runFfmpegPoster: jest.fn(async () => { throw new Error('poster boom'); }),
    });

    const result = await runTranscodePipeline(data, deps);
    expect(result.hlsPrefix).toBe(`vod/${VIDEO_ID}`);

    // No poster file should have been uploaded.
    expect(mocks.uploadFile).not.toHaveBeenCalled();
    const readyCall = mocks.prismaUpdate.mock.calls.find(
      (c: unknown[]) => (c[0] as { data: { status: string } }).data.status === 'READY',
    )?.[0] as { data: { posterKey: string | null } };
    expect(readyCall.data.posterKey).toBeNull();
  });

  it('passes rotation and hasAudio from probe into buildFfmpegArgs', async () => {
    const rotated: ProbeResult = {
      durationMs: 12_000,
      width: 1080,
      height: 1920,
      audioSampleRate: null,
      hasAudio: false,
      containerFormat: 'mov,mp4',
      videoCodec: 'h264',
      audioCodec: null,
      rotationDegrees: 90,
    };
    const { deps, mocks } = buildDeps({
      probe: jest.fn(async () => rotated),
    });

    await runTranscodePipeline(data, deps);

    expect(mocks.buildArgs).toHaveBeenCalledTimes(1);
    const [, , , optsArg] = mocks.buildArgs.mock.calls[0] as [unknown, unknown, unknown, unknown];
    expect(optsArg).toEqual({ rotationDegrees: 90, hasAudio: false });
  });

  it('returns success even when source delete fails (best-effort)', async () => {
    const { deps, mocks } = buildDeps({
      objectStore: {
        downloadToFile: jest.fn(async () => undefined),
        uploadDirectory: jest.fn(async () => ({ uploaded: 3 })),
        uploadFile: jest.fn(async () => undefined),
        deleteObject: jest.fn(async () => { throw new Error('s3 down'); }),
      },
    });

    const result = await runTranscodePipeline(data, deps);

    expect(result.hlsPrefix).toBe(`vod/${VIDEO_ID}`);
    expect(mocks.cleanupTmp).toHaveBeenCalledTimes(1);
  });

  it('swallows P2025 on the UPLOADING→TRANSCODING transition', async () => {
    const prismaUpdate = jest.fn()
      .mockImplementationOnce(async () => {
        const err = new Error('Record to update not found.') as Error & { code: string };
        err.code = 'P2025';
        throw err;
      })
      .mockResolvedValue({});

    const { deps } = buildDeps({
      prisma: { video: { update: prismaUpdate } } as unknown as PrismaClient,
    });

    await expect(runTranscodePipeline(data, deps)).resolves.toEqual(
      expect.objectContaining({ hlsPrefix: `vod/${VIDEO_ID}` }),
    );

    // Two update calls: the swallowed UPLOADING→TRANSCODING and the READY commit.
    expect(prismaUpdate).toHaveBeenCalledTimes(2);
  });

  it('re-throws non-P2025 errors from the TRANSCODING update', async () => {
    const prismaUpdate = jest.fn()
      .mockImplementationOnce(async () => {
        throw new Error('connection lost');
      });

    const { deps, mocks } = buildDeps({
      prisma: { video: { update: prismaUpdate } } as unknown as PrismaClient,
    });

    await expect(runTranscodePipeline(data, deps)).rejects.toThrow(/connection lost/);
    expect(mocks.runFfmpeg).not.toHaveBeenCalled();
    expect(mocks.cleanupTmp).toHaveBeenCalledTimes(1);
  });

  it('re-throws errors from the READY commit', async () => {
    const prismaUpdate = jest.fn()
      .mockResolvedValueOnce({}) // TRANSCODING
      .mockImplementationOnce(async () => { throw new Error('READY commit failed'); });

    const { deps, mocks } = buildDeps({
      prisma: { video: { update: prismaUpdate } } as unknown as PrismaClient,
    });

    await expect(runTranscodePipeline(data, deps)).rejects.toThrow(/READY commit failed/);
    // Source delete should not run if the READY commit failed.
    expect(mocks.deleteObject).not.toHaveBeenCalled();
    expect(mocks.cleanupTmp).toHaveBeenCalledTimes(1);
  });
});
