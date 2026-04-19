import '@tests/unit/setup';
import { gradeMatching } from '@/services/grading/matching';
import type { MatchingPayload, MatchingResponse } from '@/validators/cue-payloads';

const PAYLOAD: MatchingPayload = {
  type: 'MATCHING',
  prompt: 'Match the capitals',
  left: ['France', 'Germany', 'Spain'],
  right: ['Berlin', 'Paris', 'Madrid'],
  // Canonical pairs: France->Paris(1), Germany->Berlin(0), Spain->Madrid(2)
  pairs: [
    [0, 1],
    [1, 0],
    [2, 2],
  ],
};

describe('gradeMatching', () => {
  it('correct when userPairs set equals payload pairs set', () => {
    const r = gradeMatching(PAYLOAD, {
      userPairs: [
        [0, 1],
        [1, 0],
        [2, 2],
      ],
    } as MatchingResponse);
    expect(r.correct).toBe(true);
    expect(r.scoreJson).toEqual({ correctPairs: 3, totalPairs: 3 });
  });

  it('correct when user submits same pairs in a different order (set semantics)', () => {
    const r = gradeMatching(PAYLOAD, {
      userPairs: [
        [2, 2],
        [0, 1],
        [1, 0],
      ],
    } as MatchingResponse);
    expect(r.correct).toBe(true);
  });

  it('incorrect when user has an extra pair', () => {
    const r = gradeMatching(PAYLOAD, {
      userPairs: [
        [0, 1],
        [1, 0],
        [2, 2],
        [0, 0], // wrong extra
      ],
    } as MatchingResponse);
    expect(r.correct).toBe(false);
    expect(r.scoreJson).toEqual({ correctPairs: 3, totalPairs: 3 });
  });

  it('incorrect when user is missing a pair', () => {
    const r = gradeMatching(PAYLOAD, {
      userPairs: [
        [0, 1],
        [1, 0],
      ],
    } as MatchingResponse);
    expect(r.correct).toBe(false);
    expect(r.scoreJson).toEqual({ correctPairs: 2, totalPairs: 3 });
  });

  it('incorrect when user has wrong pair (reversed direction)', () => {
    const r = gradeMatching(PAYLOAD, {
      userPairs: [
        [1, 1],
        [1, 0],
        [2, 2],
      ],
    } as MatchingResponse);
    expect(r.correct).toBe(false);
    expect(r.scoreJson).toEqual({ correctPairs: 2, totalPairs: 3 });
  });

  it('duplicate pairs in user response collapse (set semantics)', () => {
    const r = gradeMatching(PAYLOAD, {
      userPairs: [
        [0, 1],
        [0, 1], // duplicate — collapses to one member in the Set
        [1, 0],
        [2, 2],
      ],
    } as MatchingResponse);
    // After dedupe user has 3 correct pairs; sizes match -> correct.
    expect(r.correct).toBe(true);
    expect(r.scoreJson).toEqual({ correctPairs: 3, totalPairs: 3 });
  });

  it('empty user response -> incorrect', () => {
    const r = gradeMatching(PAYLOAD, { userPairs: [] } as MatchingResponse);
    expect(r.correct).toBe(false);
    expect(r.scoreJson).toEqual({ correctPairs: 0, totalPairs: 3 });
  });

  it('emits no explanation', () => {
    const r = gradeMatching(PAYLOAD, { userPairs: [[0, 1], [1, 0], [2, 2]] } as MatchingResponse);
    expect(r.explanation).toBeUndefined();
  });
});
