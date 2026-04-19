import '@tests/unit/setup';

jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
}));

import type { Request, Response } from 'express';
import { ZodError } from 'zod';
import { handleTusdHook } from '@/controllers/tusd-hooks.controller';
import { enqueueTranscode } from '@/queues/transcode.queue';
import { UnauthorizedError, ValidationError } from '@/utils/errors';

const VIDEO_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const HOOK_SECRET = process.env.TUSD_HOOK_SECRET as string;

function makeRes(): Response {
  const res = {} as Response;
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

function makeReq(opts: {
  headers?: Record<string, string>;
  query?: Record<string, string>;
  body?: unknown;
}): Request {
  const headers = opts.headers ?? {};
  return {
    body: opts.body ?? {},
    query: opts.query ?? {},
    header(name: string) {
      const lower = name.toLowerCase();
      const found = Object.entries(headers).find(([k]) => k.toLowerCase() === lower);
      return found ? found[1] : undefined;
    },
  } as unknown as Request;
}

function preFinishBody(metadata: Record<string, string> = { videoId: VIDEO_ID }) {
  return {
    Type: 'pre-finish',
    Event: { Upload: { ID: 'tus-upload-id', MetaData: metadata } },
  };
}

describe('tusd-hooks.controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects with 401 when neither header nor query token is present', async () => {
    const req = makeReq({ body: preFinishBody() });
    const res = makeRes();
    await expect(handleTusdHook(req, res)).rejects.toBeInstanceOf(UnauthorizedError);
    expect(enqueueTranscode).not.toHaveBeenCalled();
  });

  it('rejects with 401 when the token is wrong (matched length)', async () => {
    // Same length as the real secret but different bytes — exercises the
    // constant-time compare path, not the early length-mismatch return.
    const wrong = 'X'.repeat(HOOK_SECRET.length);
    const req = makeReq({
      headers: { 'x-tusd-hook-token': wrong },
      body: preFinishBody(),
    });
    const res = makeRes();
    await expect(handleTusdHook(req, res)).rejects.toBeInstanceOf(UnauthorizedError);
    expect(enqueueTranscode).not.toHaveBeenCalled();
  });

  it('rejects with 401 when the token is wrong length (early bail)', async () => {
    const req = makeReq({
      headers: { 'x-tusd-hook-token': 'short' },
      body: preFinishBody(),
    });
    const res = makeRes();
    await expect(handleTusdHook(req, res)).rejects.toBeInstanceOf(UnauthorizedError);
    expect(enqueueTranscode).not.toHaveBeenCalled();
  });

  it('enqueues a transcode job on pre-finish with header token', async () => {
    const req = makeReq({
      headers: { 'x-tusd-hook-token': HOOK_SECRET },
      body: preFinishBody(),
    });
    const res = makeRes();

    await handleTusdHook(req, res);

    expect(enqueueTranscode).toHaveBeenCalledWith({
      videoId: VIDEO_ID,
      sourceKey: 'tus-upload-id',
    });
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ ok: true, enqueued: VIDEO_ID });
  });

  it('accepts the secret via the ?token= query (dev fallback)', async () => {
    const req = makeReq({
      query: { token: HOOK_SECRET },
      body: preFinishBody(),
    });
    const res = makeRes();

    await handleTusdHook(req, res);

    expect(enqueueTranscode).toHaveBeenCalledWith({
      videoId: VIDEO_ID,
      sourceKey: 'tus-upload-id',
    });
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('post-finish is acknowledged with a no-op 200 (no enqueue)', async () => {
    const req = makeReq({
      headers: { 'x-tusd-hook-token': HOOK_SECRET },
      body: {
        Type: 'post-finish',
        Event: { Upload: { ID: 'tus-id', MetaData: {} } },
      },
    });
    const res = makeRes();

    await handleTusdHook(req, res);

    expect(enqueueTranscode).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ ok: true, noop: true });
  });

  it('prefers Storage.Key over Upload.ID when tusd supplies it', async () => {
    const req = makeReq({
      headers: { 'x-tusd-hook-token': HOOK_SECRET },
      body: {
        Type: 'pre-finish',
        Event: {
          Upload: {
            ID: 'tus-upload-id',
            MetaData: { videoId: VIDEO_ID },
            Storage: { Key: 'custom-storage-key', Bucket: 'learn-uploads' },
          },
        },
      },
    });
    const res = makeRes();
    await handleTusdHook(req, res);
    expect(enqueueTranscode).toHaveBeenCalledWith({
      videoId: VIDEO_ID,
      sourceKey: 'custom-storage-key',
    });
  });

  it('throws ValidationError when videoId is not a UUID', async () => {
    const req = makeReq({
      headers: { 'x-tusd-hook-token': HOOK_SECRET },
      body: preFinishBody({ videoId: 'not-a-uuid' }),
    });
    const res = makeRes();
    await expect(handleTusdHook(req, res)).rejects.toBeInstanceOf(ValidationError);
    expect(enqueueTranscode).not.toHaveBeenCalled();
  });

  it('throws ValidationError when pre-finish has no videoId metadata', async () => {
    const req = makeReq({
      headers: { 'x-tusd-hook-token': HOOK_SECRET },
      body: preFinishBody({}),
    });
    const res = makeRes();

    await expect(handleTusdHook(req, res)).rejects.toBeInstanceOf(ValidationError);
    expect(enqueueTranscode).not.toHaveBeenCalled();
  });

  it('throws ZodError when the body is malformed', async () => {
    const req = makeReq({
      headers: { 'x-tusd-hook-token': HOOK_SECRET },
      body: { Type: 'pre-finish' /* missing Event */ },
    });
    const res = makeRes();
    await expect(handleTusdHook(req, res)).rejects.toBeInstanceOf(ZodError);
    expect(enqueueTranscode).not.toHaveBeenCalled();
  });
});
