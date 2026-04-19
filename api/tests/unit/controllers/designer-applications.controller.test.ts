import '@tests/unit/setup';

jest.mock('@/services/designer-application.service', () => ({
  designerApplicationService: {
    applyAsLearner: jest.fn(),
    list: jest.fn(),
    review: jest.fn(),
  },
}));

import type { Request, Response } from 'express';
import { ZodError } from 'zod';
import * as controller from '@/controllers/designer-applications.controller';
import { designerApplicationService } from '@/services/designer-application.service';
import { UnauthorizedError } from '@/utils/errors';

const USER_ID = '11111111-1111-4111-8111-111111111111';
const APP_ID = '22222222-2222-4222-8222-222222222222';

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

describe('designer-applications.controller', () => {
  beforeEach(() => jest.clearAllMocks());

  it('apply returns 201', async () => {
    (designerApplicationService.applyAsLearner as jest.Mock).mockResolvedValueOnce({
      id: APP_ID,
    });
    const req = makeReq({ body: { note: 'hi' } });
    const res = makeRes();
    await controller.apply(req, res);
    expect(res.status).toHaveBeenCalledWith(201);
  });

  it('apply 401 when unauthenticated', async () => {
    const req = makeReq({ user: undefined });
    const res = makeRes();
    await expect(controller.apply(req, res)).rejects.toBeInstanceOf(UnauthorizedError);
  });

  it('adminList returns 200', async () => {
    (designerApplicationService.list as jest.Mock).mockResolvedValueOnce({
      items: [],
      nextCursor: null,
      hasMore: false,
    });
    const req = makeReq({ query: {} });
    const res = makeRes();
    await controller.adminList(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('adminReview returns 200', async () => {
    (designerApplicationService.review as jest.Mock).mockResolvedValueOnce({
      id: APP_ID,
      status: 'APPROVED',
    });
    const req = makeReq({
      params: { id: APP_ID },
      body: { status: 'APPROVED' },
    });
    const res = makeRes();
    await controller.adminReview(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('adminReview rejects bad status in body', async () => {
    const req = makeReq({
      params: { id: APP_ID },
      body: { status: 'WAITING' },
    });
    const res = makeRes();
    await expect(controller.adminReview(req, res)).rejects.toBeInstanceOf(ZodError);
  });
});
