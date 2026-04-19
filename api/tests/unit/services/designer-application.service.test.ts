import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import { createDesignerApplicationService } from '@/services/designer-application.service';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
} from '@/utils/errors';

type MockPrisma = {
  designerApplication: {
    findUnique: jest.Mock;
    findMany: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
  };
  user: { updateMany: jest.Mock };
  $transaction: jest.Mock;
};

function buildMockPrisma(): MockPrisma {
  return {
    designerApplication: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    user: { updateMany: jest.fn() },
    $transaction: jest.fn(),
  };
}

const USER_ID = '11111111-1111-4111-8111-111111111111';
const APP_ID = '22222222-2222-4222-8222-222222222222';
const REVIEWER_ID = '33333333-3333-4333-8333-333333333333';

describe('designer-application.service', () => {
  describe('applyAsLearner', () => {
    it('non-learner forbidden', async () => {
      const prisma = buildMockPrisma();
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      await expect(svc.applyAsLearner(USER_ID, 'COURSE_DESIGNER'))
        .rejects.toBeInstanceOf(ForbiddenError);
      await expect(svc.applyAsLearner(USER_ID, 'ADMIN'))
        .rejects.toBeInstanceOf(ForbiddenError);
    });

    it('creates new application when none exists', async () => {
      const prisma = buildMockPrisma();
      prisma.designerApplication.findUnique.mockResolvedValueOnce(null);
      prisma.designerApplication.create.mockResolvedValueOnce({
        id: APP_ID,
        userId: USER_ID,
        status: 'PENDING',
      });
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      await svc.applyAsLearner(USER_ID, 'LEARNER', 'pls');
      expect(prisma.designerApplication.create).toHaveBeenCalled();
    });

    it('existing PENDING -> ConflictError', async () => {
      const prisma = buildMockPrisma();
      prisma.designerApplication.findUnique.mockResolvedValueOnce({
        id: APP_ID,
        userId: USER_ID,
        status: 'PENDING',
      });
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      await expect(svc.applyAsLearner(USER_ID, 'LEARNER'))
        .rejects.toBeInstanceOf(ConflictError);
    });

    it('existing APPROVED -> ConflictError (defensive)', async () => {
      const prisma = buildMockPrisma();
      prisma.designerApplication.findUnique.mockResolvedValueOnce({
        id: APP_ID,
        userId: USER_ID,
        status: 'APPROVED',
      });
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      await expect(svc.applyAsLearner(USER_ID, 'LEARNER'))
        .rejects.toBeInstanceOf(ConflictError);
    });

    it('existing REJECTED -> resurrects row to PENDING', async () => {
      const prisma = buildMockPrisma();
      prisma.designerApplication.findUnique.mockResolvedValueOnce({
        id: APP_ID,
        userId: USER_ID,
        status: 'REJECTED',
        reviewedBy: REVIEWER_ID,
      });
      prisma.designerApplication.update.mockResolvedValueOnce({
        id: APP_ID,
        userId: USER_ID,
        status: 'PENDING',
      });
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      const res = await svc.applyAsLearner(USER_ID, 'LEARNER', 'take 2');
      expect(res.status).toBe('PENDING');
      const args = prisma.designerApplication.update.mock.calls[0][0];
      expect(args.data.status).toBe('PENDING');
      expect(args.data.reviewedBy).toBeNull();
      expect(args.data.reviewerNote).toBeNull();
    });
  });

  describe('list', () => {
    it('filters by status when provided', async () => {
      const prisma = buildMockPrisma();
      prisma.designerApplication.findMany.mockResolvedValueOnce([]);
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      await svc.list({ status: 'PENDING' });
      const args = prisma.designerApplication.findMany.mock.calls[0][0];
      expect(args.where.status).toBe('PENDING');
    });

    it('computes hasMore and nextCursor', async () => {
      const prisma = buildMockPrisma();
      const rows = Array.from({ length: 3 }, (_, i) => ({
        id: `id-${i}`,
        submittedAt: new Date(Date.now() - i * 1000),
        status: 'PENDING' as const,
      }));
      prisma.designerApplication.findMany.mockResolvedValueOnce(rows);
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      const res = await svc.list({ limit: 2 });
      expect(res.items).toHaveLength(2);
      expect(res.hasMore).toBe(true);
      expect(res.nextCursor).toBeTruthy();
    });
  });

  describe('review', () => {
    it('missing app -> NotFoundError', async () => {
      const prisma = buildMockPrisma();
      prisma.designerApplication.findUnique.mockResolvedValueOnce(null);
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      await expect(
        svc.review(APP_ID, REVIEWER_ID, { status: 'APPROVED' }),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('REJECTED: simple update', async () => {
      const prisma = buildMockPrisma();
      prisma.designerApplication.findUnique.mockResolvedValueOnce({
        id: APP_ID,
        userId: USER_ID,
        status: 'PENDING',
      });
      prisma.designerApplication.update.mockResolvedValueOnce({
        id: APP_ID,
        status: 'REJECTED',
      });
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      const res = await svc.review(APP_ID, REVIEWER_ID, {
        status: 'REJECTED',
        reviewerNote: 'nope',
      });
      expect(res.status).toBe('REJECTED');
    });

    it('APPROVED: uses $transaction for app update + role promotion', async () => {
      const prisma = buildMockPrisma();
      prisma.designerApplication.findUnique.mockResolvedValueOnce({
        id: APP_ID,
        userId: USER_ID,
        status: 'PENDING',
      });
      const updatedApp = { id: APP_ID, status: 'APPROVED', userId: USER_ID };
      prisma.$transaction.mockResolvedValueOnce([updatedApp, { count: 1 }]);
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);

      const res = await svc.review(APP_ID, REVIEWER_ID, { status: 'APPROVED' });
      expect(res).toEqual(updatedApp);
      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
      const batch = prisma.$transaction.mock.calls[0][0];
      expect(Array.isArray(batch)).toBe(true);
      expect(batch).toHaveLength(2);
    });

    it('APPROVED with $transaction failure bubbles up (atomicity)', async () => {
      const prisma = buildMockPrisma();
      prisma.designerApplication.findUnique.mockResolvedValueOnce({
        id: APP_ID,
        userId: USER_ID,
        status: 'PENDING',
      });
      // Simulate the real Prisma behaviour: when $transaction rejects, both
      // writes should be rolled back. We assert that the *only* awaited
      // aggregate was the $transaction call — the service never short-circuits
      // and awaits the individual updates independently.
      prisma.$transaction.mockRejectedValueOnce(new Error('boom'));
      const svc = createDesignerApplicationService(prisma as unknown as PrismaClient);
      await expect(
        svc.review(APP_ID, REVIEWER_ID, { status: 'APPROVED' }),
      ).rejects.toThrow('boom');
      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    });
  });
});
