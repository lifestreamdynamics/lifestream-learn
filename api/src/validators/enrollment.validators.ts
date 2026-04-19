import { z } from 'zod';

export const createEnrollmentBodySchema = z
  .object({
    courseId: z.string().uuid(),
  })
  .strict();
export type CreateEnrollmentBody = z.infer<typeof createEnrollmentBodySchema>;

export const updateEnrollmentProgressBodySchema = z
  .object({
    lastVideoId: z.string().uuid(),
    lastPosMs: z.coerce.number().int().min(0),
  })
  .strict();
export type UpdateEnrollmentProgressBody = z.infer<
  typeof updateEnrollmentProgressBodySchema
>;

export const enrollmentCourseIdParamsSchema = z.object({
  courseId: z.string().uuid(),
});
export type EnrollmentCourseIdParams = z.infer<typeof enrollmentCourseIdParamsSchema>;
