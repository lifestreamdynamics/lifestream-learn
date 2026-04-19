import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import { Prisma } from '@prisma/client';
import { createCourseService } from '@/services/course.service';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from '@/utils/errors';

type MockPrisma = {
  course: {
    create: jest.Mock;
    findMany: jest.Mock;
    findUnique: jest.Mock;
    update: jest.Mock;
  };
  video: { count: jest.Mock };
  user: { findUnique: jest.Mock };
  courseCollaborator: {
    findUnique: jest.Mock;
    create: jest.Mock;
    deleteMany: jest.Mock;
  };
};

function buildMockPrisma(): MockPrisma {
  return {
    course: {
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    video: { count: jest.fn() },
    user: { findUnique: jest.fn() },
    courseCollaborator: {
      findUnique: jest.fn(),
      create: jest.fn(),
      deleteMany: jest.fn(),
    },
  };
}

const OWNER_ID = '11111111-1111-4111-8111-111111111111';
const OTHER_DESIGNER_ID = '22222222-2222-4222-8222-222222222222';
const ADMIN_ID = '33333333-3333-4333-8333-333333333333';
const COURSE_ID = '44444444-4444-4444-8444-444444444444';
const LEARNER_ID = '55555555-5555-4555-8555-555555555555';

describe('course.service', () => {
  describe('createCourse', () => {
    it('designer can create (auto-generates slug when absent)', async () => {
      const prisma = buildMockPrisma();
      prisma.course.create.mockResolvedValueOnce({
        id: COURSE_ID,
        slug: 'hello-world-abcdef',
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);

      const res = await svc.createCourse(OWNER_ID, 'COURSE_DESIGNER', {
        title: 'Hello World',
        description: 'd',
      });

      expect(res.slug).toBe('hello-world-abcdef');
      const args = prisma.course.create.mock.calls[0][0];
      expect(args.data.title).toBe('Hello World');
      expect(args.data.ownerId).toBe(OWNER_ID);
      expect(args.data.slug).toMatch(/^hello-world-[0-9a-f]{6}$/);
    });

    it('admin can create', async () => {
      const prisma = buildMockPrisma();
      prisma.course.create.mockResolvedValueOnce({ id: COURSE_ID });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.createCourse(ADMIN_ID, 'ADMIN', { title: 't', description: 'd' }),
      ).resolves.toBeDefined();
    });

    it('learner is forbidden', async () => {
      const prisma = buildMockPrisma();
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.createCourse(LEARNER_ID, 'LEARNER', { title: 't', description: 'd' }),
      ).rejects.toBeInstanceOf(ForbiddenError);
      expect(prisma.course.create).not.toHaveBeenCalled();
    });

    it('retries on slug collision then gives up with ConflictError', async () => {
      const prisma = buildMockPrisma();
      const err = new Prisma.PrismaClientKnownRequestError('unique', {
        code: 'P2002',
        clientVersion: 'x',
      });
      prisma.course.create.mockRejectedValue(err);
      const svc = createCourseService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCourse(OWNER_ID, 'COURSE_DESIGNER', { title: 't', description: 'd' }),
      ).rejects.toBeInstanceOf(ConflictError);
      expect(prisma.course.create).toHaveBeenCalledTimes(5);
    });

    it('explicit slug: collision → single ConflictError (no retry)', async () => {
      const prisma = buildMockPrisma();
      const err = new Prisma.PrismaClientKnownRequestError('unique', {
        code: 'P2002',
        clientVersion: 'x',
      });
      prisma.course.create.mockRejectedValueOnce(err);
      const svc = createCourseService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCourse(OWNER_ID, 'COURSE_DESIGNER', {
          title: 't',
          description: 'd',
          slug: 'my-course',
        }),
      ).rejects.toBeInstanceOf(ConflictError);
      expect(prisma.course.create).toHaveBeenCalledTimes(1);
    });
  });

  describe('listCourses', () => {
    it('anonymous caller forces published=true', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findMany.mockResolvedValueOnce([]);
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await svc.listCourses(null, null, {});
      const args = prisma.course.findMany.mock.calls[0][0];
      expect(args.where.published).toBe(true);
    });

    it('anonymous caller may not use owned/enrolled', async () => {
      const prisma = buildMockPrisma();
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(svc.listCourses(null, null, { owned: true })).rejects.toBeInstanceOf(
        ForbiddenError,
      );
      await expect(
        svc.listCourses(null, null, { enrolled: true }),
      ).rejects.toBeInstanceOf(ForbiddenError);
    });

    it('hasMore + nextCursor computed for a full page', async () => {
      const prisma = buildMockPrisma();
      const now = new Date('2026-04-19T10:00:00Z');
      const rows = Array.from({ length: 21 }, (_, i) => ({
        id: `id-${i}`,
        createdAt: new Date(now.getTime() - i * 1000),
      }));
      prisma.course.findMany.mockResolvedValueOnce(rows);
      const svc = createCourseService(prisma as unknown as PrismaClient);
      const res = await svc.listCourses(OWNER_ID, 'COURSE_DESIGNER', { limit: 20 });
      expect(res.items).toHaveLength(20);
      expect(res.hasMore).toBe(true);
      expect(res.nextCursor).toBeTruthy();
    });

    it('invalid cursor rejected', async () => {
      const prisma = buildMockPrisma();
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.listCourses(OWNER_ID, 'COURSE_DESIGNER', { cursor: '%%garbage' }),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('passes owned filter when authenticated', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findMany.mockResolvedValueOnce([]);
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await svc.listCourses(OWNER_ID, 'COURSE_DESIGNER', { owned: true });
      const args = prisma.course.findMany.mock.calls[0][0];
      expect(args.where.ownerId).toBe(OWNER_ID);
    });
  });

  describe('getCourseById', () => {
    it('owner sees unpublished', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        videos: [],
        collaborators: [],
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.getCourseById(COURSE_ID, OWNER_ID, 'COURSE_DESIGNER'),
      ).resolves.toMatchObject({ id: COURSE_ID });
    });

    it('stranger sees 404 for unpublished', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        videos: [],
        collaborators: [],
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.getCourseById(COURSE_ID, LEARNER_ID, 'LEARNER'),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('anyone can see published', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: true,
        videos: [],
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(svc.getCourseById(COURSE_ID, null, null))
        .resolves.toMatchObject({ id: COURSE_ID });
    });

    it('missing row -> 404', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce(null);
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.getCourseById(COURSE_ID, OWNER_ID, 'COURSE_DESIGNER'),
      ).rejects.toBeInstanceOf(NotFoundError);
    });
  });

  describe('updateCourse', () => {
    it('owner can patch title', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      });
      prisma.course.update.mockResolvedValueOnce({ id: COURSE_ID, title: 'new' });
      const svc = createCourseService(prisma as unknown as PrismaClient);

      await svc.updateCourse(COURSE_ID, OWNER_ID, 'COURSE_DESIGNER', {
        title: 'new',
      });
      expect(prisma.course.update).toHaveBeenCalled();
    });

    it('non-owner forbidden', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateCourse(COURSE_ID, OTHER_DESIGNER_ID, 'COURSE_DESIGNER', {
          title: 'x',
        }),
      ).rejects.toBeInstanceOf(ForbiddenError);
    });

    it('slug collision -> ConflictError', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      });
      prisma.course.update.mockRejectedValueOnce(
        new Prisma.PrismaClientKnownRequestError('unique', {
          code: 'P2002',
          clientVersion: 'x',
        }),
      );
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateCourse(COURSE_ID, OWNER_ID, 'COURSE_DESIGNER', { slug: 'taken' }),
      ).rejects.toBeInstanceOf(ConflictError);
    });
  });

  describe('publishCourse', () => {
    it('owner + >=1 READY video succeeds', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      });
      prisma.video.count.mockResolvedValueOnce(2);
      prisma.course.update.mockResolvedValueOnce({ id: COURSE_ID, published: true });
      const svc = createCourseService(prisma as unknown as PrismaClient);

      await svc.publishCourse(COURSE_ID, OWNER_ID, 'COURSE_DESIGNER');
      expect(prisma.course.update).toHaveBeenCalledWith({
        where: { id: COURSE_ID },
        data: { published: true },
      });
    });

    it('no READY videos -> ConflictError', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      });
      prisma.video.count.mockResolvedValueOnce(0);
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.publishCourse(COURSE_ID, OWNER_ID, 'COURSE_DESIGNER'),
      ).rejects.toBeInstanceOf(ConflictError);
      expect(prisma.course.update).not.toHaveBeenCalled();
    });

    it('non-owner forbidden', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.publishCourse(COURSE_ID, OTHER_DESIGNER_ID, 'COURSE_DESIGNER'),
      ).rejects.toBeInstanceOf(ForbiddenError);
    });

    it('missing course -> 404', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce(null);
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.publishCourse(COURSE_ID, OWNER_ID, 'COURSE_DESIGNER'),
      ).rejects.toBeInstanceOf(NotFoundError);
    });
  });

  describe('addCollaborator', () => {
    function happyCourse() {
      return {
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      };
    }

    it('creates new row when absent (201-path, created=true)', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce(happyCourse());
      prisma.user.findUnique.mockResolvedValueOnce({
        id: OTHER_DESIGNER_ID,
        role: 'COURSE_DESIGNER',
      });
      prisma.courseCollaborator.findUnique.mockResolvedValueOnce(null);
      prisma.courseCollaborator.create.mockResolvedValueOnce({
        courseId: COURSE_ID,
        userId: OTHER_DESIGNER_ID,
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);

      const result = await svc.addCollaborator(
        COURSE_ID,
        OWNER_ID,
        'COURSE_DESIGNER',
        OTHER_DESIGNER_ID,
      );
      expect(result.created).toBe(true);
    });

    it('idempotent: existing row returns created=false', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce(happyCourse());
      prisma.user.findUnique.mockResolvedValueOnce({
        id: OTHER_DESIGNER_ID,
        role: 'COURSE_DESIGNER',
      });
      prisma.courseCollaborator.findUnique.mockResolvedValueOnce({
        courseId: COURSE_ID,
        userId: OTHER_DESIGNER_ID,
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);

      const result = await svc.addCollaborator(
        COURSE_ID,
        OWNER_ID,
        'COURSE_DESIGNER',
        OTHER_DESIGNER_ID,
      );
      expect(result.created).toBe(false);
      expect(prisma.courseCollaborator.create).not.toHaveBeenCalled();
    });

    it('rejects non-designer target with ValidationError', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce(happyCourse());
      prisma.user.findUnique.mockResolvedValueOnce({
        id: LEARNER_ID,
        role: 'LEARNER',
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.addCollaborator(COURSE_ID, OWNER_ID, 'COURSE_DESIGNER', LEARNER_ID),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('rejects missing target with ValidationError', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce(happyCourse());
      prisma.user.findUnique.mockResolvedValueOnce(null);
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.addCollaborator(COURSE_ID, OWNER_ID, 'COURSE_DESIGNER', LEARNER_ID),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('non-owner forbidden', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce(happyCourse());
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.addCollaborator(
          COURSE_ID,
          OTHER_DESIGNER_ID,
          'COURSE_DESIGNER',
          OTHER_DESIGNER_ID,
        ),
      ).rejects.toBeInstanceOf(ForbiddenError);
    });
  });

  describe('removeCollaborator', () => {
    it('owner can remove idempotently', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      });
      prisma.courseCollaborator.deleteMany.mockResolvedValueOnce({ count: 0 });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.removeCollaborator(
          COURSE_ID,
          OWNER_ID,
          'COURSE_DESIGNER',
          OTHER_DESIGNER_ID,
        ),
      ).resolves.toBeUndefined();
    });
  });

  describe('isCourseOwnerOrAdminOrCollaborator', () => {
    it('admin short-circuits true', async () => {
      const prisma = buildMockPrisma();
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.isCourseOwnerOrAdminOrCollaborator(COURSE_ID, ADMIN_ID, 'ADMIN'),
      ).resolves.toBe(true);
      expect(prisma.course.findUnique).not.toHaveBeenCalled();
    });

    it('returns true for owner', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.isCourseOwnerOrAdminOrCollaborator(
          COURSE_ID,
          OWNER_ID,
          'COURSE_DESIGNER',
        ),
      ).resolves.toBe(true);
    });

    it('returns false for unrelated user', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValueOnce({
        id: COURSE_ID,
        ownerId: OWNER_ID,
        published: false,
        collaborators: [],
      });
      const svc = createCourseService(prisma as unknown as PrismaClient);
      await expect(
        svc.isCourseOwnerOrAdminOrCollaborator(
          COURSE_ID,
          OTHER_DESIGNER_ID,
          'COURSE_DESIGNER',
        ),
      ).resolves.toBe(false);
    });
  });
});
