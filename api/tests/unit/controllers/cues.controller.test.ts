import '@tests/unit/setup';

jest.mock('@/services/cue.service', () => ({
  cueService: {
    createCue: jest.fn(),
    listCuesForVideo: jest.fn(),
    updateCue: jest.fn(),
    deleteCue: jest.fn(),
  },
}));

import type { Request, Response } from 'express';
import { ZodError } from 'zod';
import * as cuesController from '@/controllers/cues.controller';
import { cueService } from '@/services/cue.service';
import { UnauthorizedError } from '@/utils/errors';

const VIDEO_ID = '11111111-1111-4111-8111-111111111111';
const CUE_ID = '22222222-2222-4222-8222-222222222222';
const USER_ID = '33333333-3333-4333-8333-333333333333';

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
    params: {},
    query: {},
    user: { id: USER_ID, role: 'COURSE_DESIGNER', email: 'u@example.com' },
    ...overrides,
  } as unknown as Request;
}

describe('cues.controller', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('createOnVideo', () => {
    it('returns 201 with the created cue', async () => {
      (cueService.createCue as jest.Mock).mockResolvedValueOnce({ id: CUE_ID });
      const req = makeReq({
        params: { id: VIDEO_ID },
        body: {
          atMs: 1000,
          type: 'MCQ',
          payload: { question: 'q', choices: ['a', 'b'], answerIndex: 0 },
        },
      });
      const res = makeRes();

      await cuesController.createOnVideo(req, res);

      expect(cueService.createCue).toHaveBeenCalledWith(
        VIDEO_ID,
        USER_ID,
        'COURSE_DESIGNER',
        expect.objectContaining({ atMs: 1000, type: 'MCQ' }),
      );
      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith({ id: CUE_ID });
    });

    it('throws UnauthorizedError when req.user is absent', async () => {
      const req = makeReq({ user: undefined, params: { id: VIDEO_ID } });
      const res = makeRes();
      await expect(cuesController.createOnVideo(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('throws ZodError on malformed body', async () => {
      const req = makeReq({
        params: { id: VIDEO_ID },
        body: { atMs: -1, type: 'NOPE', payload: null },
      });
      const res = makeRes();
      await expect(cuesController.createOnVideo(req, res)).rejects.toBeInstanceOf(ZodError);
      expect(cueService.createCue).not.toHaveBeenCalled();
    });

    it('throws ZodError on malformed params', async () => {
      const req = makeReq({
        params: { id: 'not-a-uuid' },
        body: { atMs: 0, type: 'MCQ', payload: {} },
      });
      const res = makeRes();
      await expect(cuesController.createOnVideo(req, res)).rejects.toBeInstanceOf(ZodError);
    });
  });

  describe('listForVideo', () => {
    it('returns 200 with cues', async () => {
      (cueService.listCuesForVideo as jest.Mock).mockResolvedValueOnce([{ id: CUE_ID }]);
      const req = makeReq({ params: { id: VIDEO_ID } });
      const res = makeRes();

      await cuesController.listForVideo(req, res);
      expect(cueService.listCuesForVideo).toHaveBeenCalledWith(
        VIDEO_ID,
        USER_ID,
        'COURSE_DESIGNER',
      );
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith([{ id: CUE_ID }]);
    });

    it('throws UnauthorizedError when req.user is absent', async () => {
      const req = makeReq({ user: undefined, params: { id: VIDEO_ID } });
      const res = makeRes();
      await expect(cuesController.listForVideo(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('updateById', () => {
    it('returns 200 with the updated cue', async () => {
      (cueService.updateCue as jest.Mock).mockResolvedValueOnce({ id: CUE_ID, atMs: 10 });
      const req = makeReq({ params: { id: CUE_ID }, body: { atMs: 10 } });
      const res = makeRes();

      await cuesController.updateById(req, res);
      expect(cueService.updateCue).toHaveBeenCalledWith(
        CUE_ID,
        USER_ID,
        'COURSE_DESIGNER',
        { atMs: 10 },
      );
      expect(res.status).toHaveBeenCalledWith(200);
    });

    it('throws UnauthorizedError when req.user is absent', async () => {
      const req = makeReq({ user: undefined, params: { id: CUE_ID } });
      const res = makeRes();
      await expect(cuesController.updateById(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('deleteById', () => {
    it('returns 204 on success', async () => {
      (cueService.deleteCue as jest.Mock).mockResolvedValueOnce(undefined);
      const req = makeReq({ params: { id: CUE_ID } });
      const res = makeRes();

      await cuesController.deleteById(req, res);
      expect(cueService.deleteCue).toHaveBeenCalledWith(CUE_ID, USER_ID, 'COURSE_DESIGNER');
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });

    it('throws UnauthorizedError when req.user is absent', async () => {
      const req = makeReq({ user: undefined, params: { id: CUE_ID } });
      const res = makeRes();
      await expect(cuesController.deleteById(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });
  });
});
