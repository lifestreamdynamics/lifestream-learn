import '@tests/unit/setup';

jest.mock('@/services/enrollment.service', () => ({
  enrollmentService: {
    createEnrollment: jest.fn(),
    listOwnEnrollments: jest.fn(),
    updateProgress: jest.fn(),
  },
}));

import type { Request, Response } from 'express';
import * as enrollmentsController from '@/controllers/enrollments.controller';
import { enrollmentService } from '@/services/enrollment.service';
import { UnauthorizedError } from '@/utils/errors';

const USER_ID = '11111111-1111-4111-8111-111111111111';
const COURSE_ID = '22222222-2222-4222-8222-222222222222';
const VIDEO_ID = '33333333-3333-4333-8333-333333333333';

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

describe('enrollments.controller', () => {
  beforeEach(() => jest.clearAllMocks());

  it('create returns 201 on new', async () => {
    (enrollmentService.createEnrollment as jest.Mock).mockResolvedValueOnce({
      enrollment: { id: 'e1' },
      created: true,
    });
    const req = makeReq({ body: { courseId: COURSE_ID } });
    const res = makeRes();
    await enrollmentsController.create(req, res);
    expect(res.status).toHaveBeenCalledWith(201);
  });

  it('create returns 200 on idempotent re-enroll', async () => {
    (enrollmentService.createEnrollment as jest.Mock).mockResolvedValueOnce({
      enrollment: { id: 'e1' },
      created: false,
    });
    const req = makeReq({ body: { courseId: COURSE_ID } });
    const res = makeRes();
    await enrollmentsController.create(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('listOwn returns 200', async () => {
    (enrollmentService.listOwnEnrollments as jest.Mock).mockResolvedValueOnce([]);
    const req = makeReq();
    const res = makeRes();
    await enrollmentsController.listOwn(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('updateProgress returns 204', async () => {
    (enrollmentService.updateProgress as jest.Mock).mockResolvedValueOnce(undefined);
    const req = makeReq({
      params: { courseId: COURSE_ID },
      body: { lastVideoId: VIDEO_ID, lastPosMs: 1000 },
    });
    const res = makeRes();
    await enrollmentsController.updateProgress(req, res);
    expect(res.status).toHaveBeenCalledWith(204);
    expect(res.send).toHaveBeenCalled();
  });

  it('401 when unauthenticated', async () => {
    const req = makeReq({ user: undefined, body: { courseId: COURSE_ID } });
    const res = makeRes();
    await expect(enrollmentsController.create(req, res))
      .rejects.toBeInstanceOf(UnauthorizedError);
  });
});
