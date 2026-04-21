import { z } from 'zod';

// BCP-47: primary (2-3 lower) + optional script (Title) + optional region (UPPER or 3-digit)
export const bcp47LanguageSchema = z.string().regex(
  /^[a-z]{2,3}(-[A-Z][a-z]{3})?(-[A-Z]{2}|-[0-9]{3})?$/,
  'language must be a BCP-47 tag (e.g. en, zh-CN, pt-BR)',
);

export const videoCaptionParamsSchema = z.object({
  videoId: z.string().uuid(),
  language: bcp47LanguageSchema,
});

export const videoIdOnlyParamsSchema = z.object({
  videoId: z.string().uuid(),
});

// setDefault: coerce query strings "1"/"true" to boolean; undefined stays undefined
export const videoCaptionQuerySchema = z.object({
  language: bcp47LanguageSchema,
  setDefault: z.preprocess(
    (v) => v === undefined ? undefined : (v === '1' || v === 'true' || v === true),
    z.boolean().optional(),
  ),
});

export type VideoCaptionParams = z.infer<typeof videoCaptionParamsSchema>;
export type VideoCaptionQuery = z.infer<typeof videoCaptionQuerySchema>;
export type VideoIdOnlyParams = z.infer<typeof videoIdOnlyParamsSchema>;
