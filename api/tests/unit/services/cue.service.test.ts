import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import { createCueService } from '@/services/cue.service';
import {
  ForbiddenError,
  NotFoundError,
  NotImplementedError,
  ValidationError,
} from '@/utils/errors';

type MockPrisma = {
  video: { findUnique: jest.Mock };
  cue: {
    aggregate: jest.Mock;
    create: jest.Mock;
    findMany: jest.Mock;
    findUnique: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
  };
};

function buildMockPrisma(): MockPrisma {
  return {
    video: { findUnique: jest.fn() },
    cue: {
      aggregate: jest.fn(),
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
  };
}

const VIDEO_ID = '11111111-1111-4111-8111-111111111111';
const COURSE_ID = '22222222-2222-4222-8222-222222222222';
const OWNER_ID = '33333333-3333-4333-8333-333333333333';
const COLLAB_ID = '44444444-4444-4444-8444-444444444444';
const STRANGER_ID = '55555555-5555-4555-8555-555555555555';
const ADMIN_ID = '66666666-6666-4666-8666-666666666666';
const CUE_ID = '77777777-7777-4777-8777-777777777777';

function videoAuthRow(
  opts: { ownerId?: string; collaboratorIds?: string[]; enrolleeIds?: string[] } = {},
) {
  return {
    id: VIDEO_ID,
    courseId: COURSE_ID,
    course: {
      ownerId: opts.ownerId ?? OWNER_ID,
      collaborators: (opts.collaboratorIds ?? []).map((userId) => ({ userId })),
      enrollments: (opts.enrolleeIds ?? []).map((userId) => ({ userId })),
    },
  };
}

function mcqInput(overrides: Record<string, unknown> = {}) {
  return {
    atMs: 5000,
    type: 'MCQ' as const,
    payload: {
      question: 'q',
      choices: ['a', 'b'],
      answerIndex: 0,
    },
    ...overrides,
  };
}

describe('cue.service', () => {
  describe('createCue', () => {
    it('owner can create', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      prisma.cue.aggregate.mockResolvedValue({ _max: { orderIndex: null } });
      prisma.cue.create.mockResolvedValue({ id: CUE_ID });
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCue(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER', mcqInput()),
      ).resolves.toEqual({ id: CUE_ID });
      expect(prisma.cue.create).toHaveBeenCalledTimes(1);
      const args = prisma.cue.create.mock.calls[0][0];
      expect(args.data.orderIndex).toBe(0);
      expect(args.data.pause).toBe(true);
      expect(args.data.atMs).toBe(5000);
    });

    it('collaborator can create', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(
        videoAuthRow({ collaboratorIds: [COLLAB_ID] }),
      );
      prisma.cue.aggregate.mockResolvedValue({ _max: { orderIndex: null } });
      prisma.cue.create.mockResolvedValue({ id: CUE_ID });
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCue(VIDEO_ID, COLLAB_ID, 'COURSE_DESIGNER', mcqInput()),
      ).resolves.toBeDefined();
    });

    it('admin can create', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      prisma.cue.aggregate.mockResolvedValue({ _max: { orderIndex: null } });
      prisma.cue.create.mockResolvedValue({ id: CUE_ID });
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCue(VIDEO_ID, ADMIN_ID, 'ADMIN', mcqInput()),
      ).resolves.toBeDefined();
    });

    it('non-owner designer gets 403', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCue(VIDEO_ID, STRANGER_ID, 'COURSE_DESIGNER', mcqInput()),
      ).rejects.toBeInstanceOf(ForbiddenError);
      expect(prisma.cue.create).not.toHaveBeenCalled();
    });

    it('learner gets 403', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow({ enrolleeIds: [STRANGER_ID] }));
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCue(VIDEO_ID, STRANGER_ID, 'LEARNER', mcqInput()),
      ).rejects.toBeInstanceOf(ForbiddenError);
    });

    it('missing video -> 404', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(null);
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCue(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER', mcqInput()),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('VOICE cues are rejected with NotImplementedError', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCue(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER', {
          atMs: 0,
          type: 'VOICE',
          payload: {},
        }),
      ).rejects.toBeInstanceOf(NotImplementedError);
      expect(prisma.cue.create).not.toHaveBeenCalled();
    });

    it('invalid payload -> ValidationError', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCue(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER', {
          atMs: 0,
          type: 'MCQ',
          payload: { question: 'q', choices: ['a', 'b'], answerIndex: 5 },
        }),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('negative atMs rejected', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.createCue(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER', mcqInput({ atMs: -1 })),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('computes orderIndex = max + 1 when not provided', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      prisma.cue.aggregate.mockResolvedValue({ _max: { orderIndex: 4 } });
      prisma.cue.create.mockResolvedValue({ id: CUE_ID });
      const svc = createCueService(prisma as unknown as PrismaClient);

      await svc.createCue(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER', mcqInput());
      const args = prisma.cue.create.mock.calls[0][0];
      expect(args.data.orderIndex).toBe(5);
    });

    it('respects explicit orderIndex', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      prisma.cue.create.mockResolvedValue({ id: CUE_ID });
      const svc = createCueService(prisma as unknown as PrismaClient);

      await svc.createCue(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER', mcqInput({ orderIndex: 99 }));
      const args = prisma.cue.create.mock.calls[0][0];
      expect(args.data.orderIndex).toBe(99);
      expect(prisma.cue.aggregate).not.toHaveBeenCalled();
    });
  });

  describe('listCuesForVideo', () => {
    it('owner can list', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      prisma.cue.findMany.mockResolvedValue([]);
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(svc.listCuesForVideo(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER'))
        .resolves.toEqual([]);
    });

    it('collaborator can list', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow({ collaboratorIds: [COLLAB_ID] }));
      prisma.cue.findMany.mockResolvedValue([]);
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(svc.listCuesForVideo(VIDEO_ID, COLLAB_ID, 'COURSE_DESIGNER'))
        .resolves.toEqual([]);
    });

    it('enrolled learner can list', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow({ enrolleeIds: [STRANGER_ID] }));
      prisma.cue.findMany.mockResolvedValue([]);
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(svc.listCuesForVideo(VIDEO_ID, STRANGER_ID, 'LEARNER'))
        .resolves.toEqual([]);
    });

    it('admin can list', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      prisma.cue.findMany.mockResolvedValue([]);
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(svc.listCuesForVideo(VIDEO_ID, ADMIN_ID, 'ADMIN'))
        .resolves.toEqual([]);
    });

    it('stranger gets 403', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(videoAuthRow());
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(svc.listCuesForVideo(VIDEO_ID, STRANGER_ID, 'LEARNER'))
        .rejects.toBeInstanceOf(ForbiddenError);
    });

    it('missing video 404', async () => {
      const prisma = buildMockPrisma();
      prisma.video.findUnique.mockResolvedValue(null);
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(svc.listCuesForVideo(VIDEO_ID, OWNER_ID, 'COURSE_DESIGNER'))
        .rejects.toBeInstanceOf(NotFoundError);
    });
  });

  describe('updateCue', () => {
    function cueRow(
      opts: { ownerId?: string; collaboratorIds?: string[]; type?: 'MCQ' | 'BLANKS' | 'MATCHING' | 'VOICE' } = {},
    ) {
      return {
        id: CUE_ID,
        type: opts.type ?? ('MCQ' as const),
        video: {
          id: VIDEO_ID,
          course: {
            ownerId: opts.ownerId ?? OWNER_ID,
            collaborators: (opts.collaboratorIds ?? []).map((userId) => ({ userId })),
          },
        },
      };
    }

    it('owner can patch atMs', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(cueRow());
      prisma.cue.update.mockResolvedValue({ id: CUE_ID, atMs: 10000 });
      const svc = createCueService(prisma as unknown as PrismaClient);

      await svc.updateCue(CUE_ID, OWNER_ID, 'COURSE_DESIGNER', { atMs: 10000 });
      expect(prisma.cue.update).toHaveBeenCalledWith({
        where: { id: CUE_ID },
        data: { atMs: 10000 },
      });
    });

    it('rejects type change with ValidationError', async () => {
      const prisma = buildMockPrisma();
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateCue(CUE_ID, OWNER_ID, 'COURSE_DESIGNER', { type: 'BLANKS' }),
      ).rejects.toBeInstanceOf(ValidationError);
      expect(prisma.cue.findUnique).not.toHaveBeenCalled();
    });

    it('validates new payload against existing cue.type', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(cueRow({ type: 'MCQ' }));
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.updateCue(CUE_ID, OWNER_ID, 'COURSE_DESIGNER', {
          payload: { question: 'q', choices: ['a', 'b'], answerIndex: 5 },
        }),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('non-owner designer gets 403', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(cueRow());
      const svc = createCueService(prisma as unknown as PrismaClient);

      await expect(
        svc.updateCue(CUE_ID, STRANGER_ID, 'COURSE_DESIGNER', { atMs: 10 }),
      ).rejects.toBeInstanceOf(ForbiddenError);
    });

    it('missing cue -> 404', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(null);
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateCue(CUE_ID, OWNER_ID, 'COURSE_DESIGNER', { atMs: 10 }),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('rejects negative atMs', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(cueRow());
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateCue(CUE_ID, OWNER_ID, 'COURSE_DESIGNER', { atMs: -1 }),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('rejects negative orderIndex', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(cueRow());
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(
        svc.updateCue(CUE_ID, OWNER_ID, 'COURSE_DESIGNER', { orderIndex: -1 }),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('admin can patch any cue', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(cueRow());
      prisma.cue.update.mockResolvedValue({ id: CUE_ID });
      const svc = createCueService(prisma as unknown as PrismaClient);

      await svc.updateCue(CUE_ID, ADMIN_ID, 'ADMIN', { pause: false });
      expect(prisma.cue.update).toHaveBeenCalledWith({
        where: { id: CUE_ID },
        data: { pause: false },
      });
    });
  });

  describe('deleteCue', () => {
    function cueRow(opts: { ownerId?: string; collaboratorIds?: string[] } = {}) {
      return {
        id: CUE_ID,
        video: {
          course: {
            ownerId: opts.ownerId ?? OWNER_ID,
            collaborators: (opts.collaboratorIds ?? []).map((userId) => ({ userId })),
          },
        },
      };
    }

    it('owner can delete', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(cueRow());
      prisma.cue.delete.mockResolvedValue({});
      const svc = createCueService(prisma as unknown as PrismaClient);
      await svc.deleteCue(CUE_ID, OWNER_ID, 'COURSE_DESIGNER');
      expect(prisma.cue.delete).toHaveBeenCalledWith({ where: { id: CUE_ID } });
    });

    it('stranger gets 403', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(cueRow());
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(
        svc.deleteCue(CUE_ID, STRANGER_ID, 'COURSE_DESIGNER'),
      ).rejects.toBeInstanceOf(ForbiddenError);
    });

    it('missing -> 404', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(null);
      const svc = createCueService(prisma as unknown as PrismaClient);
      await expect(
        svc.deleteCue(CUE_ID, OWNER_ID, 'COURSE_DESIGNER'),
      ).rejects.toBeInstanceOf(NotFoundError);
    });
  });
});
