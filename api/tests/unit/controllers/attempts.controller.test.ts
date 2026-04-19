import '@tests/unit/setup';

jest.mock('@/services/attempt.service', () => ({
  attemptService: {
    submitAttempt: jest.fn(),
    listOwnAttempts: jest.fn(),
  },
}));

import type { Request, Response } from 'express';
import { ZodError } from 'zod';
import * as attemptsController from '@/controllers/attempts.controller';
import { attemptService } from '@/services/attempt.service';
import { UnauthorizedError } from '@/utils/errors';

const USER_ID = '11111111-1111-4111-8111-111111111111';
const CUE_ID = '22222222-2222-4222-8222-222222222222';
const VIDEO_ID = '33333333-3333-4333-8333-333333333333';

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
    user: { id: USER_ID, role: 'LEARNER', email: 'u@example.com' },
    ...overrides,
  } as unknown as Request;
}

describe('attempts.controller', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('submit', () => {
    it('returns 201 with the grading result', async () => {
      (attemptService.submitAttempt as jest.Mock).mockResolvedValueOnce({
        attempt: { id: 'a' },
        correct: true,
        scoreJson: { selected: 1 },
        explanation: 'expl',
      });
      const req = makeReq({
        body: { cueId: CUE_ID, response: { choiceIndex: 1 } },
      });
      const res = makeRes();

      await attemptsController.submit(req, res);

      expect(attemptService.submitAttempt).toHaveBeenCalledWith(
        CUE_ID,
        USER_ID,
        'LEARNER',
        { choiceIndex: 1 },
      );
      expect(res.status).toHaveBeenCalledWith(201);
      const payload = (res.json as jest.Mock).mock.calls[0][0];
      expect(payload.correct).toBe(true);
      expect(payload.scoreJson).toEqual({ selected: 1 });
      expect(payload.explanation).toBe('expl');
    });

    it('throws UnauthorizedError when req.user is absent', async () => {
      const req = makeReq({ user: undefined });
      const res = makeRes();
      await expect(attemptsController.submit(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('throws ZodError on malformed body', async () => {
      const req = makeReq({ body: { cueId: 'not-a-uuid' } });
      const res = makeRes();
      await expect(attemptsController.submit(req, res)).rejects.toBeInstanceOf(ZodError);
    });
  });

  describe('listOwn', () => {
    it('returns 200 with attempts, no filter', async () => {
      (attemptService.listOwnAttempts as jest.Mock).mockResolvedValueOnce([]);
      const req = makeReq({ query: {} });
      const res = makeRes();

      await attemptsController.listOwn(req, res);
      expect(attemptService.listOwnAttempts).toHaveBeenCalledWith(USER_ID, undefined);
      expect(res.status).toHaveBeenCalledWith(200);
    });

    it('passes videoId filter through', async () => {
      (attemptService.listOwnAttempts as jest.Mock).mockResolvedValueOnce([]);
      const req = makeReq({ query: { videoId: VIDEO_ID } });
      const res = makeRes();

      await attemptsController.listOwn(req, res);
      expect(attemptService.listOwnAttempts).toHaveBeenCalledWith(USER_ID, VIDEO_ID);
    });

    it('throws UnauthorizedError when req.user is absent', async () => {
      const req = makeReq({ user: undefined });
      const res = makeRes();
      await expect(attemptsController.listOwn(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('throws ZodError on bad videoId query', async () => {
      const req = makeReq({ query: { videoId: 'not-a-uuid' } });
      const res = makeRes();
      await expect(attemptsController.listOwn(req, res)).rejects.toBeInstanceOf(ZodError);
    });
  });
});
