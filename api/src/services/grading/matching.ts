import type { MatchingPayload, MatchingResponse } from '@/validators/cue-payloads';
import type { GradingResult } from '@/services/grading/types';

/**
 * Grade a MATCHING response using set semantics over `leftIdx:rightIdx` keys.
 *
 * Pairs are ordered left→right (never sort within a pair — a pair is a
 * directed edge in the matching graph). Duplicate user pairs collapse into
 * one because we key into a Set. `correct` is true iff the two sets are
 * equal (same membership).
 *
 * `scoreJson.correctPairs` is the count of user-submitted pairs that exist
 * in the answer set; `totalPairs` is the size of the answer set. Useful for
 * partial-credit surfacing without leaking which pairs were right.
 *
 * Pure function — no I/O.
 */
export function gradeMatching(
  payload: MatchingPayload,
  response: MatchingResponse,
): GradingResult {
  const keyOf = (p: readonly [number, number]): string => `${p[0]}:${p[1]}`;
  const answerSet = new Set(payload.pairs.map(keyOf));
  const userSet = new Set(response.userPairs.map(keyOf));

  let correctPairs = 0;
  for (const k of userSet) {
    if (answerSet.has(k)) correctPairs += 1;
  }

  // Set equality: same size, same members.
  let setsEqual = userSet.size === answerSet.size;
  if (setsEqual) {
    for (const k of answerSet) {
      if (!userSet.has(k)) {
        setsEqual = false;
        break;
      }
    }
  }

  return {
    correct: setsEqual,
    scoreJson: { correctPairs, totalPairs: answerSet.size },
  };
}
