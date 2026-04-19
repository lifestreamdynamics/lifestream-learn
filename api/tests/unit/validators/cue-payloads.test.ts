import '@tests/unit/setup';
import {
  cuePayloadSchema,
  extractPlaceholderIndices,
  parseResponseFor,
} from '@/validators/cue-payloads';
import { ValidationError } from '@/utils/errors';

describe('extractPlaceholderIndices', () => {
  it('returns distinct indices in order of first appearance', () => {
    expect(extractPlaceholderIndices('a {{1}} b {{0}} c {{1}} d')).toEqual([1, 0]);
  });

  it('empty when no placeholders', () => {
    expect(extractPlaceholderIndices('no placeholders here')).toEqual([]);
  });

  it('deduplicates repeated indices', () => {
    expect(extractPlaceholderIndices('{{0}} {{0}} {{0}}')).toEqual([0]);
  });
});

describe('cuePayloadSchema (discriminated union)', () => {
  describe('MCQ', () => {
    const valid = {
      type: 'MCQ' as const,
      question: 'q',
      choices: ['a', 'b', 'c'],
      answerIndex: 1,
    };

    it('accepts a valid payload', () => {
      expect(cuePayloadSchema.safeParse(valid).success).toBe(true);
    });

    it('accepts optional explanation', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, explanation: 'because' });
      expect(r.success).toBe(true);
    });

    it('rejects answerIndex out of range (>= choices.length)', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, answerIndex: 3 });
      expect(r.success).toBe(false);
    });

    it('rejects fewer than 2 choices', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, choices: ['a'] });
      expect(r.success).toBe(false);
    });

    it('rejects more than 4 choices', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, choices: ['a', 'b', 'c', 'd', 'e'] });
      expect(r.success).toBe(false);
    });

    it('rejects empty question', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, question: '' });
      expect(r.success).toBe(false);
    });

    it('rejects empty choice string', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, choices: ['a', ''] });
      expect(r.success).toBe(false);
    });

    it('rejects negative answerIndex', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, answerIndex: -1 });
      expect(r.success).toBe(false);
    });

    it('rejects non-integer answerIndex', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, answerIndex: 1.5 });
      expect(r.success).toBe(false);
    });
  });

  describe('BLANKS', () => {
    const valid = {
      type: 'BLANKS' as const,
      sentenceTemplate: 'x {{0}} y',
      blanks: [{ accept: ['hello'] }],
    };

    it('accepts a valid payload', () => {
      expect(cuePayloadSchema.safeParse(valid).success).toBe(true);
    });

    it('accepts caseSensitive on blanks', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        blanks: [{ accept: ['Hello'], caseSensitive: true }],
      });
      expect(r.success).toBe(true);
    });

    it('rejects template with no placeholders', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, sentenceTemplate: 'no placeholders' });
      expect(r.success).toBe(false);
    });

    it('rejects placeholder count mismatch (too few)', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        sentenceTemplate: '{{0}} {{1}}',
        blanks: [{ accept: ['a'] }],
      });
      expect(r.success).toBe(false);
    });

    it('rejects placeholder count mismatch (too many)', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        sentenceTemplate: '{{0}}',
        blanks: [{ accept: ['a'] }, { accept: ['b'] }],
      });
      expect(r.success).toBe(false);
    });

    it('rejects template with non-contiguous placeholders (skips {{1}})', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        sentenceTemplate: '{{0}} {{2}}',
        blanks: [{ accept: ['a'] }, { accept: ['b'] }],
      });
      expect(r.success).toBe(false);
    });

    it('accepts reordered placeholders as long as 0..N-1 all appear exactly once', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        sentenceTemplate: '{{1}} comes before {{0}}',
        blanks: [{ accept: ['a'] }, { accept: ['b'] }],
      });
      expect(r.success).toBe(true);
    });

    it('rejects empty blanks array', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, blanks: [] });
      expect(r.success).toBe(false);
    });

    it('rejects empty accept array', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, blanks: [{ accept: [] }] });
      expect(r.success).toBe(false);
    });

    it('rejects empty accept string', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, blanks: [{ accept: [''] }] });
      expect(r.success).toBe(false);
    });
  });

  describe('MATCHING', () => {
    const valid = {
      type: 'MATCHING' as const,
      prompt: 'p',
      left: ['a', 'b', 'c'],
      right: ['d', 'e', 'f'],
      pairs: [
        [0, 0],
        [1, 1],
        [2, 2],
      ],
    };

    it('accepts a valid payload', () => {
      expect(cuePayloadSchema.safeParse(valid).success).toBe(true);
    });

    it('accepts pairs leaving some items unmatched (distractors allowed)', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        left: ['a', 'b', 'c', 'd'],
        right: ['w', 'x', 'y', 'z'],
        pairs: [[0, 0], [1, 1]],
      });
      expect(r.success).toBe(true);
    });

    it('rejects duplicate pairs', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        pairs: [[0, 0], [0, 0]],
      });
      expect(r.success).toBe(false);
    });

    it('rejects left index reuse', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        pairs: [[0, 0], [0, 1]],
      });
      expect(r.success).toBe(false);
    });

    it('rejects right index reuse', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        pairs: [[0, 0], [1, 0]],
      });
      expect(r.success).toBe(false);
    });

    it('rejects leftIdx out of range', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        pairs: [[3, 0]],
      });
      expect(r.success).toBe(false);
    });

    it('rejects rightIdx out of range', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        pairs: [[0, 3]],
      });
      expect(r.success).toBe(false);
    });

    it('rejects fewer than 2 left items', () => {
      const r = cuePayloadSchema.safeParse({
        ...valid,
        left: ['only-one'],
        pairs: [[0, 0]],
      });
      expect(r.success).toBe(false);
    });

    it('rejects empty pairs', () => {
      const r = cuePayloadSchema.safeParse({ ...valid, pairs: [] });
      expect(r.success).toBe(false);
    });
  });

  describe('VOICE', () => {
    it('accepts a permissive VOICE payload (write gate is at service layer)', () => {
      const r = cuePayloadSchema.safeParse({ type: 'VOICE', anything: 'goes' });
      expect(r.success).toBe(true);
    });
  });

  it('rejects unknown discriminator value', () => {
    const r = cuePayloadSchema.safeParse({ type: 'NOPE' });
    expect(r.success).toBe(false);
  });
});

describe('parseResponseFor', () => {
  it('MCQ: accepts valid {choiceIndex}', () => {
    const r = parseResponseFor('MCQ', { choiceIndex: 2 });
    expect(r).toEqual({ choiceIndex: 2 });
  });

  it('MCQ: rejects out-of-range choiceIndex', () => {
    expect(() => parseResponseFor('MCQ', { choiceIndex: 5 })).toThrow(ValidationError);
  });

  it('MCQ: rejects missing choiceIndex', () => {
    expect(() => parseResponseFor('MCQ', {})).toThrow(ValidationError);
  });

  it('BLANKS: accepts valid {answers}', () => {
    const r = parseResponseFor('BLANKS', { answers: ['a', 'b'] });
    expect(r).toEqual({ answers: ['a', 'b'] });
  });

  it('BLANKS: rejects empty answers array', () => {
    expect(() => parseResponseFor('BLANKS', { answers: [] })).toThrow(ValidationError);
  });

  it('MATCHING: accepts valid {userPairs}', () => {
    const r = parseResponseFor('MATCHING', { userPairs: [[0, 1], [1, 2]] });
    expect(r).toEqual({ userPairs: [[0, 1], [1, 2]] });
  });

  it('MATCHING: accepts empty userPairs (grader handles correctness)', () => {
    const r = parseResponseFor('MATCHING', { userPairs: [] });
    expect(r).toEqual({ userPairs: [] });
  });

  it('VOICE: throws ValidationError (service layer rejects with 501 earlier)', () => {
    expect(() => parseResponseFor('VOICE', {})).toThrow(ValidationError);
  });
});
