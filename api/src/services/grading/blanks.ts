import type { BlanksPayload, BlanksResponse } from '@/validators/cue-payloads';
import type { GradingResult } from '@/services/grading/types';

/**
 * Grade a BLANKS response.
 *
 * Rules:
 *   - Both user answer and accept values are trimmed on each side.
 *   - Case-insensitive by default; `caseSensitive: true` flips to exact
 *     comparison (post-trim).
 *   - A blank is correct if ANY accept-list entry matches (synonyms).
 *   - All blanks must match for `correct: true`.
 *   - If `response.answers.length !== payload.blanks.length`, the mismatch is
 *     tolerated (correct=false); `perBlank` is emitted for every *payload*
 *     blank using the corresponding user answer if present, otherwise false.
 *     This keeps the grader tolerant — upstream (service/zod) should already
 *     have rejected bad shapes but the grader can't assume that.
 *
 * Pure function — no I/O.
 */
export function gradeBlanks(payload: BlanksPayload, response: BlanksResponse): GradingResult {
  const perBlank: boolean[] = payload.blanks.map((blank, i) => {
    const raw = response.answers[i];
    if (typeof raw !== 'string') return false;
    const user = raw.trim();
    const caseSensitive = blank.caseSensitive === true;
    const userCmp = caseSensitive ? user : user.toLowerCase();
    return blank.accept.some((acc) => {
      const accTrim = acc.trim();
      const accCmp = caseSensitive ? accTrim : accTrim.toLowerCase();
      return accCmp === userCmp;
    });
  });

  const allMatched =
    response.answers.length === payload.blanks.length && perBlank.every((b) => b);

  return {
    correct: allMatched,
    scoreJson: { perBlank },
  };
}
