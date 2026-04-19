import '@tests/unit/setup';
import { gradeMcq } from '@/services/grading/mcq';
import type { McqPayload, McqResponse } from '@/validators/cue-payloads';

function payload(overrides: Partial<McqPayload> = {}): McqPayload {
  return {
    type: 'MCQ',
    question: 'What is 2+2?',
    choices: ['3', '4', '5', '6'],
    answerIndex: 1,
    ...overrides,
  };
}

describe('gradeMcq', () => {
  it('correct when choiceIndex matches answerIndex', () => {
    const r = gradeMcq(payload(), { choiceIndex: 1 });
    expect(r.correct).toBe(true);
    expect(r.scoreJson).toEqual({ selected: 1 });
  });

  it('incorrect when choiceIndex does not match', () => {
    const r = gradeMcq(payload(), { choiceIndex: 0 });
    expect(r.correct).toBe(false);
    expect(r.scoreJson).toEqual({ selected: 0 });
  });

  it('passes explanation through on correct', () => {
    const r = gradeMcq(payload({ explanation: 'Because math.' }), { choiceIndex: 1 });
    expect(r.explanation).toBe('Because math.');
  });

  it('passes explanation through on incorrect', () => {
    const r = gradeMcq(payload({ explanation: 'Because math.' }), { choiceIndex: 3 });
    expect(r.explanation).toBe('Because math.');
    expect(r.correct).toBe(false);
  });

  it('omits explanation when payload has none', () => {
    const r = gradeMcq(payload(), { choiceIndex: 1 });
    expect(r.explanation).toBeUndefined();
  });

  it.each([
    [0, 0, true],
    [1, 1, true],
    [2, 2, true],
    [3, 3, true],
    [0, 3, false],
    [3, 0, false],
  ])(
    'answerIndex=%s choiceIndex=%s -> correct=%s',
    (answerIndex: number, choiceIndex: number, expected: boolean) => {
      const r = gradeMcq(payload({ answerIndex }), { choiceIndex } as McqResponse);
      expect(r.correct).toBe(expected);
    },
  );
});
