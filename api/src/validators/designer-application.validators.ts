import { z } from 'zod';
import { AppStatus } from '@prisma/client';

export const createDesignerApplicationBodySchema = z
  .object({
    note: z.string().max(2000).optional(),
  })
  .strict();
export type CreateDesignerApplicationBody = z.infer<
  typeof createDesignerApplicationBodySchema
>;

export const reviewDesignerApplicationBodySchema = z
  .object({
    status: z.enum([AppStatus.APPROVED, AppStatus.REJECTED]),
    reviewerNote: z.string().max(2000).optional(),
  })
  .strict();
export type ReviewDesignerApplicationBody = z.infer<
  typeof reviewDesignerApplicationBodySchema
>;

export const designerApplicationIdParamsSchema = z.object({
  id: z.string().uuid(),
});
export type DesignerApplicationIdParams = z.infer<
  typeof designerApplicationIdParamsSchema
>;

export const listDesignerApplicationsQuerySchema = z
  .object({
    status: z.nativeEnum(AppStatus).optional(),
    cursor: z.string().min(1).max(500).optional(),
    limit: z.coerce.number().int().min(1).max(50).optional(),
  })
  .strict();
export type ListDesignerApplicationsQuery = z.infer<
  typeof listDesignerApplicationsQuerySchema
>;

/**
 * Reuse the Course cursor shape for DesignerApplication listings
 * (sorted newest first by submittedAt). We keep it local so the
 * downstream decoder can't be misused for an unrelated cursor shape.
 */
export interface DesignerApplicationCursor {
  submittedAt: Date;
  id: string;
}

export function encodeDesignerApplicationCursor(c: DesignerApplicationCursor): string {
  return Buffer.from(`${c.submittedAt.toISOString()}|${c.id}`, 'utf8').toString('base64');
}

export function decodeDesignerApplicationCursor(
  raw: string,
): DesignerApplicationCursor | null {
  try {
    const decoded = Buffer.from(raw, 'base64').toString('utf8');
    const idx = decoded.indexOf('|');
    if (idx === -1) return null;
    const submittedAt = new Date(decoded.slice(0, idx));
    const id = decoded.slice(idx + 1);
    if (Number.isNaN(submittedAt.getTime()) || id.length === 0) return null;
    return { submittedAt, id };
  } catch {
    return null;
  }
}
