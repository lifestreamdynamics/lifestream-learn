import type { CueType } from '@prisma/client';
import type {
  BlanksPayload,
  BlanksResponse,
  CueResponse,
  MatchingPayload,
  MatchingResponse,
  McqPayload,
  McqResponse,
} from '@/validators/cue-payloads';
import { NotImplementedError } from '@/utils/errors';
import { gradeMcq } from '@/services/grading/mcq';
import { gradeBlanks } from '@/services/grading/blanks';
import { gradeMatching } from '@/services/grading/matching';
import { gradeVoice } from '@/services/grading/voice';
import type { GradingResult } from '@/services/grading/types';

export type { GradingResult } from '@/services/grading/types';

/**
 * Dispatch on cue.type. The caller MUST have already validated `payload`
 * (discriminated union by type) and `response` (via `parseResponseFor`).
 * This function does no re-validation — it's purely a type-level switch.
 *
 * Declared with an exhaustive `default` so a future CueType enum addition
 * becomes a compile error, not a silent miss.
 */
export function grade(
  cueType: CueType,
  payload: unknown,
  response: CueResponse,
): GradingResult {
  switch (cueType) {
    case 'MCQ':
      return gradeMcq(payload as McqPayload, response as McqResponse);
    case 'BLANKS':
      return gradeBlanks(payload as BlanksPayload, response as BlanksResponse);
    case 'MATCHING':
      return gradeMatching(payload as MatchingPayload, response as MatchingResponse);
    case 'VOICE':
      return gradeVoice();
    /* istanbul ignore next -- exhaustiveness guard; unreachable given
       the CueType enum. Left as a compile-time barrier so that adding a
       new enum value becomes a TS error instead of a silent fall-through. */
    default: {
      const exhaustive: never = cueType;
      throw new NotImplementedError(`Unknown cue type: ${String(exhaustive)}`);
    }
  }
}
