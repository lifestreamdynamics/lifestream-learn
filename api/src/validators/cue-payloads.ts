import { z } from 'zod';
import { ValidationError } from '@/utils/errors';

/**
 * Canonical cue payload shapes (see IMPLEMENTATION_PLAN.md §4).
 *
 * These are the *write-shape* validators: they describe what a designer may
 * submit on cue create/update. Response-shape validators (learner submitting
 * an attempt) are separate, keyed per cue type and dispatched via
 * `parseResponseFor()`.
 *
 * The canonical TS types are derived via `z.infer` — one source of truth.
 */

// ---------- shared helpers ----------

/**
 * Extract the distinct `{{N}}` placeholder indices from a BLANKS
 * `sentenceTemplate`, in order of first appearance. Exported because the
 * refinement below needs it *and* grading logic may want to cross-reference
 * placeholders in a future feature (e.g. highlighting mismatched blanks).
 */
export function extractPlaceholderIndices(template: string): number[] {
  const re = /\{\{(\d+)\}\}/g;
  const seen = new Set<number>();
  const out: number[] = [];
  let m: RegExpExecArray | null;
  while ((m = re.exec(template)) !== null) {
    const idx = Number.parseInt(m[1], 10);
    if (!seen.has(idx)) {
      seen.add(idx);
      out.push(idx);
    }
  }
  return out;
}

// ---------- MCQ ----------

/**
 * Base object for each cue type. `z.discriminatedUnion` requires a
 * `ZodObject` keyed by the discriminator, so the cross-field refinements
 * live on `*PayloadSchema` (used for standalone parsing) and the base
 * objects feed into the union.
 */
const mcqPayloadBase = z
  .object({
    type: z.literal('MCQ'),
    question: z.string().min(1),
    choices: z.array(z.string().min(1)).min(2).max(4),
    answerIndex: z.number().int().min(0).max(3),
    explanation: z.string().optional(),
  })
  .strict();

const mcqAnswerIndexRefinement = (
  v: { answerIndex: number; choices: string[] },
  ctx: z.RefinementCtx,
): void => {
  if (v.answerIndex >= v.choices.length) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['answerIndex'],
      message: 'answerIndex must be a valid index into choices',
    });
  }
};

export const mcqPayloadSchema = mcqPayloadBase.superRefine(mcqAnswerIndexRefinement);

export type McqPayload = z.infer<typeof mcqPayloadBase>;

// ---------- BLANKS ----------

const blankSpecSchema = z
  .object({
    accept: z.array(z.string().min(1)).min(1),
    caseSensitive: z.boolean().optional(),
  })
  .strict();

const blanksPayloadBase = z
  .object({
    type: z.literal('BLANKS'),
    sentenceTemplate: z.string().min(1),
    blanks: z.array(blankSpecSchema).min(1),
  })
  .strict();

type BlanksBase = z.infer<typeof blanksPayloadBase>;

const blanksTemplateRefinement = (v: BlanksBase, ctx: z.RefinementCtx): void => {
  const indices = extractPlaceholderIndices(v.sentenceTemplate);
  if (indices.length === 0) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['sentenceTemplate'],
      message: 'sentenceTemplate must contain at least one {{N}} placeholder',
    });
    return;
  }
  if (indices.length !== v.blanks.length) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['sentenceTemplate'],
      message: `sentenceTemplate has ${indices.length} distinct placeholders but blanks has ${v.blanks.length}`,
    });
    return;
  }
  const sorted = [...indices].sort((a, b) => a - b);
  for (let i = 0; i < sorted.length; i += 1) {
    if (sorted[i] !== i) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['sentenceTemplate'],
        message: `sentenceTemplate placeholders must be {{0}}..{{${v.blanks.length - 1}}} exactly once`,
      });
      return;
    }
  }
};

export const blanksPayloadSchema = blanksPayloadBase.superRefine(blanksTemplateRefinement);

export type BlanksPayload = BlanksBase;

// ---------- MATCHING ----------

const matchingPairSchema = z.tuple([
  z.number().int().min(0),
  z.number().int().min(0),
]);

const matchingPayloadBase = z
  .object({
    type: z.literal('MATCHING'),
    prompt: z.string().min(1),
    left: z.array(z.string().min(1)).min(2),
    right: z.array(z.string().min(1)).min(2),
    pairs: z.array(matchingPairSchema).min(1),
  })
  .strict();

type MatchingBase = z.infer<typeof matchingPayloadBase>;

const matchingPairsRefinement = (v: MatchingBase, ctx: z.RefinementCtx): void => {
  const seenLeft = new Set<number>();
  const seenRight = new Set<number>();
  const seenPair = new Set<string>();
  v.pairs.forEach(([l, r], i) => {
    if (l >= v.left.length) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['pairs', i, 0],
        message: `leftIdx ${l} out of range (left has ${v.left.length} items)`,
      });
    }
    if (r >= v.right.length) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['pairs', i, 1],
        message: `rightIdx ${r} out of range (right has ${v.right.length} items)`,
      });
    }
    const key = `${l}:${r}`;
    if (seenPair.has(key)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['pairs', i],
        message: `duplicate pair [${l}, ${r}]`,
      });
    }
    seenPair.add(key);
    if (seenLeft.has(l)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['pairs', i, 0],
        message: `leftIdx ${l} appears in more than one pair (must be 1:1)`,
      });
    }
    seenLeft.add(l);
    if (seenRight.has(r)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['pairs', i, 1],
        message: `rightIdx ${r} appears in more than one pair (must be 1:1)`,
      });
    }
    seenRight.add(r);
  });
};

export const matchingPayloadSchema = matchingPayloadBase.superRefine(matchingPairsRefinement);

export type MatchingPayload = MatchingBase;

// ---------- VOICE ----------

/**
 * VOICE is a reserved enum value; cue creation is rejected with 501 at the
 * service layer (ADR 0004). The validator stays permissive so that *reading*
 * a VOICE payload (should one ever land in the DB) doesn't crash. Writes
 * still fail because the cue.service inspects `input.type === 'VOICE'` before
 * anything else.
 */
export const voicePayloadSchema = z
  .object({ type: z.literal('VOICE') })
  .passthrough();

export type VoicePayload = z.infer<typeof voicePayloadSchema>;

// ---------- discriminated union ----------

/**
 * The discriminated union feeds on the plain `*Base` schemas (Zod requires
 * `ZodObject` variants keyed by a literal) and then re-applies the
 * cross-field refinements on the union level so a single `cuePayloadSchema`
 * parse still rejects invalid MCQ.answerIndex, BLANKS templates, and
 * MATCHING pair graphs.
 */
export const cuePayloadSchema = z
  .discriminatedUnion('type', [
    mcqPayloadBase,
    blanksPayloadBase,
    matchingPayloadBase,
    voicePayloadSchema,
  ])
  .superRefine((v, ctx) => {
    switch (v.type) {
      case 'MCQ':
        mcqAnswerIndexRefinement(v, ctx);
        return;
      case 'BLANKS':
        blanksTemplateRefinement(v, ctx);
        return;
      case 'MATCHING':
        matchingPairsRefinement(v, ctx);
        return;
      case 'VOICE':
        // No refinement — VOICE is rejected at the cue.service layer (501).
        return;
    }
  });

export type CuePayload = z.infer<typeof cuePayloadSchema>;

// ---------- response schemas (learner attempt submissions) ----------

export const mcqResponseSchema = z
  .object({ choiceIndex: z.number().int().min(0).max(3) })
  .strict();
export type McqResponse = z.infer<typeof mcqResponseSchema>;

export const blanksResponseSchema = z
  .object({ answers: z.array(z.string()).min(1) })
  .strict();
export type BlanksResponse = z.infer<typeof blanksResponseSchema>;

export const matchingResponseSchema = z
  .object({ userPairs: z.array(matchingPairSchema) })
  .strict();
export type MatchingResponse = z.infer<typeof matchingResponseSchema>;

export type CueResponse = McqResponse | BlanksResponse | MatchingResponse;

/**
 * Pick the correct response schema for a cue.type and parse `input` against
 * it. Thrown errors are normalised to `ValidationError` so the HTTP layer
 * maps them to 400 without leaking zod internals. VOICE is rejected at the
 * cue layer (501), but we guard here too — this helper must never grade a
 * VOICE cue silently.
 */
export function parseResponseFor(
  cueType: 'MCQ' | 'BLANKS' | 'MATCHING' | 'VOICE',
  input: unknown,
): CueResponse {
  let schema: z.ZodTypeAny;
  switch (cueType) {
    case 'MCQ':
      schema = mcqResponseSchema;
      break;
    case 'BLANKS':
      schema = blanksResponseSchema;
      break;
    case 'MATCHING':
      schema = matchingResponseSchema;
      break;
    case 'VOICE':
      throw new ValidationError('VOICE cues do not accept responses');
    /* istanbul ignore next -- exhaustiveness guard; unreachable given CueType. */
    default: {
      const exhaustive: never = cueType;
      throw new ValidationError(`Unsupported cue type: ${String(exhaustive)}`);
    }
  }
  const parsed = schema.safeParse(input);
  if (!parsed.success) {
    throw new ValidationError('Invalid response payload', parsed.error.issues);
  }
  return parsed.data as CueResponse;
}
