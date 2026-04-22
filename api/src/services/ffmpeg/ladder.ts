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
 *
 * For portrait sources (rotationDegrees 90 or 270) the stored width/height
 * are the raw sensor dimensions before the transpose filter is applied, so
 * the effective landscape height is `probe.width`. We use that value when
 * selecting rungs so a 1080×1920 portrait source is treated the same as a
 * 1920×1080 landscape source.
 */
export function selectLadder(
  probe: Pick<ProbeResult, 'width' | 'height' | 'rotationDegrees'>,
  ladder: LadderRung[] = DEFAULT_LADDER,
): LadderRung[] {
  const isTransposed = probe.rotationDegrees === 90 || probe.rotationDegrees === 270;
  const effectiveHeight = isTransposed ? probe.width : probe.height;
  const filtered = ladder.filter((rung) => rung.height <= effectiveHeight);
  if (filtered.length === 0) return [ladder[0]];
  return filtered;
}
