import path from 'node:path';
import type { LadderRung } from '@/queues/transcode.types';

/**
 * Build the argv passed to `ffmpeg` for a multi-rung HLS+fMP4 transcode.
 *
 * Output layout under `outputDir`:
 *   master.m3u8
 *   v_0/init_0.mp4, v_0/seg_001.m4s, v_0/index.m3u8
 *   v_1/init_1.mp4, ...
 *
 * Pure function — no side effects. The caller is responsible for creating
 * `outputDir` and the per-variant `v_<i>/` subdirectories before invoking
 * ffmpeg (FFmpeg's `%v` expansion does not create them).
 */
export function buildFfmpegArgs(
  ladder: LadderRung[],
  inputPath: string,
  outputDir: string,
): string[] {
  if (ladder.length === 0) {
    throw new Error('buildFfmpegArgs: ladder must not be empty');
  }

  // filter_complex: split the source video N ways and scale each branch.
  //   [0:v]split=N[v0][v1]...; [v0]scale=w=W0:h=H0[v0out]; [v1]scale=...
  const splitLabels = ladder.map((_, i) => `[v${i}]`).join('');
  const splitClause = `[0:v]split=${ladder.length}${splitLabels}`;
  const scaleClauses = ladder
    .map((rung, i) => `[v${i}]scale=w=${rung.width}:h=${rung.height}[v${i}out]`)
    .join('; ');
  const filterComplex = `${splitClause}; ${scaleClauses}`;

  const args: string[] = ['-y', '-i', inputPath, '-filter_complex', filterComplex];

  // Per-rung video + audio mappings and codec params.
  ladder.forEach((rung, i) => {
    const maxrateKbps = Math.round(rung.videoBitrateKbps * 1.07);
    const bufsizeKbps = rung.videoBitrateKbps * 2;
    args.push(
      '-map', `[v${i}out]`,
      '-map', '0:a:0?',
      `-c:v:${i}`, 'libx264',
      '-preset', 'veryfast',
      `-profile:v:${i}`, 'main',
      `-level:v:${i}`, '4.0',
      `-b:v:${i}`, `${rung.videoBitrateKbps}k`,
      `-maxrate:v:${i}`, `${maxrateKbps}k`,
      `-bufsize:v:${i}`, `${bufsizeKbps}k`,
      `-c:a:${i}`, 'aac',
      `-b:a:${i}`, '96k',
    );
  });

  // Global audio params (one set), GOP, and HLS packaging.
  args.push(
    '-ac', '2',
    '-ar', '48000',
    '-g', '48',
    '-keyint_min', '48',
    '-sc_threshold', '0',
    '-var_stream_map', ladder.map((_, i) => `v:${i},a:${i}`).join(' '),
    '-hls_time', '4',
    '-hls_playlist_type', 'vod',
    '-hls_segment_type', 'fmp4',
    '-hls_flags', 'independent_segments',
    '-hls_fmp4_init_filename', 'init_%v.mp4',
    '-hls_segment_filename', path.join(outputDir, 'v_%v/seg_%03d.m4s'),
    '-master_pl_name', 'master.m3u8',
    '-f', 'hls',
    path.join(outputDir, 'v_%v/index.m3u8'),
  );

  return args;
}
