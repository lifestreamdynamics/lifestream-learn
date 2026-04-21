import { pipeline } from 'node:stream/promises';
import type { Response } from 'express';
import type { ObjectStreamResult } from '@/services/object-store';

/**
 * Pipe an avatar object stream to an HTTP response with the right
 * content headers. Shared between `GET /api/me/avatar` (private
 * cache) and `GET /api/users/:id/avatar` (public cache) — the
 * Cache-Control value is the only part of the response shape that
 * differs between the two, so it's the only thing the caller picks.
 *
 * Responds 204 No Content and returns when [result] is null, so the
 * caller can write `await streamAvatar(res, result, '...')` in one
 * line without a separate null-check branch.
 */
export async function streamAvatar(
  res: Response,
  result: ObjectStreamResult | null,
  cacheControl: string,
): Promise<void> {
  if (!result) {
    res.status(204).end();
    return;
  }
  res.status(200);
  res.setHeader('Content-Type', result.contentType);
  if (result.contentLength != null) {
    res.setHeader('Content-Length', String(result.contentLength));
  }
  res.setHeader('Cache-Control', cacheControl);
  await pipeline(result.stream, res);
}
