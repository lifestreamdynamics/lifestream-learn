import type { AppStatus, DesignerApplication, PrismaClient, Role } from '@prisma/client';
import { Prisma } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from '@/utils/errors';
import {
  decodeDesignerApplicationCursor,
  encodeDesignerApplicationCursor,
} from '@/validators/designer-application.validators';

export interface ListDesignerApplicationsOpts {
  status?: AppStatus;
  cursor?: string;
  limit?: number;
}

export interface ListDesignerApplicationsResult {
  items: DesignerApplication[];
  nextCursor: string | null;
  hasMore: boolean;
}

export interface DesignerApplicationService {
  applyAsLearner(
    userId: string,
    role: Role,
    note?: string,
  ): Promise<DesignerApplication>;
  list(opts: ListDesignerApplicationsOpts): Promise<ListDesignerApplicationsResult>;
  review(
    applicationId: string,
    reviewerId: string,
    input: { status: 'APPROVED' | 'REJECTED'; reviewerNote?: string },
  ): Promise<DesignerApplication>;
}

export function createDesignerApplicationService(
  prisma: PrismaClient = defaultPrisma,
): DesignerApplicationService {
  return {
    async applyAsLearner(userId, role, note) {
      // Only LEARNER may apply — existing designers and admins are already
      // above-or-at the target role, so an application would be nonsensical.
      if (role !== 'LEARNER') {
        throw new ForbiddenError('Only learners may apply to become designers');
      }

      // Schema has @unique userId, so "existing REJECTED → new application
      // is allowed" can't mean inserting a second row. Instead we update the
      // existing REJECTED row back to PENDING, clearing the previous review
      // fields. This preserves the audit trail in the UPDATED row (updatedAt
      // reflects the resubmission; reviewedBy/reviewedAt are nulled because
      // the new PENDING state hasn't been reviewed yet).
      const existing = await prisma.designerApplication.findUnique({
        where: { userId },
      });

      if (existing) {
        if (existing.status === 'PENDING') {
          throw new ConflictError('A pending application already exists');
        }
        if (existing.status === 'APPROVED') {
          // If a previous application was approved the user's role should
          // already be COURSE_DESIGNER, so the role check above normally
          // catches this — defensive guard for the rare case where the role
          // was manually reset.
          throw new ConflictError('User has already been approved as a designer');
        }
        // REJECTED — resurrect with a fresh note.
        return prisma.designerApplication.update({
          where: { userId },
          data: {
            status: 'PENDING',
            reviewedBy: null,
            reviewedAt: null,
            reviewerNote: null,
            note: note ?? null,
          },
        });
      }

      return prisma.designerApplication.create({
        data: {
          userId,
          status: 'PENDING',
          note: note ?? null,
        },
      });
    },

    async list(opts) {
      const limit = Math.min(opts.limit ?? 20, 50);
      const where: Prisma.DesignerApplicationWhereInput = {};
      if (opts.status) where.status = opts.status;

      if (opts.cursor) {
        const decoded = decodeDesignerApplicationCursor(opts.cursor);
        if (!decoded) throw new ValidationError('Invalid cursor');
        const prev: Prisma.DesignerApplicationWhereInput[] = where.AND
          ? Array.isArray(where.AND)
            ? where.AND
            : [where.AND]
          : [];
        where.AND = [
          ...prev,
          {
            OR: [
              { submittedAt: { lt: decoded.submittedAt } },
              { submittedAt: decoded.submittedAt, id: { lt: decoded.id } },
            ],
          },
        ];
      }

      const rows = await prisma.designerApplication.findMany({
        where,
        orderBy: [{ submittedAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      });

      const hasMore = rows.length > limit;
      const items = hasMore ? rows.slice(0, limit) : rows;
      const last = items[items.length - 1];
      const nextCursor = hasMore && last
        ? encodeDesignerApplicationCursor({
            submittedAt: last.submittedAt,
            id: last.id,
          })
        : null;

      return { items, nextCursor, hasMore };
    },

    async review(applicationId, reviewerId, input) {
      const app = await prisma.designerApplication.findUnique({
        where: { id: applicationId },
      });
      if (!app) throw new NotFoundError('Application not found');

      if (input.status === 'REJECTED') {
        // Simple update — no role flip.
        return prisma.designerApplication.update({
          where: { id: applicationId },
          data: {
            status: 'REJECTED',
            reviewedBy: reviewerId,
            reviewedAt: new Date(),
            reviewerNote: input.reviewerNote ?? null,
          },
        });
      }

      // APPROVED — atomic update of application + user role promotion.
      // Use $transaction so either both changes land or neither does. The
      // role is only promoted if the current role is LEARNER; we don't want
      // to downgrade an ADMIN to COURSE_DESIGNER just because someone
      // approves a dormant application.
      const [updated] = await prisma.$transaction([
        prisma.designerApplication.update({
          where: { id: applicationId },
          data: {
            status: 'APPROVED',
            reviewedBy: reviewerId,
            reviewedAt: new Date(),
            reviewerNote: input.reviewerNote ?? null,
          },
        }),
        prisma.user.updateMany({
          where: { id: app.userId, role: 'LEARNER' },
          data: { role: 'COURSE_DESIGNER' },
        }),
      ]);

      return updated;
    },
  };
}

export const designerApplicationService = createDesignerApplicationService();
