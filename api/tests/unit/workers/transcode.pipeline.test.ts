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
      deleteObject,
    },
    probe,
    runFfmpeg,
    buildFfmpegArgs: buildArgs,
    tmp: { makeJobTmpDir: makeTmp, cleanupJobTmpDir: cleanupTmp },
    uploadBucket: 'learn-uploads',
    vodBucket: 'learn-vod',
    maxDurationMs: 180_000,
    logger: silentLogger,
    ...overrides,
  };

  return {
    deps,
    trace,
    mocks: { download, uploadDirectory, deleteObject, probe, runFfmpeg, buildArgs, prismaUpdate, makeTmp, cleanupTmp },
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

    // Strict order: makeTmp → download → probe → prisma TRANSCODING → buildArgs → runFfmpeg → uploadDirectory → prisma READY → deleteObject → cleanupTmp
    expect(trace.order).toEqual([
      'makeTmp',
      'download',
      'probe',
      'prisma.update:"TRANSCODING"',
      'buildArgs',
      'runFfmpeg',
      'uploadDirectory',
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
    };
    const { deps, mocks } = buildDeps({
      probe: jest.fn(async () => longProbe),
    });

    await expect(runTranscodePipeline(data, deps)).rejects.toThrow(/exceeds cap/);
    expect(mocks.runFfmpeg).not.toHaveBeenCalled();
    expect(mocks.uploadDirectory).not.toHaveBeenCalled();
    expect(mocks.cleanupTmp).toHaveBeenCalledTimes(1);
  });

  it('returns success even when source delete fails (best-effort)', async () => {
    const { deps, mocks } = buildDeps({
      objectStore: {
        downloadToFile: jest.fn(async () => undefined),
        uploadDirectory: jest.fn(async () => ({ uploaded: 3 })),
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
