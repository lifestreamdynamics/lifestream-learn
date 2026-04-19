import type { Cue, CueType, PrismaClient, Role } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import {
  ForbiddenError,
  NotFoundError,
  NotImplementedError,
  ValidationError,
} from '@/utils/errors';
import { cuePayloadSchema } from '@/validators/cue-payloads';

export interface CreateCueInput {
  atMs: number;
  pause?: boolean;
  type: CueType;
  payload?: unknown;
  orderIndex?: number;
}

export interface UpdateCuePatch {
  atMs?: number;
  pause?: boolean;
  payload?: unknown;
  orderIndex?: number;
  // Accept `type` only to reject it explicitly — changing cue.type would
  // orphan existing attempts' scoreJson shape.
  type?: CueType;
}

export interface CueService {
  createCue(
    videoId: string,
    userId: string,
    role: Role,
    input: CreateCueInput,
  ): Promise<Cue>;
  listCuesForVideo(videoId: string, userId: string, role: Role): Promise<Cue[]>;
  updateCue(
    cueId: string,
    userId: string,
    role: Role,
    patch: UpdateCuePatch,
  ): Promise<Cue>;
  deleteCue(cueId: string, userId: string, role: Role): Promise<void>;
}

/**
 * Load the authorization facets of the video's course. Mirrors the shape
 * returned by `video.service.canAccessVideo` but scoped to the cue layer.
 */
async function loadVideoAuth(
  prisma: PrismaClient,
  videoId: string,
  userId: string,
) {
  return prisma.video.findUnique({
    where: { id: videoId },
    select: {
      id: true,
      courseId: true,
      course: {
        select: {
          ownerId: true,
          collaborators: { where: { userId }, select: { userId: true } },
          enrollments: { where: { userId }, select: { userId: true } },
        },
      },
    },
  });
}

function isDesignerOrAbove(
  role: Role,
  userId: string,
  course: { ownerId: string; collaborators: { userId: string }[] },
): boolean {
  if (role === 'ADMIN') return true;
  if (course.ownerId === userId) return true;
  if (course.collaborators.length > 0) return true;
  return false;
}

function validatePayloadForType(type: CueType, payload: unknown): void {
  // Reconstruct the discriminator on the payload so discriminatedUnion
  // dispatches correctly — the HTTP input keeps `type` at the cue level, not
  // inside payload, but the Zod schemas tag each variant with `type`.
  const tagged =
    typeof payload === 'object' && payload !== null
      ? { ...(payload as Record<string, unknown>), type }
      : { type };
  const parsed = cuePayloadSchema.safeParse(tagged);
  if (!parsed.success) {
    throw new ValidationError('Invalid cue payload', parsed.error.issues);
  }
}

export function createCueService(prisma: PrismaClient = defaultPrisma): CueService {
  return {
    async createCue(videoId, userId, role, input) {
      const video = await loadVideoAuth(prisma, videoId, userId);
      if (!video) throw new NotFoundError('Video not found');
      if (!isDesignerOrAbove(role, userId, video.course)) {
        throw new ForbiddenError('Not authorized to create cues on this video');
      }

      // VOICE is deferred — reject BEFORE writing anything.
      if (input.type === 'VOICE') {
        throw new NotImplementedError('VOICE cues are not yet supported');
      }

      validatePayloadForType(input.type, input.payload);

      if (input.atMs < 0 || !Number.isInteger(input.atMs)) {
        throw new ValidationError('atMs must be a non-negative integer');
      }

      let orderIndex = input.orderIndex;
      if (orderIndex === undefined) {
        const max = await prisma.cue.aggregate({
          where: { videoId },
          _max: { orderIndex: true },
        });
        orderIndex = max._max.orderIndex === null ? 0 : max._max.orderIndex + 1;
      }

      const cue = await prisma.cue.create({
        data: {
          videoId,
          atMs: input.atMs,
          pause: input.pause ?? true,
          type: input.type,
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          payload: input.payload as any,
          orderIndex,
        },
      });
      return cue;
    },

    async listCuesForVideo(videoId, userId, role) {
      const video = await prisma.video.findUnique({
        where: { id: videoId },
        select: {
          id: true,
          course: {
            select: {
              ownerId: true,
              collaborators: { where: { userId }, select: { userId: true } },
              enrollments: { where: { userId }, select: { userId: true } },
            },
          },
        },
      });
      if (!video) throw new NotFoundError('Video not found');

      const isAdmin = role === 'ADMIN';
      const isOwner = video.course.ownerId === userId;
      const isCollab = video.course.collaborators.length > 0;
      const isEnrolled = video.course.enrollments.length > 0;
      if (!isAdmin && !isOwner && !isCollab && !isEnrolled) {
        throw new ForbiddenError('You do not have access to this video');
      }

      return prisma.cue.findMany({
        where: { videoId },
        orderBy: [{ atMs: 'asc' }],
      });
    },

    async updateCue(cueId, userId, role, patch) {
      if (patch.type !== undefined) {
        throw new ValidationError('Cannot change cue.type after creation');
      }

      const cue = await prisma.cue.findUnique({
        where: { id: cueId },
        select: {
          id: true,
          type: true,
          video: {
            select: {
              id: true,
              course: {
                select: {
                  ownerId: true,
                  collaborators: { where: { userId }, select: { userId: true } },
                },
              },
            },
          },
        },
      });
      if (!cue) throw new NotFoundError('Cue not found');
      if (!isDesignerOrAbove(role, userId, cue.video.course)) {
        throw new ForbiddenError('Not authorized to update this cue');
      }

      if (patch.atMs !== undefined && (patch.atMs < 0 || !Number.isInteger(patch.atMs))) {
        throw new ValidationError('atMs must be a non-negative integer');
      }
      if (patch.orderIndex !== undefined && (patch.orderIndex < 0 || !Number.isInteger(patch.orderIndex))) {
        throw new ValidationError('orderIndex must be a non-negative integer');
      }

      if (patch.payload !== undefined) {
        validatePayloadForType(cue.type, patch.payload);
      }

      return prisma.cue.update({
        where: { id: cueId },
        data: {
          ...(patch.atMs !== undefined ? { atMs: patch.atMs } : {}),
          ...(patch.pause !== undefined ? { pause: patch.pause } : {}),
          ...(patch.orderIndex !== undefined ? { orderIndex: patch.orderIndex } : {}),
          ...(patch.payload !== undefined
            ? // eslint-disable-next-line @typescript-eslint/no-explicit-any
              { payload: patch.payload as any }
            : {}),
        },
      });
    },

    async deleteCue(cueId, userId, role) {
      const cue = await prisma.cue.findUnique({
        where: { id: cueId },
        select: {
          id: true,
          video: {
            select: {
              course: {
                select: {
                  ownerId: true,
                  collaborators: { where: { userId }, select: { userId: true } },
                },
              },
            },
          },
        },
      });
      if (!cue) throw new NotFoundError('Cue not found');
      if (!isDesignerOrAbove(role, userId, cue.video.course)) {
        throw new ForbiddenError('Not authorized to delete this cue');
      }
      // Prisma cascade on Attempt.cueId handles attempts cleanup.
      await prisma.cue.delete({ where: { id: cueId } });
    },
  };
}

export const cueService = createCueService();
