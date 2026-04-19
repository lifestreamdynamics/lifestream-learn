import '@tests/unit/setup';

jest.mock('@/services/course.service', () => ({
  courseService: {
    createCourse: jest.fn(),
    listCourses: jest.fn(),
    getCourseById: jest.fn(),
    updateCourse: jest.fn(),
    publishCourse: jest.fn(),
    addCollaborator: jest.fn(),
    removeCollaborator: jest.fn(),
  },
}));

import type { Request, Response } from 'express';
import { ZodError } from 'zod';
import * as coursesController from '@/controllers/courses.controller';
import { courseService } from '@/services/course.service';
import { UnauthorizedError } from '@/utils/errors';

const COURSE_ID = '11111111-1111-4111-8111-111111111111';
const USER_ID = '22222222-2222-4222-8222-222222222222';
const TARGET_ID = '33333333-3333-4333-8333-333333333333';

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

describe('courses.controller', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('create', () => {
    it('201 with new course', async () => {
      (courseService.createCourse as jest.Mock).mockResolvedValueOnce({
        id: COURSE_ID,
      });
      const req = makeReq({ body: { title: 't', description: 'd' } });
      const res = makeRes();
      await coursesController.create(req, res);
      expect(res.status).toHaveBeenCalledWith(201);
    });

    it('ZodError on malformed body', async () => {
      const req = makeReq({ body: { title: '' } });
      const res = makeRes();
      await expect(coursesController.create(req, res)).rejects.toBeInstanceOf(ZodError);
    });

    it('401 when unauthenticated', async () => {
      const req = makeReq({ user: undefined, body: { title: 't', description: 'd' } });
      const res = makeRes();
      await expect(coursesController.create(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('list', () => {
    it('200 with paginated result', async () => {
      (courseService.listCourses as jest.Mock).mockResolvedValueOnce({
        items: [],
        nextCursor: null,
        hasMore: false,
      });
      const req = makeReq({ query: {} });
      const res = makeRes();
      await coursesController.list(req, res);
      expect(res.status).toHaveBeenCalledWith(200);
    });

    it('passes null userId when unauthenticated', async () => {
      (courseService.listCourses as jest.Mock).mockResolvedValueOnce({
        items: [],
        nextCursor: null,
        hasMore: false,
      });
      const req = makeReq({ user: undefined, query: {} });
      const res = makeRes();
      await coursesController.list(req, res);
      expect(courseService.listCourses).toHaveBeenCalledWith(null, null, {});
    });
  });

  describe('getById', () => {
    it('200 with course', async () => {
      (courseService.getCourseById as jest.Mock).mockResolvedValueOnce({
        id: COURSE_ID,
      });
      const req = makeReq({ params: { id: COURSE_ID } });
      const res = makeRes();
      await coursesController.getById(req, res);
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('publish', () => {
    it('200 after publish', async () => {
      (courseService.publishCourse as jest.Mock).mockResolvedValueOnce({
        id: COURSE_ID,
        published: true,
      });
      const req = makeReq({ params: { id: COURSE_ID } });
      const res = makeRes();
      await coursesController.publish(req, res);
      expect(res.status).toHaveBeenCalledWith(200);
    });

    it('401 when unauthenticated', async () => {
      const req = makeReq({ user: undefined, params: { id: COURSE_ID } });
      const res = makeRes();
      await expect(coursesController.publish(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('addCollaborator', () => {
    it('201 on create', async () => {
      (courseService.addCollaborator as jest.Mock).mockResolvedValueOnce({
        collaborator: { userId: TARGET_ID },
        created: true,
      });
      const req = makeReq({
        params: { id: COURSE_ID },
        body: { userId: TARGET_ID },
      });
      const res = makeRes();
      await coursesController.addCollaborator(req, res);
      expect(res.status).toHaveBeenCalledWith(201);
    });

    it('200 on idempotent re-add', async () => {
      (courseService.addCollaborator as jest.Mock).mockResolvedValueOnce({
        collaborator: { userId: TARGET_ID },
        created: false,
      });
      const req = makeReq({
        params: { id: COURSE_ID },
        body: { userId: TARGET_ID },
      });
      const res = makeRes();
      await coursesController.addCollaborator(req, res);
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('removeCollaborator', () => {
    it('204', async () => {
      (courseService.removeCollaborator as jest.Mock).mockResolvedValueOnce(undefined);
      const req = makeReq({ params: { id: COURSE_ID, userId: TARGET_ID } });
      const res = makeRes();
      await coursesController.removeCollaborator(req, res);
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });

  describe('update', () => {
    it('200 on update', async () => {
      (courseService.updateCourse as jest.Mock).mockResolvedValueOnce({
        id: COURSE_ID,
      });
      const req = makeReq({
        params: { id: COURSE_ID },
        body: { title: 'new' },
      });
      const res = makeRes();
      await coursesController.update(req, res);
      expect(res.status).toHaveBeenCalledWith(200);
    });

    it('401 when unauthenticated', async () => {
      const req = makeReq({ user: undefined, params: { id: COURSE_ID } });
      const res = makeRes();
      await expect(coursesController.update(req, res))
        .rejects.toBeInstanceOf(UnauthorizedError);
    });
  });
});
