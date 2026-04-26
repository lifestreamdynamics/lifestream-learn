import { randomUUID } from 'node:crypto';
import type { PrismaClient, Role, Video, VideoStatus } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { ForbiddenError, NotFoundError } from '@/utils/errors';
import { hasCourseAccess } from '@/services/course-access';

export interface PublicVideo {
  id: string;
  courseId: string;
  title: string;
  orderIndex: number;
  status: VideoStatus;
  durationMs: number | null;
  /**
   * BCP-47 caption language to surface as default in player + designer
   * UIs. Mirrors `Video.defaultCaptionLanguage` and is null when no
   * default has been chosen. Designer reads this to show the "default"
   * marker on the matching caption row; player reads it via the
   * playback bundle for caption auto-selection.
   */
  defaultCaptionLanguage: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export type VideoAccessSummary = Pick<
  Video,
  'id' | 'status' | 'hlsPrefix' | 'posterKey' | 'courseId'
>;

export interface VideoService {
  createVideo(input: {
    courseId: string;
    title: string;
    orderIndex: number;
    userId: string;
    role: Role;
  }): Promise<{ video: PublicVideo; sourceKey: string }>;
  getVideoById(videoId: string, userId: string, role: Role): Promise<PublicVideo>;
  canAccessVideo(
    userId: string,
    role: Role,
    videoId: string,
  ): Promise<{ allowed: boolean; video: VideoAccessSummary | null }>;
  markReady(videoId: string, data: { hlsPrefix: string; durationMs: number }): Promise<void>;
  markFailed(videoId: string, reason: string): Promise<void>;
}

function toPublic(v: Video): PublicVideo {
  return {
    id: v.id,
    courseId: v.courseId,
    title: v.title,
    orderIndex: v.orderIndex,
    status: v.status,
    durationMs: v.durationMs,
    defaultCaptionLanguage: v.defaultCaptionLanguage,
    createdAt: v.createdAt,
    updatedAt: v.updatedAt,
  };
}

export function createVideoService(prisma: PrismaClient = defaultPrisma): VideoService {
  return {
    async createVideo({ courseId, title, orderIndex, userId, role }) {
      const course = await prisma.course.findUnique({
        where: { id: courseId },
        select: {
          ownerId: true,
          collaborators: {
            where: { userId },
            select: { userId: true },
          },
        },
      });
      if (!course) throw new NotFoundError('Course not found');

      if (!hasCourseAccess(role, userId, course, 'WRITE')) {
        throw new ForbiddenError('Not authorized to create videos in this course');
      }

      // Generate the UUID up front so the source key (`uploads/<videoId>`)
      // matches the row we just created. tusd will write the upload at this
      // key after the pre-finish hook fires.
      const videoId = randomUUID();
      const sourceKey = `uploads/${videoId}`;
      const created = await prisma.video.create({
        data: {
          id: videoId,
          courseId,
          title,
          orderIndex,
          sourceKey,
          status: 'UPLOADING',
        },
      });
      return { video: toPublic(created), sourceKey };
    },

    async canAccessVideo(userId, role, videoId) {
      const video = await prisma.video.findUnique({
        where: { id: videoId },
        select: {
          id: true,
          status: true,
          hlsPrefix: true,
          posterKey: true,
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
      if (!video) return { allowed: false, video: null };

      const summary: VideoAccessSummary = {
        id: video.id,
        status: video.status,
        hlsPrefix: video.hlsPrefix,
        posterKey: video.posterKey,
        courseId: video.courseId,
      };

      const allowed = hasCourseAccess(role, userId, video.course, 'READ');
      return { allowed, video: summary };
    },

    async getVideoById(videoId, userId, role) {
      // Two reads on purpose: canAccessVideo selects a lean authorization
      // summary (id + status + hlsPrefix + courseId + course relations), and
      // the full Video row (title, orderIndex, durationMs, createdAt,
      // updatedAt) is needed for the public response. At MVP scale the extra
      // Postgres round-trip is negligible; revisit once this endpoint shows
      // up in the p95 budget.
      const access = await this.canAccessVideo(userId, role, videoId);
      if (!access.video) throw new NotFoundError('Video not found');
      if (!access.allowed) throw new ForbiddenError('You do not have access to this video');
      const full = await prisma.video.findUnique({ where: { id: videoId } });
      if (!full) throw new NotFoundError('Video not found');
      return toPublic(full);
    },

    // SCAFFOLD (Phase 6 analytics): markReady/markFailed are intentionally
    // kept here as centralized state-transition hooks even though the Phase 3
    // worker does its own Prisma updates inline. When Phase 6 lands the
    // analytics event pipeline, video-status changes fan out from these
    // methods so emission is a single concern, not duplicated in every
    // writer. Unit-tested to keep the contract stable.
    async markReady(videoId, data) {
      await prisma.video.update({
        where: { id: videoId },
        data: {
          status: 'READY',
          hlsPrefix: data.hlsPrefix,
          durationMs: data.durationMs,
        },
      });
    },

    async markFailed(videoId, reason) {
      // `reason` is logged for diagnostics; the schema doesn't have a column
      // for it yet (tracked separately), so we just transition status.
      void reason;
      await prisma.video.update({
        where: { id: videoId },
        data: { status: 'FAILED' },
      });
    },
  };
}

export const videoService = createVideoService();
