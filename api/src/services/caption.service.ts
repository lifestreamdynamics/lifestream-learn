import { randomUUID } from 'node:crypto';
import type { PrismaClient, Role } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { objectStore as defaultObjectStore, type ObjectStore } from '@/services/object-store';
import { parseSrtToVtt, validateVtt } from '@/services/caption.parser';
import { hasCourseAccess } from '@/services/course-access';
import { signCaptionUrl } from '@/utils/hls-signer';
import { uploadBytes } from '@/utils/object-store-utils';
import { env } from '@/config/env';
import { ForbiddenError, NotFoundError, ValidationError } from '@/utils/errors';
import { logger } from '@/config/logger';

export const CAPTION_MAX_BYTES = 512 * 1024; // 512 KB cap on uploaded bytes (before conversion).

export type SupportedUploadContentType = 'text/vtt' | 'application/x-subrip';

export interface CaptionUploadInput {
  videoId: string;
  language: string;        // already BCP-47-validated by the controller
  bytes: Buffer;
  contentType: SupportedUploadContentType;
  userId: string;          // who uploaded — stored as VideoCaption.uploadedBy
  role: Role;              // used for WRITE-level gate
  setDefault?: boolean;    // when true, also set Video.defaultCaptionLanguage atomically
}

export interface CaptionSummary {
  language: string;
  bytes: number;
  uploadedAt: Date;
}

export interface PlaybackCaption {
  language: string;
  url: string;
  expiresAt: Date;
}

export interface PlaybackCaptionBundle {
  captions: PlaybackCaption[];
  defaultCaptionLanguage: string | null;
}

export interface CaptionService {
  /**
   * Upload or overwrite a caption for (videoId, language). Converts SRT→VTT
   * as needed, validates the result, writes to object-storage, upserts the DB
   * row. If setDefault is true AND the language is supported (same row we just
   * wrote), also set Video.defaultCaptionLanguage. Requires WRITE access.
   */
  uploadCaption(input: CaptionUploadInput): Promise<CaptionSummary>;

  /**
   * List caption summaries for a video sorted by language ascending.
   * Requires READ access to the course.
   */
  listCaptions(videoId: string, userId: string, role: Role): Promise<CaptionSummary[]>;

  /**
   * Delete a specific (videoId, language) caption. Also clears
   * Video.defaultCaptionLanguage if it pointed at this language. Requires WRITE.
   */
  deleteCaption(
    videoId: string,
    language: string,
    userId: string,
    role: Role,
  ): Promise<void>;

  /**
   * Build the playback bundle for /api/videos/:id/playback. Caller has already
   * gated the request with canAccessVideo. Returns signed caption URLs plus
   * the Video.defaultCaptionLanguage.
   */
  getCaptionsForPlayback(videoId: string): Promise<PlaybackCaptionBundle>;
}

/** Prisma select shape for WRITE-level course authorization on a video. */
const VIDEO_WRITE_SELECT = (userId: string) => ({
  id: true,
  course: {
    select: {
      ownerId: true,
      collaborators: {
        where: { userId },
        select: { userId: true },
      },
    },
  },
} as const);

/** Prisma select shape for READ-level course authorization on a video. */
const VIDEO_READ_SELECT = (userId: string) => ({
  id: true,
  course: {
    select: {
      ownerId: true,
      collaborators: {
        where: { userId },
        select: { userId: true },
      },
      enrollments: {
        where: { userId },
        select: { userId: true },
      },
    },
  },
} as const);

const UTF8_BOM = '﻿';

/** Strip BOM and normalise CRLF → LF for raw VTT bytes before validation. */
function normaliseVttText(buf: Buffer): string {
  let text = buf.toString('utf8');
  if (text.startsWith(UTF8_BOM)) text = text.slice(1);
  return text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

export function createCaptionService(deps: {
  prisma: PrismaClient;
  objectStore: ObjectStore;
}): CaptionService {
  const { prisma, objectStore } = deps;

  return {
    async uploadCaption({
      videoId,
      language,
      bytes,
      contentType,
      userId,
      role,
      setDefault,
    }) {
      if (bytes.byteLength === 0) {
        throw new ValidationError('Caption body is empty');
      }
      if (bytes.byteLength > CAPTION_MAX_BYTES) {
        throw new ValidationError('Caption exceeds 512 KB limit');
      }

      const video = await prisma.video.findUnique({
        where: { id: videoId },
        select: VIDEO_WRITE_SELECT(userId),
      });
      if (!video) throw new NotFoundError('Video not found');

      if (!hasCourseAccess(role, userId, video.course, 'WRITE')) {
        throw new ForbiddenError('Not authorized to upload captions for this video');
      }

      let vttBuffer: Buffer;
      if (contentType === 'application/x-subrip') {
        vttBuffer = parseSrtToVtt(bytes);
      } else {
        const text = normaliseVttText(bytes);
        validateVtt(text);
        vttBuffer = Buffer.from(text, 'utf8');
      }

      const key = `vod/${videoId}/captions/${language}.vtt`;
      await uploadBytes(objectStore, env.S3_VOD_BUCKET, key, vttBuffer, 'text/vtt; charset=utf-8');

      const now = new Date();
      const upsertOp = prisma.videoCaption.upsert({
        where: { videoId_language: { videoId, language } },
        create: {
          id: randomUUID(),
          videoId,
          language,
          vttKey: key,
          bytes: vttBuffer.byteLength,
          uploadedBy: userId,
        },
        update: {
          vttKey: key,
          bytes: vttBuffer.byteLength,
          uploadedBy: userId,
          uploadedAt: now,
        },
        select: { language: true, bytes: true, uploadedAt: true },
      });

      if (setDefault) {
        const updateDefaultOp = prisma.video.update({
          where: { id: videoId },
          data: { defaultCaptionLanguage: language },
        });
        const [caption] = await prisma.$transaction([upsertOp, updateDefaultOp]);
        return { language: caption.language, bytes: caption.bytes, uploadedAt: caption.uploadedAt };
      }

      const caption = await upsertOp;
      return { language: caption.language, bytes: caption.bytes, uploadedAt: caption.uploadedAt };
    },

    async listCaptions(videoId, userId, role) {
      const video = await prisma.video.findUnique({
        where: { id: videoId },
        select: VIDEO_READ_SELECT(userId),
      });
      if (!video) throw new NotFoundError('Video not found');

      if (!hasCourseAccess(role, userId, video.course, 'READ')) {
        throw new ForbiddenError('Not authorized to view captions for this video');
      }

      const rows = await prisma.videoCaption.findMany({
        where: { videoId },
        select: { language: true, bytes: true, uploadedAt: true },
        orderBy: { language: 'asc' },
      });

      return rows;
    },

    async deleteCaption(videoId, language, userId, role) {
      const video = await prisma.video.findUnique({
        where: { id: videoId },
        select: {
          ...VIDEO_WRITE_SELECT(userId),
          defaultCaptionLanguage: true,
        },
      });
      if (!video) throw new NotFoundError('Video not found');

      if (!hasCourseAccess(role, userId, video.course, 'WRITE')) {
        throw new ForbiddenError('Not authorized to delete captions for this video');
      }

      const caption = await prisma.videoCaption.findUnique({
        where: { videoId_language: { videoId, language } },
        select: { vttKey: true },
      });
      if (!caption) throw new NotFoundError('Caption not found');

      // S3 delete is best-effort — do not throw if it fails; DB is source of truth.
      try {
        await objectStore.deleteObject(env.S3_VOD_BUCKET, caption.vttKey);
      } catch (err) {
        logger.warn({ err, videoId, language, key: caption.vttKey }, 'caption: S3 delete failed; continuing with DB delete');
      }

      const deleteOp = prisma.videoCaption.delete({
        where: { videoId_language: { videoId, language } },
      });

      if (video.defaultCaptionLanguage === language) {
        const clearDefaultOp = prisma.video.update({
          where: { id: videoId },
          data: { defaultCaptionLanguage: null },
        });
        await prisma.$transaction([deleteOp, clearDefaultOp]);
      } else {
        await deleteOp;
      }
    },

    async getCaptionsForPlayback(videoId) {
      const video = await prisma.video.findUnique({
        where: { id: videoId },
        select: { defaultCaptionLanguage: true },
      });

      // Defensive: caller's canAccessVideo gate already rejects missing videos,
      // but treat missing as an empty bundle rather than erroring here.
      if (!video) {
        return { captions: [], defaultCaptionLanguage: null };
      }

      const rows = await prisma.videoCaption.findMany({
        where: { videoId },
        select: { language: true },
        orderBy: { language: 'asc' },
      });

      const captions: PlaybackCaption[] = rows.map(({ language }) => {
        const { url, expiresAt } = signCaptionUrl(videoId, language);
        return { language, url, expiresAt };
      });

      return { captions, defaultCaptionLanguage: video.defaultCaptionLanguage };
    },
  };
}

export const captionService = createCaptionService({
  prisma: defaultPrisma,
  objectStore: defaultObjectStore,
});
