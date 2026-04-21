/**
 * @openapi
 * tags:
 *   name: InternalHooks
 *   description: Internal webhook receivers (not for client use).
 */
import { createHash, timingSafeEqual } from 'node:crypto';
import type { Request, Response } from 'express';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { tusdHookBodySchema } from '@/validators/video.validators';
import { enqueueTranscode } from '@/queues/transcode.queue';
import { UnauthorizedError, ValidationError } from '@/utils/errors';

// Query-param fallback leaks the secret into proxy/access logs, so it is only
// honoured outside production. Header-based auth is required in prod.
const QUERY_TOKEN_ALLOWED = env.NODE_ENV !== 'production';

/**
 * Constant-time check of the shared secret tusd presents on every hook
 * delivery. Accepts the secret via `X-Tusd-Hook-Token` header; a `?token=`
 * query-param fallback is honoured only in non-production environments. Both
 * provided and expected are SHA-256 hashed before `timingSafeEqual`, which
 * removes the length-branch timing side-channel that a raw compare has (the
 * hash output is always 32 bytes, so missing/short/long tokens all hit the
 * same code path).
 */
function hookTokenValid(req: Request): boolean {
  const tokenFromHeader = req.header('x-tusd-hook-token') ?? '';
  const tokenFromQuery =
    QUERY_TOKEN_ALLOWED && typeof req.query.token === 'string' ? req.query.token : '';
  const provided = tokenFromHeader || tokenFromQuery;
  const expected = env.TUSD_HOOK_SECRET;
  const providedDigest = createHash('sha256').update(provided).digest();
  const expectedDigest = createHash('sha256').update(expected).digest();
  return timingSafeEqual(providedDigest, expectedDigest);
}

/**
 * @openapi
 * /internal/hooks/tusd:
 *   post:
 *     tags: [InternalHooks]
 *     summary: tusd webhook receiver. Enqueues transcode jobs on `pre-finish`.
 *     description: |
 *       Authenticated by a shared secret (`X-Tusd-Hook-Token` header). All other
 *       event types (`post-finish`, etc.) are acknowledged with a 200 no-op so
 *       tusd does not retry.
 *     responses:
 *       200: { description: Acknowledged. Either enqueued or no-op. }
 *       400: { description: Malformed body or missing videoId metadata. }
 *       401: { description: Missing or wrong shared secret. }
 */
export async function handleTusdHook(req: Request, res: Response): Promise<void> {
  if (!hookTokenValid(req)) throw new UnauthorizedError('Invalid tusd hook token');

  const body = tusdHookBodySchema.parse(req.body);
  const type = body.Type;

  if (type === 'pre-create') {
    // tusd forwards any non-2xx response to the client as the upload
    // rejection. We cap the declared Upload-Length at env.VIDEO_MAX_BYTES
    // to stop oversized byte streams at the edge rather than after the
    // bytes are already on disk. A deferred-length upload (Size=0 or
    // missing) cannot be checked here — the pipeline re-runs the size
    // check against the downloaded source in transcode.pipeline.ts.
    const declaredSize = body.Event.Upload.Size ?? 0;
    if (declaredSize > env.VIDEO_MAX_BYTES) {
      logger.warn(
        { declaredSize, cap: env.VIDEO_MAX_BYTES },
        'tusd pre-create: rejecting oversized upload',
      );
      res.status(413).json({
        ok: false,
        code: 'INPUT_TOO_LARGE',
        message: `Upload size ${declaredSize}B exceeds cap ${env.VIDEO_MAX_BYTES}B`,
      });
      return;
    }
    res.status(200).json({ ok: true, accepted: true });
    return;
  }

  if (type === 'pre-finish') {
    const videoId = body.Event.Upload.MetaData?.videoId;
    if (!videoId) throw new ValidationError('Missing videoId in Upload-Metadata');
    // Validate UUID shape up-front so a malformed client payload can't be
    // propagated as a Prisma lookup key or persisted as a nonsense job id.
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(videoId)) {
      throw new ValidationError('videoId in Upload-Metadata must be a UUID');
    }
    // tusd writes to its own object layout (`{upload-id-hash}` in the S3
    // bucket, ignoring our Upload-Metadata). Prefer Storage.Key when tusd
    // supplies it; fall back to `Event.Upload.ID` which matches tusd's
    // default S3 naming for the in-compose tusd v2 configuration.
    const storageKey = body.Event.Upload.Storage?.Key ?? body.Event.Upload.ID;
    if (!storageKey) throw new ValidationError('Missing Storage.Key and Upload.ID');
    await enqueueTranscode({ videoId, sourceKey: storageKey });
    logger.info({ videoId, storageKey, type }, 'enqueued transcode job');
    res.status(200).json({ ok: true, enqueued: videoId });
    return;
  }

  // post-finish (and any future tusd event types) are acked so tusd doesn't
  // retry forever; we only act on pre-finish because that's the moment the
  // upload bytes are durable but the rename hasn't fired yet.
  logger.debug({ type }, 'tusd hook: no-op type');
  res.status(200).json({ ok: true, noop: true });
}
