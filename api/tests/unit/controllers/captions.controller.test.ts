import '@tests/unit/setup';

jest.mock('@/services/caption.service', () => ({
  captionService: {
    uploadCaption: jest.fn(),
    listCaptions: jest.fn(),
    deleteCaption: jest.fn(),
    getCaptionsForPlayback: jest.fn(),
  },
  CAPTION_MAX_BYTES: 512 * 1024,
}));

import type { Request, Response } from 'express';
import * as captionsController from '@/controllers/captions.controller';
import { captionService, CAPTION_MAX_BYTES } from '@/services/caption.service';
import { UnauthorizedError, ValidationError } from '@/utils/errors';

const VIDEO_ID = '11111111-1111-4111-8111-111111111111';
const USER_ID = '22222222-2222-4222-8222-222222222222';

function makeRes(): Response {
  const res = {} as Response;
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.send = jest.fn().mockReturnValue(res);
  return res;
}

function makeReq(overrides: Partial<Request> = {}): Request {
  return {
    body: {},
    params: { id: VIDEO_ID },
    query: {},
    headers: {},
    get: jest.fn((header: string) => {
      const h = (overrides as Record<string, unknown>)['_headers'] as Record<string, string> | undefined;
      return h?.[header.toLowerCase()] ?? undefined;
    }),
    user: { id: USER_ID, role: 'COURSE_DESIGNER' as const, email: 'u@example.com' },
    ...overrides,
  } as unknown as Request;
}

/** Build a req with a specific Content-Type header value. */
function makeReqWithContentType(
  contentType: string,
  body: unknown = Buffer.alloc(8),
  queryOverrides: Record<string, string> = {},
): Request {
  const req = makeReq({
    query: { language: 'en', ...queryOverrides },
    body,
  });
  (req.get as jest.Mock).mockImplementation((header: string) => {
    if (header.toLowerCase() === 'content-type') return contentType;
    return undefined;
  });
  return req;
}

describe('captions.controller', () => {
  beforeEach(() => jest.clearAllMocks());

  // -------------------------------------------------------------------------
  // uploadCaption
  // -------------------------------------------------------------------------
  describe('uploadCaption', () => {
    it('throws UnauthorizedError when req.user is missing', async () => {
      const req = makeReq({ user: undefined });
      const res = makeRes();
      await expect(captionsController.uploadCaption(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
      expect(captionService.uploadCaption).not.toHaveBeenCalled();
    });

    it('returns 415 when content-type is application/json', async () => {
      const req = makeReqWithContentType('application/json');
      const res = makeRes();
      await captionsController.uploadCaption(req, res);
      expect(res.status).toHaveBeenCalledWith(415);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: 'UNSUPPORTED_MEDIA_TYPE' }),
      );
      expect(captionService.uploadCaption).not.toHaveBeenCalled();
    });

    it('returns 415 when content-type is image/jpeg', async () => {
      const req = makeReqWithContentType('image/jpeg');
      const res = makeRes();
      await captionsController.uploadCaption(req, res);
      expect(res.status).toHaveBeenCalledWith(415);
      expect(captionService.uploadCaption).not.toHaveBeenCalled();
    });

    it('throws ValidationError when body is not a Buffer', async () => {
      const req = makeReqWithContentType('text/vtt', 'plain string');
      const res = makeRes();
      await expect(captionsController.uploadCaption(req, res))
        .rejects.toBeInstanceOf(ValidationError);
      expect(captionService.uploadCaption).not.toHaveBeenCalled();
    });

    it('throws ValidationError when body is an empty Buffer', async () => {
      const req = makeReqWithContentType('text/vtt', Buffer.alloc(0));
      const res = makeRes();
      await expect(captionsController.uploadCaption(req, res))
        .rejects.toBeInstanceOf(ValidationError);
      expect(captionService.uploadCaption).not.toHaveBeenCalled();
    });

    it('returns 413 when body size exceeds CAPTION_MAX_BYTES', async () => {
      const oversized = Buffer.alloc(CAPTION_MAX_BYTES + 1);
      const req = makeReqWithContentType('text/vtt', oversized);
      const res = makeRes();
      await captionsController.uploadCaption(req, res);
      expect(res.status).toHaveBeenCalledWith(413);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: 'PAYLOAD_TOO_LARGE' }),
      );
      expect(captionService.uploadCaption).not.toHaveBeenCalled();
    });

    it('returns 200 with summary on happy path (text/vtt)', async () => {
      const uploadedAt = new Date('2025-01-01T00:00:00.000Z');
      (captionService.uploadCaption as jest.Mock).mockResolvedValueOnce({
        language: 'en',
        bytes: 128,
        uploadedAt,
      });

      const req = makeReqWithContentType('text/vtt', Buffer.from('WEBVTT\n\n00:00.000 --> 00:01.000\nHello'));
      const res = makeRes();

      await captionsController.uploadCaption(req, res);

      expect(captionService.uploadCaption).toHaveBeenCalledWith(
        expect.objectContaining({
          videoId: VIDEO_ID,
          language: 'en',
          contentType: 'text/vtt',
          userId: USER_ID,
          role: 'COURSE_DESIGNER',
        }),
      );
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        language: 'en',
        bytes: 128,
        uploadedAt,
      });
    });

    it('passes setDefault=true to service when query ?setDefault=1', async () => {
      const uploadedAt = new Date();
      (captionService.uploadCaption as jest.Mock).mockResolvedValueOnce({
        language: 'fr',
        bytes: 64,
        uploadedAt,
      });

      const req = makeReqWithContentType(
        'text/vtt',
        Buffer.from('WEBVTT\n'),
        { language: 'fr', setDefault: '1' },
      );
      const res = makeRes();

      await captionsController.uploadCaption(req, res);

      expect(captionService.uploadCaption).toHaveBeenCalledWith(
        expect.objectContaining({ setDefault: true, language: 'fr' }),
      );
    });

    it('accepts text/vtt; charset=utf-8 (charset suffix stripped)', async () => {
      const uploadedAt = new Date();
      (captionService.uploadCaption as jest.Mock).mockResolvedValueOnce({
        language: 'en',
        bytes: 32,
        uploadedAt,
      });

      const req = makeReqWithContentType('text/vtt; charset=utf-8', Buffer.alloc(32));
      const res = makeRes();

      await captionsController.uploadCaption(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      // contentType passed to the service should be stripped form
      expect(captionService.uploadCaption).toHaveBeenCalledWith(
        expect.objectContaining({ contentType: 'text/vtt' }),
      );
    });
  });

  // -------------------------------------------------------------------------
  // listCaptions
  // -------------------------------------------------------------------------
  describe('listCaptions', () => {
    it('throws UnauthorizedError when req.user is missing', async () => {
      const req = makeReq({ user: undefined });
      const res = makeRes();
      await expect(captionsController.listCaptions(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
      expect(captionService.listCaptions).not.toHaveBeenCalled();
    });

    it('returns 200 with captions array on happy path', async () => {
      const row = { language: 'en', bytes: 512, uploadedAt: new Date() };
      (captionService.listCaptions as jest.Mock).mockResolvedValueOnce([row]);

      const req = makeReq();
      const res = makeRes();

      await captionsController.listCaptions(req, res);

      expect(captionService.listCaptions).toHaveBeenCalledWith(VIDEO_ID, USER_ID, 'COURSE_DESIGNER');
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({ captions: [row] });
    });
  });

  // -------------------------------------------------------------------------
  // deleteCaption
  // -------------------------------------------------------------------------
  describe('deleteCaption', () => {
    it('throws UnauthorizedError when req.user is missing', async () => {
      const req = makeReq({ user: undefined, params: { id: VIDEO_ID, language: 'en' } });
      const res = makeRes();
      await expect(captionsController.deleteCaption(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
      expect(captionService.deleteCaption).not.toHaveBeenCalled();
    });

    it('parses :language from params, calls service, and returns 204', async () => {
      (captionService.deleteCaption as jest.Mock).mockResolvedValueOnce(undefined);

      const req = makeReq({ params: { id: VIDEO_ID, language: 'fr' } });
      const res = makeRes();

      await captionsController.deleteCaption(req, res);

      expect(captionService.deleteCaption).toHaveBeenCalledWith(
        VIDEO_ID,
        'fr',
        USER_ID,
        'COURSE_DESIGNER',
      );
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
