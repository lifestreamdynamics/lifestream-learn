import '@tests/unit/setup';

jest.mock('@/services/feed.service', () => ({
  feedService: { getFeed: jest.fn() },
}));

import type { Request, Response } from 'express';
import * as feedController from '@/controllers/feed.controller';
import { feedService } from '@/services/feed.service';
import { UnauthorizedError } from '@/utils/errors';

const USER_ID = '11111111-1111-4111-8111-111111111111';

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
    user: { id: USER_ID, role: 'LEARNER', email: 'u@example.com' },
    ...overrides,
  } as unknown as Request;
}

describe('feed.controller', () => {
  beforeEach(() => jest.clearAllMocks());

  it('200 with feed', async () => {
    (feedService.getFeed as jest.Mock).mockResolvedValueOnce({
      items: [],
      nextCursor: null,
      hasMore: false,
    });
    const req = makeReq({ query: {} });
    const res = makeRes();
    await feedController.getFeed(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('401 when unauthenticated', async () => {
    const req = makeReq({ user: undefined });
    const res = makeRes();
    await expect(feedController.getFeed(req, res))
      .rejects.toBeInstanceOf(UnauthorizedError);
  });
});
