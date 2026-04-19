import '@tests/unit/setup';
import { DEFAULT_LADDER, selectLadder } from '@/services/ffmpeg/ladder';

describe('selectLadder', () => {
  const cases: Array<{ height: number; expectedNames: string[] }> = [
    { height: 100, expectedNames: ['360p'] }, // tiny — falls back to smallest rung
    { height: 360, expectedNames: ['360p'] },
    { height: 500, expectedNames: ['360p'] }, // below 540, no upscale
    { height: 540, expectedNames: ['360p', '540p'] },
    { height: 720, expectedNames: ['360p', '540p', '720p'] },
    { height: 800, expectedNames: ['360p', '540p', '720p'] }, // below 1080
    { height: 1080, expectedNames: ['360p', '540p', '720p', '1080p'] },
    { height: 2160, expectedNames: ['360p', '540p', '720p', '1080p'] }, // never upscale, never include phantom rungs
  ];

  it.each(cases)('source height %s -> rungs', ({ height, expectedNames }) => {
    const got = selectLadder({ height }).map((r) => r.name);
    expect(got).toEqual(expectedNames);
  });

  it('returns rungs in ascending height order', () => {
    const got = selectLadder({ height: 1080 });
    const heights = got.map((r) => r.height);
    expect(heights).toEqual([...heights].sort((a, b) => a - b));
  });

  it('falls back to the smallest rung when source is shorter than minimum', () => {
    const got = selectLadder({ height: 1 });
    expect(got).toHaveLength(1);
    expect(got[0]).toEqual(DEFAULT_LADDER[0]);
  });
});
