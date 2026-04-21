import { z } from 'zod';

/**
 * Slice P2 — progress-aggregation endpoints. Path params only: the body
 * is always empty for these GETs.
 */

export const progressCourseIdParamsSchema = z.object({
  courseId: z.string().uuid(),
});
export type ProgressCourseIdParams = z.infer<
  typeof progressCourseIdParamsSchema
>;

export const progressVideoIdParamsSchema = z.object({
  videoId: z.string().uuid(),
});
export type ProgressVideoIdParams = z.infer<typeof progressVideoIdParamsSchema>;
