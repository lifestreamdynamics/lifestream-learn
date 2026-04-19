import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import { createAttemptService } from '@/services/attempt.service';
import { ForbiddenError, NotFoundError, ValidationError } from '@/utils/errors';

type MockPrisma = {
  cue: { findUnique: jest.Mock };
  attempt: { create: jest.Mock; findMany: jest.Mock };
};

function buildMockPrisma(): MockPrisma {
  return {
    cue: { findUnique: jest.fn() },
    attempt: { create: jest.fn(), findMany: jest.fn() },
  };
}

const USER_ID = '11111111-1111-4111-8111-111111111111';
const OWNER_ID = '22222222-2222-4222-8222-222222222222';
const COLLAB_ID = '33333333-3333-4333-8333-333333333333';
const STRANGER_ID = '44444444-4444-4444-8444-444444444444';
const ADMIN_ID = '55555555-5555-4555-8555-555555555555';
const CUE_ID = '66666666-6666-4666-8666-666666666666';
const VIDEO_ID = '77777777-7777-4777-8777-777777777777';

function mcqCueRow(
  opts: {
    ownerId?: string;
    collaboratorIds?: string[];
    enrolleeIds?: string[];
    answerIndex?: number;
  } = {},
) {
  return {
    id: CUE_ID,
    type: 'MCQ' as const,
    videoId: VIDEO_ID,
    payload: {
      question: 'q',
      choices: ['a', 'b', 'c', 'd'],
      answerIndex: opts.answerIndex ?? 1,
      explanation: 'expl',
    },
    video: {
      courseId: 'ccc',
      course: {
        ownerId: opts.ownerId ?? OWNER_ID,
        collaborators: (opts.collaboratorIds ?? []).map((userId) => ({ userId })),
        enrollments: (opts.enrolleeIds ?? []).map((userId) => ({ userId })),
      },
    },
  };
}

function blanksCueRow(
  opts: { enrolleeIds?: string[] } = {},
) {
  return {
    id: CUE_ID,
    type: 'BLANKS' as const,
    videoId: VIDEO_ID,
    payload: {
      type: 'BLANKS',
      sentenceTemplate: '{{0}}',
      blanks: [{ accept: ['yes'] }],
    },
    video: {
      courseId: 'ccc',
      course: {
        ownerId: OWNER_ID,
        collaborators: [],
        enrollments: (opts.enrolleeIds ?? []).map((userId) => ({ userId })),
      },
    },
  };
}

describe('attempt.service', () => {
  describe('submitAttempt', () => {
    it('enrolled learner can submit an MCQ attempt; correct path', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(
        mcqCueRow({ enrolleeIds: [USER_ID], answerIndex: 2 }),
      );
      prisma.attempt.create.mockResolvedValue({ id: 'a', correct: true });
      const svc = createAttemptService(prisma as unknown as PrismaClient);

      const out = await svc.submitAttempt(CUE_ID, USER_ID, 'LEARNER', { choiceIndex: 2 });
      expect(out.correct).toBe(true);
      expect(out.scoreJson).toEqual({ selected: 2 });
      expect(out.explanation).toBe('expl');
      const args = prisma.attempt.create.mock.calls[0][0];
      expect(args.data).toMatchObject({
        userId: USER_ID,
        videoId: VIDEO_ID,
        cueId: CUE_ID,
        correct: true,
      });
    });

    it('enrolled learner submit MCQ incorrect', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(
        mcqCueRow({ enrolleeIds: [USER_ID], answerIndex: 2 }),
      );
      prisma.attempt.create.mockResolvedValue({ id: 'a', correct: false });
      const svc = createAttemptService(prisma as unknown as PrismaClient);

      const out = await svc.submitAttempt(CUE_ID, USER_ID, 'LEARNER', { choiceIndex: 0 });
      expect(out.correct).toBe(false);
      expect(out.explanation).toBe('expl');
    });

    it('owner may submit without enrollment', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(mcqCueRow({ ownerId: OWNER_ID }));
      prisma.attempt.create.mockResolvedValue({ id: 'a', correct: true });
      const svc = createAttemptService(prisma as unknown as PrismaClient);

      await expect(
        svc.submitAttempt(CUE_ID, OWNER_ID, 'COURSE_DESIGNER', { choiceIndex: 1 }),
      ).resolves.toBeDefined();
    });

    it('collaborator may submit without enrollment', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(mcqCueRow({ collaboratorIds: [COLLAB_ID] }));
      prisma.attempt.create.mockResolvedValue({ id: 'a', correct: true });
      const svc = createAttemptService(prisma as unknown as PrismaClient);
      await expect(
        svc.submitAttempt(CUE_ID, COLLAB_ID, 'COURSE_DESIGNER', { choiceIndex: 1 }),
      ).resolves.toBeDefined();
    });

    it('admin may submit on any cue', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(mcqCueRow());
      prisma.attempt.create.mockResolvedValue({ id: 'a', correct: true });
      const svc = createAttemptService(prisma as unknown as PrismaClient);
      await expect(
        svc.submitAttempt(CUE_ID, ADMIN_ID, 'ADMIN', { choiceIndex: 1 }),
      ).resolves.toBeDefined();
    });

    it('non-enrolled learner stranger -> 403', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(mcqCueRow());
      const svc = createAttemptService(prisma as unknown as PrismaClient);

      await expect(
        svc.submitAttempt(CUE_ID, STRANGER_ID, 'LEARNER', { choiceIndex: 0 }),
      ).rejects.toBeInstanceOf(ForbiddenError);
      expect(prisma.attempt.create).not.toHaveBeenCalled();
    });

    it('missing cue -> 404', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(null);
      const svc = createAttemptService(prisma as unknown as PrismaClient);
      await expect(
        svc.submitAttempt(CUE_ID, USER_ID, 'LEARNER', { choiceIndex: 0 }),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('invalid response shape -> ValidationError', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(mcqCueRow({ enrolleeIds: [USER_ID] }));
      const svc = createAttemptService(prisma as unknown as PrismaClient);
      await expect(
        svc.submitAttempt(CUE_ID, USER_ID, 'LEARNER', { not: 'right' }),
      ).rejects.toBeInstanceOf(ValidationError);
    });

    it('BLANKS plumbing: answers flow through to grading', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(blanksCueRow({ enrolleeIds: [USER_ID] }));
      prisma.attempt.create.mockResolvedValue({ id: 'a', correct: true });
      const svc = createAttemptService(prisma as unknown as PrismaClient);

      const out = await svc.submitAttempt(CUE_ID, USER_ID, 'LEARNER', { answers: ['yes'] });
      expect(out.correct).toBe(true);
      expect(out.scoreJson).toEqual({ perBlank: [true] });
      expect(out.explanation).toBeUndefined();
    });

    it('never echoes answerIndex in the response (security)', async () => {
      const prisma = buildMockPrisma();
      prisma.cue.findUnique.mockResolvedValue(
        mcqCueRow({ enrolleeIds: [USER_ID], answerIndex: 2 }),
      );
      prisma.attempt.create.mockResolvedValue({ id: 'a', correct: false });
      const svc = createAttemptService(prisma as unknown as PrismaClient);

      const out = await svc.submitAttempt(CUE_ID, USER_ID, 'LEARNER', { choiceIndex: 0 });
      const serialized = JSON.stringify(out);
      expect(serialized).not.toContain('answerIndex');
    });
  });

  describe('listOwnAttempts', () => {
    it('filters by userId and optional videoId', async () => {
      const prisma = buildMockPrisma();
      prisma.attempt.findMany.mockResolvedValue([]);
      const svc = createAttemptService(prisma as unknown as PrismaClient);

      await svc.listOwnAttempts(USER_ID);
      expect(prisma.attempt.findMany).toHaveBeenCalledWith({
        where: { userId: USER_ID },
        orderBy: [{ submittedAt: 'desc' }],
      });

      await svc.listOwnAttempts(USER_ID, VIDEO_ID);
      expect(prisma.attempt.findMany).toHaveBeenLastCalledWith({
        where: { userId: USER_ID, videoId: VIDEO_ID },
        orderBy: [{ submittedAt: 'desc' }],
      });
    });
  });
});
