import '@tests/unit/setup';

jest.mock('@/services/analytics.service', () => ({
  analyticsService: {
    ingestEvents: jest.fn(),
    getCourseAggregate: jest.fn(),
  },
}));

import type { Request, Response } from 'express';
import * as controller from '@/controllers/analytics.controller';
import { analyticsService } from '@/services/analytics.service';
import { UnauthorizedError, ValidationError } from '@/utils/errors';

const USER_ID = '11111111-1111-4111-8111-111111111111';
const COURSE_ID = '22222222-2222-4222-8222-222222222222';

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

describe('analytics.controller', () => {
  beforeEach(() => jest.clearAllMocks());

  it('ingest returns 202', async () => {
    (analyticsService.ingestEvents as jest.Mock).mockResolvedValueOnce({ count: 1 });
    const req = makeReq({
      body: [
        { eventType: 'video_view', occurredAt: '2026-04-19T00:00:00.000Z' },
      ],
    });
    const res = makeRes();
    await controller.ingest(req, res);
    expect(res.status).toHaveBeenCalledWith(202);
    expect(res.json).toHaveBeenCalledWith({ ingested: 1 });
  });

  it('ingest rejects non-array body', async () => {
    const req = makeReq({ body: { eventType: 'x' } });
    const res = makeRes();
    await expect(controller.ingest(req, res)).rejects.toBeInstanceOf(ValidationError);
  });

  it('ingest 401 when unauthenticated', async () => {
    const req = makeReq({ user: undefined, body: [] });
    const res = makeRes();
    await expect(controller.ingest(req, res)).rejects.toBeInstanceOf(UnauthorizedError);
  });

  it('getCourseAggregate 200', async () => {
    (analyticsService.getCourseAggregate as jest.Mock).mockResolvedValueOnce({
      totalViews: 0,
      completionRate: 0,
      perCueTypeAccuracy: { MCQ: null, MATCHING: null, BLANKS: null, VOICE: null },
    });
    const req = makeReq({ params: { id: COURSE_ID } });
    const res = makeRes();
    await controller.getCourseAggregate(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
  });
});
