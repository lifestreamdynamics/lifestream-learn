import { NotImplementedError } from '@/utils/errors';

/**
 * VOICE grading is deferred post-MVP (ADR 0004). This is defence-in-depth:
 * the controller rejects VOICE cue creation with 501 before anything gets
 * stored, and `parseResponseFor` rejects VOICE response shapes. This
 * function exists so the `grade()` dispatcher has a total mapping over
 * CueType and can never silently fall through.
 */
export function gradeVoice(): never {
  throw new NotImplementedError('VOICE cues are not yet supported');
}
