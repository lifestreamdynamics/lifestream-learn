import { z } from 'zod';

export const feedQuerySchema = z
  .object({
    cursor: z.string().min(1).max(500).optional(),
    limit: z.coerce.number().int().min(1).max(50).optional(),
  })
  .strict();
export type FeedQuery = z.infer<typeof feedQuerySchema>;

/**
 * Feed cursor = base64(`${enrollmentStartedAtIso}|${orderIndex}|${videoId}`).
 * Opaque to clients. Decoded in the feed service to resume ordering at the
 * previous page's last boundary.
 */
export interface FeedCursor {
  startedAt: Date;
  orderIndex: number;
  videoId: string;
}

export function encodeFeedCursor(c: FeedCursor): string {
  return Buffer.from(
    `${c.startedAt.toISOString()}|${c.orderIndex}|${c.videoId}`,
    'utf8',
  ).toString('base64');
}

export function decodeFeedCursor(raw: string): FeedCursor | null {
  try {
    const decoded = Buffer.from(raw, 'base64').toString('utf8');
    const parts = decoded.split('|');
    if (parts.length !== 3) return null;
    const [isoStartedAt, orderIndexStr, videoId] = parts;
    const startedAt = new Date(isoStartedAt);
    const orderIndex = Number.parseInt(orderIndexStr, 10);
    if (Number.isNaN(startedAt.getTime())) return null;
    if (!Number.isInteger(orderIndex)) return null;
    if (videoId.length === 0) return null;
    return { startedAt, orderIndex, videoId };
  } catch {
    return null;
  }
}
