import type { LadderRung, ProbeResult } from '@/queues/transcode.types';

/**
 * Default ABR ladder for the MVP. Bitrates target H.264 Main @ ~24fps.
 * Always ordered ascending by height so `[0]` is the safest fallback rung.
 */
export const DEFAULT_LADDER: LadderRung[] = [
  { name: '360p', width: 640, height: 360, videoBitrateKbps: 800 },
  { name: '540p', width: 960, height: 540, videoBitrateKbps: 1400 },
  { name: '720p', width: 1280, height: 720, videoBitrateKbps: 2800 },
  { name: '1080p', width: 1920, height: 1080, videoBitrateKbps: 5000 },
];

/**
 * Pick the rungs whose target height does not exceed the source. We never
 * upscale. If the source is shorter than the smallest rung, still emit the
 * smallest rung (FFmpeg will downscale on the fly) so playback always has
 * something to play.
 */
export function selectLadder(
  probe: Pick<ProbeResult, 'height'>,
  ladder: LadderRung[] = DEFAULT_LADDER,
): LadderRung[] {
  const filtered = ladder.filter((rung) => rung.height <= probe.height);
  if (filtered.length === 0) return [ladder[0]];
  return filtered;
}
