/**
 * @openapi
 * tags:
 *   name: Captions
 *   description: Upload, list, and delete per-language WebVTT captions on a video.
 */
import type { Request, Response } from 'express';
import {
  videoCaptionParamsSchema,
  videoCaptionQuerySchema,
  videoIdOnlyParamsSchema,
} from '@/validators/caption.validators';
import {
  captionService,
  CAPTION_MAX_BYTES,
  type SupportedUploadContentType,
} from '@/services/caption.service';
import { UnauthorizedError, ValidationError } from '@/utils/errors';

const ALLOWED_CAPTION_CONTENT_TYPES: ReadonlySet<SupportedUploadContentType> = new Set([
  'text/vtt',
  'application/x-subrip',
]);

/**
 * @openapi
 * /api/videos/{id}/captions:
 *   post:
 *     tags: [Captions]
 *     summary: Upload or overwrite a caption track for a specific language.
 *     description: |
 *       Accepts a raw WebVTT (`text/vtt`) or SubRip (`application/x-subrip`) body.
 *       SRT input is converted to VTT server-side before storage. Maximum body
 *       size is 512 KB (pre-conversion). Pass `?setDefault=1` to atomically mark
 *       this language as the video's default caption track.
 *
 *       Authorization is course-level: the caller must be the course owner, an
 *       enrolled COURSE_DESIGNER collaborator, or ADMIN. A LEARNER who has not
 *       been granted collaborator access will receive 403.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *         description: Video ID.
 *       - in: query
 *         name: language
 *         required: true
 *         schema: { type: string, example: en }
 *         description: BCP-47 language tag (e.g. `en`, `zh-CN`, `pt-BR`).
 *       - in: query
 *         name: setDefault
 *         required: false
 *         schema: { type: string, enum: ['1', 'true'] }
 *         description: When present and truthy, marks this language as the video default.
 *     requestBody:
 *       required: true
 *       content:
 *         text/vtt:
 *           schema: { type: string, format: binary }
 *         application/x-subrip:
 *           schema: { type: string, format: binary }
 *     responses:
 *       200:
 *         description: Caption uploaded (or overwritten). Returns a summary of the stored track.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 language: { type: string, example: en }
 *                 bytes: { type: integer, example: 4096 }
 *                 uploadedAt: { type: string, format: date-time }
 *       400: { description: Validation error — missing language, empty body, or VTT parse failure. }
 *       401: { description: Unauthenticated. }
 *       403: { description: No write access to this video's course. }
 *       404: { description: Video not found. }
 *       413: { description: Payload exceeds 512 KB limit. }
 *       415: { description: Content type must be text/vtt or application/x-subrip. }
 */
export async function uploadCaption(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');

  const { videoId } = videoIdOnlyParamsSchema.parse({ videoId: req.params.id });
  const { language, setDefault } = videoCaptionQuerySchema.parse(req.query);

  // Strip any `; charset=...` suffix before the media-type check.
  const rawContentType = req.get('content-type') ?? '';
  const contentType = rawContentType.split(';')[0]?.trim().toLowerCase();

  if (!contentType || !ALLOWED_CAPTION_CONTENT_TYPES.has(contentType as SupportedUploadContentType)) {
    res.status(415).json({
      error: 'UNSUPPORTED_MEDIA_TYPE',
      message: 'Caption must be text/vtt or application/x-subrip',
    });
    return;
  }

  const bytes = req.body as unknown;
  if (!Buffer.isBuffer(bytes) || bytes.byteLength === 0) {
    throw new ValidationError('Caption body must be a non-empty raw payload');
  }
  if (bytes.byteLength > CAPTION_MAX_BYTES) {
    res.status(413).json({
      error: 'PAYLOAD_TOO_LARGE',
      message: 'Caption exceeds 512 KB limit',
    });
    return;
  }

  const summary = await captionService.uploadCaption({
    videoId,
    language,
    bytes,
    contentType: contentType as SupportedUploadContentType,
    userId: req.user.id,
    role: req.user.role,
    setDefault,
  });

  res.status(200).json({
    language: summary.language,
    bytes: summary.bytes,
    uploadedAt: summary.uploadedAt,
  });
}

/**
 * @openapi
 * /api/videos/{id}/captions:
 *   get:
 *     tags: [Captions]
 *     summary: List available caption tracks for a video.
 *     description: |
 *       Returns all language tracks stored for the video, sorted by language
 *       ascending. Requires READ access (enrolled learner, collaborator, owner,
 *       or ADMIN).
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *         description: Video ID.
 *     responses:
 *       200:
 *         description: Caption track list (may be empty).
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 captions:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       language: { type: string, example: en }
 *                       bytes: { type: integer, example: 4096 }
 *                       uploadedAt: { type: string, format: date-time }
 *       401: { description: Unauthenticated. }
 *       403: { description: No read access to this video's course. }
 *       404: { description: Video not found. }
 */
export async function listCaptions(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');

  const { videoId } = videoIdOnlyParamsSchema.parse({ videoId: req.params.id });

  const captions = await captionService.listCaptions(videoId, req.user.id, req.user.role);

  res.status(200).json({ captions });
}

/**
 * @openapi
 * /api/videos/{id}/captions/{language}:
 *   delete:
 *     tags: [Captions]
 *     summary: Delete a specific language caption track.
 *     description: |
 *       Removes the caption object from storage and the DB row for the given
 *       `(videoId, language)` pair. If this language was the video's default
 *       caption, `Video.defaultCaptionLanguage` is cleared atomically.
 *       S3 deletion is best-effort — a storage failure is logged but does not
 *       prevent the DB row from being removed. Requires WRITE access.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *         description: Video ID.
 *       - in: path
 *         name: language
 *         required: true
 *         schema: { type: string, example: en }
 *         description: BCP-47 language tag to remove.
 *     responses:
 *       204: { description: Caption deleted. }
 *       401: { description: Unauthenticated. }
 *       403: { description: No write access to this video's course. }
 *       404: { description: Video or caption not found. }
 */
export async function deleteCaption(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');

  const { videoId, language } = videoCaptionParamsSchema.parse({
    videoId: req.params.id,
    language: req.params.language,
  });

  await captionService.deleteCaption(videoId, language, req.user.id, req.user.role);

  res.status(204).send();
}
