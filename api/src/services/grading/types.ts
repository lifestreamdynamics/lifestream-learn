/**
 * Shared grading result shape. `scoreJson` is persisted on Attempt as-is; the
 * only true server-side secret is whatever the client does NOT see. We pick
 * per-type shapes that are useful to the learner (e.g. perBlank[] lets the UI
 * highlight which blanks were wrong) without leaking the correct answer.
 */
export interface GradingResult {
  correct: boolean;
  scoreJson: Record<string, unknown> | null;
  explanation?: string;
}
