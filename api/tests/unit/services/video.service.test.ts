import '@tests/unit/setup';
import type { PrismaClient, Role } from '@prisma/client';
import { createVideoService } from '@/services/video.service';
import { ForbiddenError, NotFoundError } from '@/utils/errors';

type MockPrisma = {
  course: { findUnique: jest.Mock };
  video: {
    create: jest.Mock;
    findUnique: jest.Mock;
    update: jest.Mock;
  };
};

function buildMockPrisma(): MockPrisma {
  return {
    course: { findUnique: jest.fn() },
    video: {
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
  };
}

const COURSE_ID = '22222222-2222-4222-8222-222222222222';
const OWNER_ID = '33333333-3333-4333-8333-333333333333';
const COLLAB_ID = '44444444-4444-4444-8444-444444444444';
const ENROLLEE_ID = '55555555-5555-4555-8555-555555555555';
const STRANGER_ID = '66666666-6666-4666-8666-666666666666';
const ADMIN_ID = '77777777-7777-4777-8777-777777777777';
const VIDEO_ID = '88888888-8888-4888-8888-888888888888';

function fakeVideoRow(overrides: Record<string, unknown> = {}) {
  return {
    id: VIDEO_ID,
    courseId: COURSE_ID,
    title: 'Lesson',
    orderIndex: 0,
    status: 'UPLOADING' as const,
    durationMs: null,
    sourceKey: `uploads/${VIDEO_ID}`,
    hlsPrefix: null,
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
    ...overrides,
  };
}

describe('video.service', () => {
  describe('createVideo', () => {
    it('lets a course owner create a video', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValue({ ownerId: OWNER_ID, collaborators: [] });
      prisma.video.create.mockImplementation(({ data }) =>
        Promise.resolve(fakeVideoRow({ id: data.id, sourceKey: data.sourceKey, title: data.title, orderIndex: data.orderIndex })),
      );
      const svc = createVideoService(prisma as unknown as PrismaClient);

      const result = await svc.createVideo({
        courseId: COURSE_ID,
        title: 'L1',
        orderIndex: 0,
        userId: OWNER_ID,
        role: 'COURSE_DESIGNER',
      });

      expect(prisma.course.findUnique).toHaveBeenCalledWith({
        where: { id: COURSE_ID },
        select: {
          ownerId: true,
          collaborators: { where: { userId: OWNER_ID }, select: { userId: true } },
        },
      });
      expect(prisma.video.create).toHaveBeenCalledTimes(1);
      const createArgs = prisma.video.create.mock.calls[0][0];
      expect(createArgs.data.status).toBe('UPLOADING');
      expect(createArgs.data.courseId).toBe(COURSE_ID);
      // sourceKey must match the generated id so tusd writes to a predictable
      // location and the worker can find it.
      expect(createArgs.data.sourceKey).toBe(`uploads/${createArgs.data.id}`);
      expect(result.sourceKey).toBe(`uploads/${createArgs.data.id}`);
      expect(result.video.id).toBe(createArgs.data.id);
      expect(result.video.status).toBe('UPLOADING');
    });

    it('lets a collaborator create a video', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValue({
        ownerId: OWNER_ID,
        collaborators: [{ userId: COLLAB_ID }],
      });
      prisma.video.create.mockImplementation(({ data }) => Promise.resolve(fakeVideoRow({ id: data.id })));
      const svc = createVideoService(prisma as unknown as PrismaClient);

      await expect(
        svc.createVideo({
          courseId: COURSE_ID,
          title: 'L',
          orderIndex: 1,
          userId: COLLAB_ID,
          role: 'COURSE_DESIGNER',
        }),
      ).resolves.toBeDefined();
    });

    it('admins bypass owner/collaborator checks', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValue({ ownerId: OWNER_ID, collaborators: [] });
      prisma.video.create.mockImplementation(({ data }) => Promise.resolve(fakeVideoRow({ id: data.id })));
      const svc = createVideoService(prisma as unknown as PrismaClient);

      await expect(
        svc.createVideo({
          courseId: COURSE_ID,
          title: 'L',
          orderIndex: 0,
          userId: ADMIN_ID,
          role: 'ADMIN',
        }),
      ).resolves.toBeDefined();
    });

    it('throws ForbiddenError for a non-owner non-collaborator non-admin', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValue({ ownerId: OWNER_ID, collaborators: [] });
      const svc = createVideoService(prisma as unknown as PrismaClient);

      await expect(
        svc.createVideo({
          courseId: COURSE_ID,
          title: 'L',
          orderIndex: 0,
          userId: STRANGER_ID,
          role: 'COURSE_DESIGNER',
        }),
      ).rejects.toBeInstanceOf(ForbiddenError);
      expect(prisma.video.create).not.toHaveBeenCalled();
    });

    it('throws NotFoundError when the course does not exist', async () => {
      const prisma = buildMockPrisma();
      prisma.course.findUnique.mockResolvedValue(null);
      const svc = createVideoService(prisma as unknown as PrismaClient);

      await expect(
        svc.createVideo({
          courseId: COURSE_ID,
          title: 'L',
          orderIndex: 0,
          userId: OWNER_ID,
          role: 'COURSE_DESIGNER',
        }),
      ).rejects.toBeInstanceOf(NotFoundError);
      expect(prisma.video.create).not.toHaveBeenCalled();
    });
  });

  describe('canAccessVideo', () => {
    type Case = {
      name: string;
      role: Role;
      userId: string;
      videoRow: ReturnType<typeof fakeAccessRow> | null;
      expectedAllowed: boolean;
      expectedHasVideo: boolean;
    };

    function fakeAccessRow(opts: {
      ownerId?: string;
      collaboratorIds?: string[];
      enrolleeIds?: string[];
      status?: 'UPLOADING' | 'TRANSCODING' | 'READY' | 'FAILED';
    } = {}) {
      return {
        id: VIDEO_ID,
        status: opts.status ?? 'READY',
        hlsPrefix: 'vod/abc',
        courseId: COURSE_ID,
        course: {
          ownerId: opts.ownerId ?? OWNER_ID,
          collaborators: (opts.collaboratorIds ?? []).map((userId) => ({ userId })),
          enrollments: (opts.enrolleeIds ?? []).map((userId) => ({ userId })),
        },
      };
    }

    const cases: Case[] = [
      {
        name: 'admin always allowed',
        role: 'ADMIN',
        userId: ADMIN_ID,
        videoRow: fakeAccessRow({ ownerId: OWNER_ID }),
        expectedAllowed: true,
        expectedHasVideo: true,
      },
      {
        name: 'course owner allowed',
        role: 'COURSE_DESIGNER',
        userId: OWNER_ID,
        videoRow: fakeAccessRow({ ownerId: OWNER_ID }),
        expectedAllowed: true,
        expectedHasVideo: true,
      },
      {
        name: 'collaborator allowed',
        role: 'COURSE_DESIGNER',
        userId: COLLAB_ID,
        videoRow: fakeAccessRow({ collaboratorIds: [COLLAB_ID] }),
        expectedAllowed: true,
        expectedHasVideo: true,
      },
      {
        name: 'enrolled learner allowed',
        role: 'LEARNER',
        userId: ENROLLEE_ID,
        videoRow: fakeAccessRow({ enrolleeIds: [ENROLLEE_ID] }),
        expectedAllowed: true,
        expectedHasVideo: true,
      },
      {
        name: 'stranger learner rejected',
        role: 'LEARNER',
        userId: STRANGER_ID,
        videoRow: fakeAccessRow(),
        expectedAllowed: false,
        expectedHasVideo: true,
      },
      {
        name: 'missing video returns null video',
        role: 'LEARNER',
        userId: STRANGER_ID,
        videoRow: null,
        expectedAllowed: false,
        expectedHasVideo: false,
      },
    ];

    it.each(cases)('$name', async (c) => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(c.videoRow);
      const svc = createVideoService(prisma as unknown as PrismaClient);

      const out = await svc.canAccessVideo(c.userId, c.role, VIDEO_ID);
      expect(out.allowed).toBe(c.expectedAllowed);
      expect(out.video !== null).toBe(c.expectedHasVideo);
    });
  });

  describe('getVideoById', () => {
    it('throws NotFoundError when the video is missing', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(null);
      const svc = createVideoService(prisma as unknown as PrismaClient);

      await expect(svc.getVideoById(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER'))
        .rejects.toBeInstanceOf(NotFoundError);
    });

    it('throws ForbiddenError when not allowed', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue({
        id: VIDEO_ID,
        status: 'READY',
        hlsPrefix: 'p',
        courseId: COURSE_ID,
        course: { ownerId: OWNER_ID, collaborators: [], enrollments: [] },
      });
      const svc = createVideoService(prisma as unknown as PrismaClient);

      await expect(svc.getVideoById(VIDEO_ID, STRANGER_ID, 'LEARNER'))
        .rejects.toBeInstanceOf(ForbiddenError);
    });

    it('returns the public view for an allowed user', async () => {
      const prisma = buildMockPrisma();
      // First call (canAccessVideo) returns the access summary; second call
      // (refetch in getVideoById) returns the full row.
      prisma.video.findUnique
        .mockResolvedValueOnce({
          id: VIDEO_ID,
          status: 'READY',
          hlsPrefix: 'p',
          courseId: COURSE_ID,
          course: { ownerId: OWNER_ID, collaborators: [], enrollments: [] },
        })
        .mockResolvedValueOnce(fakeVideoRow({ status: 'READY' }));
      const svc = createVideoService(prisma as unknown as PrismaClient);

      const v = await svc.getVideoById(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER');
      expect(v).toEqual({
        id: VIDEO_ID,
        courseId: COURSE_ID,
        title: 'Lesson',
        orderIndex: 0,
        status: 'READY',
        durationMs: null,
        createdAt: expect.any(Date),
        updatedAt: expect.any(Date),
      });
    });

    it('throws NotFoundError if the row vanishes between access check and refetch', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique
        .mockResolvedValueOnce({
          id: VIDEO_ID,
          status: 'READY',
          hlsPrefix: 'p',
          courseId: COURSE_ID,
          course: { ownerId: OWNER_ID, collaborators: [], enrollments: [] },
        })
        .mockResolvedValueOnce(null);
      const svc = createVideoService(prisma as unknown as PrismaClient);

      await expect(svc.getVideoById(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER'))
        .rejects.toBeInstanceOf(NotFoundError);
    });
  });

  describe('markReady', () => {
    it('updates status to READY with hlsPrefix and durationMs', async () => {
      const prisma = buildMockPrisma();
      prisma.video.update.mockResolvedValue({});
      const svc = createVideoService(prisma as unknown as PrismaClient);

      await svc.markReady(VIDEO_ID, { hlsPrefix: 'vod/x', durationMs: 90_000 });
      expect(prisma.video.update).toHaveBeenCalledWith({
        where: { id: VIDEO_ID },
        data: { status: 'READY', hlsPrefix: 'vod/x', durationMs: 90_000 },
      });
    });
  });

  describe('markFailed', () => {
    it('updates status to FAILED', async () => {
      const prisma = buildMockPrisma();
      prisma.video.update.mockResolvedValue({});
      const svc = createVideoService(prisma as unknown as PrismaClient);

      await svc.markFailed(VIDEO_ID, 'ffmpeg crashed');
      expect(prisma.video.update).toHaveBeenCalledWith({
        where: { id: VIDEO_ID },
        data: { status: 'FAILED' },
      });
    });
  });
});
