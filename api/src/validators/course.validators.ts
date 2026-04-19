import { z } from 'zod';

/**
 * HTTP-layer validators for the Course resource.
 *
 * Shape notes
 * -----------
 * - `slug` is optional on create (we auto-generate when omitted); when
 *   provided, we enforce the same [a-z0-9-] alphabet the auto-generator
 *   produces so clients can't smuggle in uppercase/unicode surprises.
 * - `coverImageUrl` uses `z.string().url()` — a missing scheme or obviously
 *   malformed URL is a 400, not a silent accept-and-break-later.
 * - `cursor` is opaque (base64) to downstream clients; we decode in the
 *   service. The HTTP layer just validates it parses as a string.
 */

export const slugRegex = /^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$/;

export const createCourseBodySchema = z
  .object({
    title: z.string().trim().min(1).max(200),
    description: z.string().trim().min(1).max(2000),
    coverImageUrl: z.string().url().max(2048).optional(),
    slug: z.string().min(1).max(80).regex(slugRegex).optional(),
  })
  .strict();
export type CreateCourseBody = z.infer<typeof createCourseBodySchema>;

export const updateCourseBodySchema = z
  .object({
    title: z.string().trim().min(1).max(200).optional(),
    description: z.string().trim().min(1).max(2000).optional(),
    coverImageUrl: z.string().url().max(2048).nullable().optional(),
    slug: z.string().min(1).max(80).regex(slugRegex).optional(),
  })
  .strict();
export type UpdateCourseBody = z.infer<typeof updateCourseBodySchema>;

export const courseIdParamsSchema = z.object({
  id: z.string().uuid(),
});
export type CourseIdParams = z.infer<typeof courseIdParamsSchema>;

export const collaboratorParamsSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().uuid(),
});
export type CollaboratorParams = z.infer<typeof collaboratorParamsSchema>;

export const addCollaboratorBodySchema = z
  .object({
    userId: z.string().uuid(),
  })
  .strict();
export type AddCollaboratorBody = z.infer<typeof addCollaboratorBodySchema>;

/**
 * Boolean filter that accepts the string "true"/"false" (query params are
 * always strings) or an actual boolean.
 */
const boolFilter = z
  .union([z.literal('true'), z.literal('false'), z.boolean()])
  .transform((v) => v === true || v === 'true');

export const listCoursesQuerySchema = z
  .object({
    cursor: z.string().min(1).max(500).optional(),
    limit: z.coerce.number().int().min(1).max(50).optional(),
    owned: boolFilter.optional(),
    enrolled: boolFilter.optional(),
    published: boolFilter.optional(),
  })
  .strict();
export type ListCoursesQuery = z.infer<typeof listCoursesQuerySchema>;

// ----- Cursor encoding -----

/**
 * Cursor = base64(`${createdAtIso}|${id}`). Opaque to clients so the server
 * can change the shape (e.g. switch to keyset with extra fields) without a
 * client version bump.
 */
export interface CourseCursor {
  createdAt: Date;
  id: string;
}

export function encodeCourseCursor(cursor: CourseCursor): string {
  return Buffer.from(`${cursor.createdAt.toISOString()}|${cursor.id}`, 'utf8').toString('base64');
}

export function decodeCourseCursor(raw: string): CourseCursor | null {
  try {
    const decoded = Buffer.from(raw, 'base64').toString('utf8');
    const idx = decoded.indexOf('|');
    if (idx === -1) return null;
    const createdAt = new Date(decoded.slice(0, idx));
    const id = decoded.slice(idx + 1);
    if (Number.isNaN(createdAt.getTime()) || id.length === 0) return null;
    return { createdAt, id };
  } catch {
    return null;
  }
}
