/**
 * @openapi
 * tags:
 *   name: Videos
 *   description: Video upload, metadata, and signed playback URLs.
 */
import type { Request, Response } from 'express';
import { createVideoSchema, videoIdParamsSchema } from '@/validators/video.validators';
import { videoService } from '@/services/video.service';
import { signPlaybackUrl, signPosterUrl } from '@/utils/hls-signer';
import { captionService } from '@/services/caption.service';
import { ConflictError, ForbiddenError, NotFoundError, UnauthorizedError } from '@/utils/errors';
import { env } from '@/config/env';

/**
 * @openapi
 * /api/videos:
 *   post:
 *     tags: [Videos]
 *     summary: Create a video record and obtain tusd upload coordinates.
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [courseId, title, orderIndex]
 *             properties:
 *               courseId: { type: string, format: uuid }
 *               title: { type: string, minLength: 1, maxLength: 200 }
 *               orderIndex: { type: integer, minimum: 0 }
 *     responses:
 *       201:
 *         description: Video row created with status UPLOADING; client uploads to `uploadUrl` via tus.
 *       400: { description: Validation error. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Not authorized to create a video in this course. }
 *       404: { description: Course not found. }
 */
export async function create(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const input = createVideoSchema.parse(req.body);
  const { video, sourceKey } = await videoService.createVideo({
    ...input,
    userId: req.user.id,
    role: req.user.role,
  });
  // tusd's Upload-Metadata is a comma-separated list of `key base64(value)`
  // pairs (RFC). We base64-encode the videoId without padding so tusd parses
  // cleanly and the worker can recover it via Event.Upload.MetaData.videoId.
  res.status(201).json({
    videoId: video.id,
    video,
    uploadUrl: env.TUSD_PUBLIC_URL,
    uploadHeaders: {
      'Tus-Resumable': '1.0.0',
      'Upload-Metadata': `videoId ${Buffer.from(video.id).toString('base64').replace(/=+$/, '')}`,
    },
    sourceKey,
  });
}

/**
 * @openapi
 * /api/videos/{id}:
 *   get:
 *     tags: [Videos]
 *     summary: Fetch a video's metadata.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200: { description: Video metadata. }
 *       401: { description: Unauthenticated. }
 *       403: { description: No access. }
 *       404: { description: Video not found. }
 */
export async function getById(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id } = videoIdParamsSchema.parse(req.params);
  const video = await videoService.getVideoById(id, req.user.id, req.user.role);
  res.status(200).json(video);
}

/**
 * @openapi
 * /api/videos/{id}/playback:
 *   get:
 *     tags: [Videos]
 *     summary: Get a short-lived signed master playlist URL plus caption bundle.
 *     description: |
 *       Returns a signed HLS master playlist URL, an optional poster URL, and
 *       a list of signed caption URLs for every stored language track. All URLs
 *       share the same `expiresAt` TTL (2–4 h). `defaultCaptionLanguage` is the
 *       language tag the player should enable by default, or null when no default
 *       has been set for this video.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: Signed playback bundle.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 masterPlaylistUrl: { type: string, format: uri }
 *                 posterUrl: { type: string, format: uri, nullable: true }
 *                 expiresAt: { type: string, format: date-time }
 *                 captions:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       language: { type: string, example: en }
 *                       url: { type: string, format: uri }
 *                       expiresAt: { type: string, format: date-time }
 *                 defaultCaptionLanguage:
 *                   type: string
 *                   nullable: true
 *                   example: en
 *       401: { description: Unauthenticated. }
 *       403: { description: No access. }
 *       404: { description: Video not found. }
 *       409: { description: Video not yet READY. }
 */
export async function getPlayback(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const { id } = videoIdParamsSchema.parse(req.params);
  const { allowed, video } = await videoService.canAccessVideo(req.user.id, req.user.role, id);
  if (!video) throw new NotFoundError('Video not found');
  if (!allowed) throw new ForbiddenError('You do not have access to this video');
  if (video.status !== 'READY' || !video.hlsPrefix) {
    throw new ConflictError(`Video is not ready for playback (status=${video.status})`);
  }
  const { url, expiresAt } = signPlaybackUrl(video.id);
  // The poster is best-effort during transcode (see
  // `transcode.pipeline.ts`), so it may be absent on older rows or on
  // sources that refused poster extraction. Clients must treat it as
  // optional — the Flutter feed already has a fallback coloured card.
  const posterUrl = video.posterKey ? signPosterUrl(video.id).url : null;
  const bundle = await captionService.getCaptionsForPlayback(video.id);
  res.status(200).json({
    masterPlaylistUrl: url,
    posterUrl,
    expiresAt: expiresAt.toISOString(),
    captions: bundle.captions.map((c) => ({
      language: c.language,
      url: c.url,
      expiresAt: c.expiresAt.toISOString(),
    })),
    defaultCaptionLanguage: bundle.defaultCaptionLanguage,
  });
}
