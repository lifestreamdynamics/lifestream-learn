import '@tests/unit/setup';
import { grade } from '@/services/grading';
import { NotImplementedError } from '@/utils/errors';
import type {
  BlanksPayload,
  MatchingPayload,
  McqPayload,
} from '@/validators/cue-payloads';

describe('grade dispatcher', () => {
  it('dispatches MCQ', () => {
    const payload: McqPayload = {
      type: 'MCQ',
      question: 'q',
      choices: ['a', 'b'],
      answerIndex: 0,
    };
    const r = grade('MCQ', payload, { choiceIndex: 0 });
    expect(r.correct).toBe(true);
  });

  it('dispatches BLANKS', () => {
    const payload: BlanksPayload = {
      type: 'BLANKS',
      sentenceTemplate: '{{0}}',
      blanks: [{ accept: ['x'] }],
    };
    const r = grade('BLANKS', payload, { answers: ['x'] });
    expect(r.correct).toBe(true);
  });

  it('dispatches MATCHING', () => {
    const payload: MatchingPayload = {
      type: 'MATCHING',
      prompt: 'p',
      left: ['a', 'b'],
      right: ['c', 'd'],
      pairs: [[0, 0]],
    };
    const r = grade('MATCHING', payload, { userPairs: [[0, 0]] });
    expect(r.correct).toBe(true);
  });

  it('VOICE throws NotImplementedError', () => {
    expect(() =>
      grade('VOICE', {} as unknown, { choiceIndex: 0 } as unknown as Parameters<typeof grade>[2]),
    ).toThrow(NotImplementedError);
  });
});
