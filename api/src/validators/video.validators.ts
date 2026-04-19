import { z } from 'zod';

export const createVideoSchema = z.object({
  courseId: z.string().uuid(),
  title: z.string().min(1).max(200).trim(),
  orderIndex: z.coerce.number().int().min(0),
});
export type CreateVideoInput = z.infer<typeof createVideoSchema>;

export const videoIdParamsSchema = z.object({
  id: z.string().uuid(),
});
export type VideoIdParams = z.infer<typeof videoIdParamsSchema>;

/**
 * tusd hook callback body shape. Only the fields we actually read are
 * declared — tusd sends a much larger payload (HTTPRequest, etc.) but we
 * ignore them. `MetaData` is the user-supplied tus `Upload-Metadata`
 * dictionary; we use it to recover our own `videoId`. `Storage.Key` is the
 * actual S3 object key tusd wrote to (e.g. "{upload-id-hash}"); the worker
 * needs that key verbatim to read the source bytes because tusd does NOT
 * respect `Upload-Metadata: videoId` when naming the storage object.
 */
export const tusdHookBodySchema = z.object({
  Type: z.string(),
  Event: z.object({
    Upload: z.object({
      ID: z.string(),
      MetaData: z.record(z.string()).optional().default({}),
      Storage: z
        .object({
          Key: z.string().optional(),
          Bucket: z.string().optional(),
        })
        .optional(),
    }),
  }),
});
export type TusdHookBody = z.infer<typeof tusdHookBodySchema>;
