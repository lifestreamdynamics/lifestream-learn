import { z } from 'zod';
import { CueType } from '@prisma/client';

/**
 * HTTP-layer validators for cue/attempt endpoints. The cue *payload* shape
 * itself lives in `cue-payloads.ts`; here we validate the envelope (atMs,
 * orderIndex, type) and leave payload as `unknown` so the service layer can
 * dispatch on type.
 */

export const createCueBodySchema = z
  .object({
    atMs: z.coerce.number().int().min(0),
    pause: z.boolean().optional(),
    type: z.nativeEnum(CueType),
    payload: z.unknown(),
    orderIndex: z.coerce.number().int().min(0).optional(),
  })
  .strict();
export type CreateCueBody = z.infer<typeof createCueBodySchema>;

export const updateCueBodySchema = z
  .object({
    atMs: z.coerce.number().int().min(0).optional(),
    pause: z.boolean().optional(),
    payload: z.unknown().optional(),
    orderIndex: z.coerce.number().int().min(0).optional(),
    // Accepted so we can reject it with a friendly message at the service
    // layer rather than a zod "unrecognized key" error.
    type: z.nativeEnum(CueType).optional(),
  })
  .strict();
export type UpdateCueBody = z.infer<typeof updateCueBodySchema>;

export const cueIdParamsSchema = z.object({
  id: z.string().uuid(),
});
export type CueIdParams = z.infer<typeof cueIdParamsSchema>;

export const videoIdForCuesParamsSchema = z.object({
  id: z.string().uuid(),
});

export const submitAttemptBodySchema = z
  .object({
    cueId: z.string().uuid(),
    response: z.unknown(),
  })
  .strict();
export type SubmitAttemptBody = z.infer<typeof submitAttemptBodySchema>;

export const listAttemptsQuerySchema = z.object({
  videoId: z.string().uuid().optional(),
});
export type ListAttemptsQuery = z.infer<typeof listAttemptsQuerySchema>;
