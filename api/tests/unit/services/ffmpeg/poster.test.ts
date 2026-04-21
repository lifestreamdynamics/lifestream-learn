import '@tests/unit/setup';
import { buildPosterArgs, POSTER_FILENAME, posterKey } from '@/services/ffmpeg/poster';

describe('buildPosterArgs', () => {
  const IN = '/tmp/in/source.mp4';
  const OUT = '/tmp/out/poster.jpg';

  it('seeks to 1 second before decoding (-ss before -i)', () => {
    const args = buildPosterArgs(IN, OUT);
    const ssIdx = args.indexOf('-ss');
    const iIdx = args.indexOf('-i');
    expect(ssIdx).toBeGreaterThanOrEqual(0);
    expect(iIdx).toBeGreaterThanOrEqual(0);
    expect(ssIdx).toBeLessThan(iIdx);
    expect(args[ssIdx + 1]).toBe('1');
  });

  it('outputs exactly one frame at 640px width, keeping aspect (-2 rounds to even)', () => {
    const args = buildPosterArgs(IN, OUT);
    const vfIdx = args.indexOf('-vf');
    expect(args[vfIdx + 1]).toBe('scale=640:-2');
    expect(args.indexOf('-vframes')).toBeGreaterThan(-1);
    expect(args[args.indexOf('-vframes') + 1]).toBe('1');
  });

  it('passes -update 1 and image2 muxer to suppress ffmpeg muxer warnings', () => {
    const args = buildPosterArgs(IN, OUT);
    expect(args).toContain('-update');
    expect(args).toContain('-f');
    expect(args[args.indexOf('-f') + 1]).toBe('image2');
  });

  it('uses quality 3 (good size/quality for a feed thumb)', () => {
    const args = buildPosterArgs(IN, OUT);
    const qIdx = args.indexOf('-q:v');
    expect(args[qIdx + 1]).toBe('3');
  });

  it('places the output path as the final argv entry', () => {
    const args = buildPosterArgs(IN, OUT);
    expect(args[args.length - 1]).toBe(OUT);
  });
});

describe('posterKey', () => {
  it('returns the canonical vod/<videoId>/poster.jpg layout', () => {
    expect(posterKey('abc-123')).toBe('vod/abc-123/poster.jpg');
    expect(POSTER_FILENAME).toBe('poster.jpg');
  });
});
