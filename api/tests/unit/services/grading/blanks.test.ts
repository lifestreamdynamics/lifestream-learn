import '@tests/unit/setup';
import { gradeBlanks } from '@/services/grading/blanks';
import type { BlanksPayload, BlanksResponse } from '@/validators/cue-payloads';

const ONE_BLANK: BlanksPayload = {
  type: 'BLANKS',
  sentenceTemplate: 'The capital of France is {{0}}.',
  blanks: [{ accept: ['Paris'] }],
};

const TWO_BLANKS: BlanksPayload = {
  type: 'BLANKS',
  sentenceTemplate: '{{0}} is to {{1}} as cat is to kitten.',
  blanks: [
    { accept: ['Dog', 'Canine'] },
    { accept: ['Puppy'] },
  ],
};

describe('gradeBlanks', () => {
  it('correct when single answer matches case-insensitively (default)', () => {
    const r = gradeBlanks(ONE_BLANK, { answers: ['paris'] } as BlanksResponse);
    expect(r.correct).toBe(true);
    expect(r.scoreJson).toEqual({ perBlank: [true] });
  });

  it('trims whitespace on both sides', () => {
    const r = gradeBlanks(ONE_BLANK, { answers: ['   Paris   '] } as BlanksResponse);
    expect(r.correct).toBe(true);
  });

  it('case-insensitive by default', () => {
    const r = gradeBlanks(ONE_BLANK, { answers: ['PARIS'] } as BlanksResponse);
    expect(r.correct).toBe(true);
  });

  it('caseSensitive=true rejects wrong case', () => {
    const payload: BlanksPayload = {
      ...ONE_BLANK,
      blanks: [{ accept: ['Paris'], caseSensitive: true }],
    };
    const r = gradeBlanks(payload, { answers: ['paris'] } as BlanksResponse);
    expect(r.correct).toBe(false);
    expect(r.scoreJson).toEqual({ perBlank: [false] });
  });

  it('caseSensitive=true accepts exact case', () => {
    const payload: BlanksPayload = {
      ...ONE_BLANK,
      blanks: [{ accept: ['Paris'], caseSensitive: true }],
    };
    const r = gradeBlanks(payload, { answers: ['Paris'] } as BlanksResponse);
    expect(r.correct).toBe(true);
  });

  it('accept-list synonyms: any match counts as correct', () => {
    const r = gradeBlanks(TWO_BLANKS, { answers: ['Canine', 'Puppy'] } as BlanksResponse);
    expect(r.correct).toBe(true);
    expect(r.scoreJson).toEqual({ perBlank: [true, true] });
  });

  it('partial match reports perBlank array and correct=false', () => {
    const r = gradeBlanks(TWO_BLANKS, { answers: ['Dog', 'Kitten'] } as BlanksResponse);
    expect(r.correct).toBe(false);
    expect(r.scoreJson).toEqual({ perBlank: [true, false] });
  });

  it('mismatch: too few answers -> correct=false, perBlank still length=blanks', () => {
    const r = gradeBlanks(TWO_BLANKS, { answers: ['Dog'] } as BlanksResponse);
    expect(r.correct).toBe(false);
    expect((r.scoreJson as { perBlank: boolean[] }).perBlank).toHaveLength(2);
    expect((r.scoreJson as { perBlank: boolean[] }).perBlank[0]).toBe(true);
    expect((r.scoreJson as { perBlank: boolean[] }).perBlank[1]).toBe(false);
  });

  it('mismatch: too many answers -> correct=false', () => {
    const r = gradeBlanks(ONE_BLANK, { answers: ['Paris', 'Extra'] } as BlanksResponse);
    expect(r.correct).toBe(false);
    expect(r.scoreJson).toEqual({ perBlank: [true] });
  });

  it('trims accept-list entries too', () => {
    const payload: BlanksPayload = {
      ...ONE_BLANK,
      blanks: [{ accept: ['  Paris  '] }],
    };
    const r = gradeBlanks(payload, { answers: ['Paris'] } as BlanksResponse);
    expect(r.correct).toBe(true);
  });

  it('emits no explanation', () => {
    const r = gradeBlanks(ONE_BLANK, { answers: ['Paris'] } as BlanksResponse);
    expect(r.explanation).toBeUndefined();
  });

  it('defends against non-string user answer entries (cast through unknown)', () => {
    const r = gradeBlanks(ONE_BLANK, { answers: [123 as unknown as string] } as BlanksResponse);
    expect(r.correct).toBe(false);
    expect(r.scoreJson).toEqual({ perBlank: [false] });
  });
});
