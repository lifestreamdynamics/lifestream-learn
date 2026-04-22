import path from 'node:path';
import type { LadderRung } from '@/queues/transcode.types';

export interface BuildArgsOptions {
  /**
   * Clockwise rotation in degrees as reported by ffprobe (normalised to
   * 0 / 90 / 180 / 270 by `probe.ts`). When non-zero, each per-rung
   * scale branch gets a `transpose` filter prepended so the output
   * frames are upright. We also strip the rotation tag on the output so
   * a player that would otherwise auto-rotate doesn't rotate twice.
   * Default: 0 (no rotation).
   */
  rotationDegrees?: 0 | 90 | 180 | 270;
  /**
   * When false, the builder drops every audio-related flag (no `-map
   * 0:a`, no `-c:a`, no `-b:a`, no `-ac`, no `-ar`, no `-af`) and emits
   * a video-only `var_stream_map`. This lets silent sources flow
   * through the same pipeline without ffmpeg erroring on a missing
   * audio input. Default: true.
   */
  hasAudio?: boolean;
}

/**
 * Map a 0 / 90 / 180 / 270 clockwise rotation to the `transpose=` /
 * `hflip,vflip` filter chain ffmpeg understands.
 *
 *   transpose=1 — 90° clockwise
 *   transpose=2 — 90° counter-clockwise (270° CW)
 *   hflip,vflip — 180°
 *
 * Returns an empty string when rotation is 0 so callers can splice the
 * result into the filtergraph unconditionally.
 */
function rotationFilter(deg: 0 | 90 | 180 | 270): string {
  switch (deg) {
    case 90: return 'transpose=1';
    case 180: return 'hflip,vflip';
    case 270: return 'transpose=2';
    default: return '';
  }
}

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
 *
 * What the output is guaranteed to look like regardless of the input:
 *   - H.264 Main @ L4.0, CBR-ish with a 1.07× maxrate / 2× bufsize
 *   - 8-bit 4:2:0 chroma (`yuv420p`) — universal Android decoder path
 *   - BT.709 primaries/transfer/matrix with limited (`tv`) range —
 *     HDR-tagged inputs land as well-behaved SDR on the phone
 *   - AAC 48 kHz stereo, EBU R128 loudness-normalised to −16 LUFS
 *   - 4-second independent CMAF fMP4 segments, GOP = 48 frames
 *   - Any rotation metadata on the source is applied to the pixels and
 *     cleared from the output tags so a downstream player doesn't
 *     double-rotate.
 */
export function buildFfmpegArgs(
  ladder: LadderRung[],
  inputPath: string,
  outputDir: string,
  opts: BuildArgsOptions = {},
): string[] {
  if (ladder.length === 0) {
    throw new Error('buildFfmpegArgs: ladder must not be empty');
  }
  const rotation = opts.rotationDegrees ?? 0;
  const hasAudio = opts.hasAudio ?? true;
  const rotate = rotationFilter(rotation);
  // For 90°/270° the transpose filter swaps width and height before the
  // scale step. The LadderRung always stores landscape dimensions, so we
  // must flip the scale target to match the post-transpose frame orientation
  // and produce the correct portrait output dimensions (e.g. 360×640 instead
  // of 640×360 for the 360p rung of a portrait source).
  const isTransposed = rotation === 90 || rotation === 270;

  // filter_complex: split the source video N ways and (optionally rotate
  // then) scale each branch. The rotation filter is inserted between the
  // split and the scale so the scaled dimensions are always relative to
  // the post-rotate frame — a portrait source with rotation=90 stored as
  // 1080×1920 becomes an upright 1920×1080 frame before scaling.
  const splitLabels = ladder.map((_, i) => `[v${i}]`).join('');
  const splitClause = `[0:v]split=${ladder.length}${splitLabels}`;
  const scaleClauses = ladder
    .map((rung, i) => {
      const sw = isTransposed ? rung.height : rung.width;
      const sh = isTransposed ? rung.width : rung.height;
      const chain = rotate
        ? `${rotate},scale=w=${sw}:h=${sh}`
        : `scale=w=${sw}:h=${sh}`;
      return `[v${i}]${chain}[v${i}out]`;
    })
    .join('; ');
  const filterComplex = `${splitClause}; ${scaleClauses}`;

  const args: string[] = ['-y', '-i', inputPath, '-filter_complex', filterComplex];

  // Per-rung video + audio mappings and codec params.
  ladder.forEach((rung, i) => {
    const maxrateKbps = Math.round(rung.videoBitrateKbps * 1.07);
    const bufsizeKbps = rung.videoBitrateKbps * 2;
    args.push(
      '-map', `[v${i}out]`,
    );
    if (hasAudio) {
      args.push('-map', '0:a:0?');
    }
    args.push(
      `-c:v:${i}`, 'libx264',
      '-preset', 'veryfast',
      `-profile:v:${i}`, 'main',
      `-level:v:${i}`, '4.0',
      `-pix_fmt:v:${i}`, 'yuv420p',
      `-b:v:${i}`, `${rung.videoBitrateKbps}k`,
      `-maxrate:v:${i}`, `${maxrateKbps}k`,
      `-bufsize:v:${i}`, `${bufsizeKbps}k`,
      // Anchor colour metadata on the H.264 bitstream (BT.709, limited
      // range). Inputs tagged as HDR / BT.2020 get flattened to SDR; SDR
      // inputs become explicit BT.709. Android's default decoder path
      // interprets untagged streams inconsistently — making this
      // deterministic avoids "greyscale-looking" playback on some OEMs.
      `-colorspace:v:${i}`, 'bt709',
      `-color_primaries:v:${i}`, 'bt709',
      `-color_trc:v:${i}`, 'bt709',
      `-color_range:v:${i}`, 'tv',
      // Clear any rotation tag on the output. The pixels were already
      // rotated in the filtergraph; a residual tag would make compliant
      // players double-rotate.
      `-metadata:s:v:${i}`, 'rotate=0',
    );
    if (hasAudio) {
      args.push(
        `-c:a:${i}`, 'aac',
        `-b:a:${i}`, '96k',
      );
    }
  });

  // Global audio params + HLS packaging.
  if (hasAudio) {
    args.push(
      // EBU R128 loudness normalisation. −16 LUFS is the mobile target
      // (Apple Podcasts, YouTube, Spotify all hover around −14 to −16);
      // LRA=11 / TP=−1.5 are loudnorm's documented streaming defaults.
      // One-pass is accurate enough for our source lengths (≤3 min cap).
      '-af', 'loudnorm=I=-16:LRA=11:TP=-1.5',
      '-ac', '2',
      '-ar', '48000',
    );
  }
  args.push(
    '-g', '48',
    '-keyint_min', '48',
    '-sc_threshold', '0',
    '-var_stream_map',
    ladder
      .map((_, i) => (hasAudio ? `v:${i},a:${i}` : `v:${i}`))
      .join(' '),
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
