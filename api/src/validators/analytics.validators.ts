import { z } from 'zod';

/**
 * Analytics events are an append-only log. We accept unknown `eventType`
 * strings (up to 64 chars) so adding a new event type in the Flutter app
 * does not require a backend deploy. The `payload` field is free-form JSON.
 *
 * Per-event 4KB serialized size cap is enforced at the service layer after
 * Zod parsing, since JSON stringify length isn't expressible as a single
 * Zod predicate cleanly.
 */
export const analyticsEventSchema = z
  .object({
    eventType: z.string().min(1).max(64),
    occurredAt: z.string().datetime(),
    videoId: z.string().uuid().optional(),
    cueId: z.string().uuid().optional(),
    payload: z.record(z.unknown()).optional(),
  })
  .strict();
export type AnalyticsEventInput = z.infer<typeof analyticsEventSchema>;

export const analyticsEventsBodySchema = z.array(analyticsEventSchema).min(1).max(100);
export type AnalyticsEventsBody = z.infer<typeof analyticsEventsBodySchema>;

// The `:id` UUID-path-param schema is shared with course controllers.
// Re-export from course.validators.ts so there's one canonical definition
// (validator dedup — both files otherwise hand-rolled the same 3-line
// schema).
export { courseIdParamsSchema } from '@/validators/course.validators';
