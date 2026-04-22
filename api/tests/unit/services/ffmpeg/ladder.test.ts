import '@tests/unit/setup';
import { DEFAULT_LADDER, selectLadder } from '@/services/ffmpeg/ladder';

describe('selectLadder', () => {
  describe('landscape sources (rotationDegrees 0 / 180)', () => {
    const cases: Array<{ width: number; height: number; rotationDegrees: 0 | 90 | 180 | 270; expectedNames: string[] }> = [
      { width: 160,  height: 100,  rotationDegrees: 0,   expectedNames: ['360p'] }, // tiny — falls back to smallest rung
      { width: 640,  height: 360,  rotationDegrees: 0,   expectedNames: ['360p'] },
      { width: 800,  height: 500,  rotationDegrees: 0,   expectedNames: ['360p'] }, // below 540, no upscale
      { width: 960,  height: 540,  rotationDegrees: 0,   expectedNames: ['360p', '540p'] },
      { width: 1280, height: 720,  rotationDegrees: 0,   expectedNames: ['360p', '540p', '720p'] },
      { width: 1400, height: 800,  rotationDegrees: 0,   expectedNames: ['360p', '540p', '720p'] }, // below 1080
      { width: 1920, height: 1080, rotationDegrees: 0,   expectedNames: ['360p', '540p', '720p', '1080p'] },
      { width: 3840, height: 2160, rotationDegrees: 0,   expectedNames: ['360p', '540p', '720p', '1080p'] }, // never upscale
      // 180° flip keeps the same effective dimensions
      { width: 1920, height: 1080, rotationDegrees: 180, expectedNames: ['360p', '540p', '720p', '1080p'] },
    ];

    it.each(cases)(
      'source $width×$height rot=$rotationDegrees -> rungs $expectedNames',
      ({ width, height, rotationDegrees, expectedNames }) => {
        const got = selectLadder({ width, height, rotationDegrees }).map((r) => r.name);
        expect(got).toEqual(expectedNames);
      },
    );
  });

  describe('portrait sources (rotationDegrees 90 / 270) — effectiveHeight = probe.width', () => {
    it('1080×1920 rot=90 treated the same as a 1920×1080 landscape source', () => {
      const got = selectLadder({ width: 1080, height: 1920, rotationDegrees: 90 }).map((r) => r.name);
      expect(got).toEqual(['360p', '540p', '720p', '1080p']);
    });

    it('1080×1920 rot=270 treated the same as a 1920×1080 landscape source', () => {
      const got = selectLadder({ width: 1080, height: 1920, rotationDegrees: 270 }).map((r) => r.name);
      expect(got).toEqual(['360p', '540p', '720p', '1080p']);
    });

    it('480×854 rot=90 limits to rungs ≤ 480p effectiveHeight', () => {
      // effectiveHeight = probe.width = 480 → rungs with height ≤ 480: 360p only
      const got = selectLadder({ width: 480, height: 854, rotationDegrees: 90 }).map((r) => r.name);
      expect(got).toEqual(['360p']);
    });

    it('480×854 rot=270 same as rot=90', () => {
      const got = selectLadder({ width: 480, height: 854, rotationDegrees: 270 }).map((r) => r.name);
      expect(got).toEqual(['360p']);
    });

    it('720×1280 rot=90 → effectiveHeight 720 → 3 rungs', () => {
      const got = selectLadder({ width: 720, height: 1280, rotationDegrees: 90 }).map((r) => r.name);
      expect(got).toEqual(['360p', '540p', '720p']);
    });
  });

  it('returns rungs in ascending height order', () => {
    const got = selectLadder({ width: 1920, height: 1080, rotationDegrees: 0 });
    const heights = got.map((r) => r.height);
    expect(heights).toEqual([...heights].sort((a, b) => a - b));
  });

  it('falls back to the smallest rung when source is shorter than minimum', () => {
    const got = selectLadder({ width: 1, height: 1, rotationDegrees: 0 });
    expect(got).toHaveLength(1);
    expect(got[0]).toEqual(DEFAULT_LADDER[0]);
  });
});
