import type { Enrollment, PrismaClient } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import {
  ConflictError,
  NotFoundError,
  ValidationError,
} from '@/utils/errors';

export interface CreateEnrollmentResult {
  enrollment: Enrollment;
  created: boolean;
}

export interface EnrollmentWithCourseSummary {
  id: string;
  userId: string;
  courseId: string;
  startedAt: Date;
  lastVideoId: string | null;
  lastPosMs: number | null;
  course: {
    id: string;
    title: string;
    slug: string;
    coverImageUrl: string | null;
  };
}

export interface EnrollmentService {
  createEnrollment(
    userId: string,
    courseId: string,
  ): Promise<CreateEnrollmentResult>;
  listOwnEnrollments(userId: string): Promise<EnrollmentWithCourseSummary[]>;
  updateProgress(
    userId: string,
    courseId: string,
    patch: { lastVideoId: string; lastPosMs: number },
  ): Promise<void>;
}

export function createEnrollmentService(
  prisma: PrismaClient = defaultPrisma,
): EnrollmentService {
  return {
    async createEnrollment(userId, courseId) {
      const course = await prisma.course.findUnique({
        where: { id: courseId },
        select: { id: true, published: true },
      });
      if (!course) throw new NotFoundError('Course not found');
      if (!course.published) {
        // 409: the course exists but isn't enrollable yet. A 403 would be
        // misleading — the caller has permission, the course is just in a
        // pre-publish state.
        throw new ConflictError('Course is not yet published');
      }

      // Idempotent on (userId, courseId).
      const existing = await prisma.enrollment.findUnique({
        where: { userId_courseId: { userId, courseId } },
      });
      if (existing) return { enrollment: existing, created: false };

      const enrollment = await prisma.enrollment.create({
        data: { userId, courseId },
      });
      return { enrollment, created: true };
    },

    async listOwnEnrollments(userId) {
      const rows = await prisma.enrollment.findMany({
        where: { userId },
        orderBy: [{ startedAt: 'desc' }],
        include: {
          course: {
            select: {
              id: true,
              title: true,
              slug: true,
              coverImageUrl: true,
            },
          },
        },
      });
      return rows.map((r) => ({
        id: r.id,
        userId: r.userId,
        courseId: r.courseId,
        startedAt: r.startedAt,
        lastVideoId: r.lastVideoId,
        lastPosMs: r.lastPosMs,
        course: r.course,
      }));
    },

    async updateProgress(userId, courseId, patch) {
      // Ensure the enrollment exists before we accept progress updates — an
      // unrolled user writing progress would be silently dropped otherwise.
      const enrollment = await prisma.enrollment.findUnique({
        where: { userId_courseId: { userId, courseId } },
        select: { id: true },
      });
      if (!enrollment) throw new NotFoundError('Enrollment not found');

      // The lastVideoId must belong to this course; we don't want the client
      // to point at a video from a different course as "last watched here".
      const video = await prisma.video.findUnique({
        where: { id: patch.lastVideoId },
        select: { courseId: true },
      });
      if (!video || video.courseId !== courseId) {
        throw new ValidationError('lastVideoId does not belong to this course');
      }

      await prisma.enrollment.update({
        where: { id: enrollment.id },
        data: {
          lastVideoId: patch.lastVideoId,
          lastPosMs: patch.lastPosMs,
        },
      });
    },
  };
}

export const enrollmentService = createEnrollmentService();
