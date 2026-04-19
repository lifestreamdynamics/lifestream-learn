import '@tests/unit/setup';

jest.mock('@/services/video.service', () => ({
  videoService: {
    createVideo: jest.fn(),
    getVideoById: jest.fn(),
    canAccessVideo: jest.fn(),
    markReady: jest.fn(),
    markFailed: jest.fn(),
  },
}));

jest.mock('@/utils/hls-signer', () => ({
  signPlaybackUrl: jest.fn().mockReturnValue({
    url: 'http://signed.example/hls/v/master.m3u8?md5=x&expires=1',
    expiresAt: new Date(0),
  }),
}));

import type { Request, Response } from 'express';
import { ZodError } from 'zod';
import * as videosController from '@/controllers/videos.controller';
import { videoService } from '@/services/video.service';
import { signPlaybackUrl } from '@/utils/hls-signer';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  UnauthorizedError,
} from '@/utils/errors';

const VIDEO_ID = '99999999-9999-4999-8999-999999999999';
const COURSE_ID = '88888888-8888-4888-8888-888888888888';
const USER_ID = '77777777-7777-4777-8777-777777777777';

function makeRes(): Response {
  const res = {} as Response;
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

function makeReq(overrides: Partial<Request> = {}): Request {
  return {
    body: {},
    params: {},
    query: {},
    user: { id: USER_ID, role: 'COURSE_DESIGNER', email: 'u@example.com' },
    ...overrides,
  } as unknown as Request;
}

describe('videos.controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('returns 201 with videoId, uploadUrl, and uploadHeaders on success', async () => {
      const fakeVideo = {
        id: VIDEO_ID,
        courseId: COURSE_ID,
        title: 'New',
        orderIndex: 0,
        status: 'UPLOADING' as const,
        durationMs: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      (videoService.createVideo as jest.Mock).mockResolvedValueOnce({
        video: fakeVideo,
        sourceKey: `uploads/${VIDEO_ID}`,
      });

      const req = makeReq({
        body: { courseId: COURSE_ID, title: 'New', orderIndex: 0 },
      });
      const res = makeRes();

      await videosController.create(req, res);

      expect(videoService.createVideo).toHaveBeenCalledWith({
        courseId: COURSE_ID,
        title: 'New',
        orderIndex: 0,
        userId: USER_ID,
        role: 'COURSE_DESIGNER',
      });
      expect(res.status).toHaveBeenCalledWith(201);
      const payload = (res.json as jest.Mock).mock.calls[0][0];
      expect(payload.videoId).toBe(VIDEO_ID);
      expect(payload.video).toBe(fakeVideo);
      expect(payload.sourceKey).toBe(`uploads/${VIDEO_ID}`);
      expect(typeof payload.uploadUrl).toBe('string');
      expect(payload.uploadHeaders['Tus-Resumable']).toBe('1.0.0');
      // Upload-Metadata is `key base64(value)`, padding stripped
      const expectedB64 = Buffer.from(VIDEO_ID).toString('base64').replace(/=+$/, '');
      expect(payload.uploadHeaders['Upload-Metadata']).toBe(`videoId ${expectedB64}`);
    });

    it('throws UnauthorizedError when req.user is absent', async () => {
      const req = makeReq({ user: undefined });
      const res = makeRes();
      await expect(videosController.create(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
      expect(videoService.createVideo).not.toHaveBeenCalled();
    });

    it('throws ZodError on a malformed body', async () => {
      const req = makeReq({ body: { courseId: 'not-a-uuid', title: '', orderIndex: -1 } });
      const res = makeRes();
      await expect(videosController.create(req, res)).rejects.toBeInstanceOf(ZodError);
      expect(videoService.createVideo).not.toHaveBeenCalled();
    });
  });

  describe('getById', () => {
    it('returns 200 with the video on success', async () => {
      const fakeVideo = {
        id: VIDEO_ID,
        courseId: COURSE_ID,
        title: 'A',
        orderIndex: 0,
        status: 'READY' as const,
        durationMs: 10000,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      (videoService.getVideoById as jest.Mock).mockResolvedValueOnce(fakeVideo);

      const req = makeReq({ params: { id: VIDEO_ID } });
      const res = makeRes();

      await videosController.getById(req, res);

      expect(videoService.getVideoById).toHaveBeenCalledWith(VIDEO_ID, USER_ID, 'COURSE_DESIGNER');
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(fakeVideo);
    });

    it('bubbles NotFoundError from the service', async () => {
      (videoService.getVideoById as jest.Mock).mockRejectedValueOnce(
        new NotFoundError('Video not found'),
      );
      const req = makeReq({ params: { id: VIDEO_ID } });
      const res = makeRes();
      await expect(videosController.getById(req, res))
        .rejects.toBeInstanceOf(NotFoundError);
    });

    it('throws UnauthorizedError when req.user is absent', async () => {
      const req = makeReq({ user: undefined, params: { id: VIDEO_ID } });
      const res = makeRes();
      await expect(videosController.getById(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('getPlayback', () => {
    it('returns a signed master playlist URL when the video is READY', async () => {
      (videoService.canAccessVideo as jest.Mock).mockResolvedValueOnce({
        allowed: true,
        video: { id: VIDEO_ID, status: 'READY', hlsPrefix: 'vod/x', courseId: COURSE_ID },
      });

      const req = makeReq({ params: { id: VIDEO_ID } });
      const res = makeRes();

      await videosController.getPlayback(req, res);

      expect(signPlaybackUrl).toHaveBeenCalledWith(`/hls/${VIDEO_ID}/master.m3u8`);
      expect(res.status).toHaveBeenCalledWith(200);
      const payload = (res.json as jest.Mock).mock.calls[0][0];
      expect(payload.masterPlaylistUrl).toContain('master.m3u8');
      expect(typeof payload.expiresAt).toBe('string');
    });

    it.each(['UPLOADING', 'TRANSCODING', 'FAILED'] as const)(
      'throws ConflictError when status=%s',
      async (status) => {
        (videoService.canAccessVideo as jest.Mock).mockResolvedValueOnce({
          allowed: true,
          video: { id: VIDEO_ID, status, hlsPrefix: null, courseId: COURSE_ID },
        });
        const req = makeReq({ params: { id: VIDEO_ID } });
        const res = makeRes();
        await expect(videosController.getPlayback(req, res))
          .rejects.toBeInstanceOf(ConflictError);
        expect(signPlaybackUrl).not.toHaveBeenCalled();
      },
    );

    it('throws ConflictError when status=READY but hlsPrefix missing', async () => {
      (videoService.canAccessVideo as jest.Mock).mockResolvedValueOnce({
        allowed: true,
        video: { id: VIDEO_ID, status: 'READY', hlsPrefix: null, courseId: COURSE_ID },
      });
      const req = makeReq({ params: { id: VIDEO_ID } });
      const res = makeRes();
      await expect(videosController.getPlayback(req, res))
        .rejects.toBeInstanceOf(ConflictError);
    });

    it('throws NotFoundError when the video is missing', async () => {
      (videoService.canAccessVideo as jest.Mock).mockResolvedValueOnce({
        allowed: false,
        video: null,
      });
      const req = makeReq({ params: { id: VIDEO_ID } });
      const res = makeRes();
      await expect(videosController.getPlayback(req, res))
        .rejects.toBeInstanceOf(NotFoundError);
    });

    it('throws ForbiddenError when not allowed', async () => {
      (videoService.canAccessVideo as jest.Mock).mockResolvedValueOnce({
        allowed: false,
        video: { id: VIDEO_ID, status: 'READY', hlsPrefix: 'vod/x', courseId: COURSE_ID },
      });
      const req = makeReq({ params: { id: VIDEO_ID } });
      const res = makeRes();
      await expect(videosController.getPlayback(req, res))
        .rejects.toBeInstanceOf(ForbiddenError);
    });

    it('throws UnauthorizedError when req.user is absent', async () => {
      const req = makeReq({ user: undefined, params: { id: VIDEO_ID } });
      const res = makeRes();
      await expect(videosController.getPlayback(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });
  });
});
