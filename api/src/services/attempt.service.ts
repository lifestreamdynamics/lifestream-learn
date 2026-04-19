import type { Attempt, PrismaClient, Role } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { ForbiddenError, NotFoundError } from '@/utils/errors';
import { parseResponseFor } from '@/validators/cue-payloads';
import { grade, type GradingResult } from '@/services/grading';

export interface SubmitAttemptResult {
  attempt: Attempt;
  correct: boolean;
  scoreJson: Record<string, unknown> | null;
  explanation?: string;
}

export interface AttemptService {
  submitAttempt(
    cueId: string,
    userId: string,
    role: Role,
    input: unknown,
  ): Promise<SubmitAttemptResult>;
  listOwnAttempts(userId: string, videoId?: string): Promise<Attempt[]>;
}

export function createAttemptService(
  prisma: PrismaClient = defaultPrisma,
): AttemptService {
  return {
    async submitAttempt(cueId, userId, role, input) {
      const cue = await prisma.cue.findUnique({
        where: { id: cueId },
        select: {
          id: true,
          type: true,
          payload: true,
          videoId: true,
          video: {
            select: {
              courseId: true,
              course: {
                select: {
                  ownerId: true,
                  collaborators: { where: { userId }, select: { userId: true } },
                  enrollments: { where: { userId }, select: { userId: true } },
                },
              },
            },
          },
        },
      });
      if (!cue) throw new NotFoundError('Cue not found');

      // Access gate: admin, course owner, collaborator, or enrolled learner.
      // Designers testing their own content should not be required to enrol.
      const isAdmin = role === 'ADMIN';
      const isOwner = cue.video.course.ownerId === userId;
      const isCollab = cue.video.course.collaborators.length > 0;
      const isEnrolled = cue.video.course.enrollments.length > 0;
      if (!isAdmin && !isOwner && !isCollab && !isEnrolled) {
        throw new ForbiddenError('You do not have access to this cue');
      }

      // Parse response against the cue's type — throws ValidationError (400).
      const response = parseResponseFor(cue.type, input);

      // Grade. `cue.payload` was validated on write; we cast through unknown.
      const result: GradingResult = grade(
        cue.type,
        cue.payload as unknown,
        response,
      );

      const attempt = await prisma.attempt.create({
        data: {
          userId,
          videoId: cue.videoId,
          cueId: cue.id,
          correct: result.correct,
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          scoreJson: (result.scoreJson ?? null) as any,
        },
      });

      // IMPORTANT: never echo cue.payload.answerIndex / .pairs. Only the
      // grading result goes back to the client.
      return {
        attempt,
        correct: result.correct,
        scoreJson: result.scoreJson,
        ...(result.explanation !== undefined ? { explanation: result.explanation } : {}),
      };
    },

    async listOwnAttempts(userId, videoId) {
      return prisma.attempt.findMany({
        where: {
          userId,
          ...(videoId ? { videoId } : {}),
        },
        orderBy: [{ submittedAt: 'desc' }],
      });
    },
  };
}

export const attemptService = createAttemptService();
