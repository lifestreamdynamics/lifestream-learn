import type { McqPayload, McqResponse } from '@/validators/cue-payloads';
import type { GradingResult } from '@/services/grading/types';

/**
 * Grade an MCQ response. Pure function — no I/O.
 *
 * `scoreJson.selected` lets analytics answer "which distractor was most
 * tempting?" without us having to re-derive it. Explanation is passed through
 * on both outcomes so the learner always gets the teaching moment.
 */
export function gradeMcq(payload: McqPayload, response: McqResponse): GradingResult {
  const correct = response.choiceIndex === payload.answerIndex;
  return {
    correct,
    scoreJson: { selected: response.choiceIndex },
    explanation: payload.explanation,
  };
}
