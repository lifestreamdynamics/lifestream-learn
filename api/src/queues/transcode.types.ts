export interface TranscodeJobData {
  videoId: string;
  sourceKey: string;
}

export interface TranscodeJobResult {
  hlsPrefix: string;
  durationMs: number;
  rungCount: number;
}

export interface LadderRung {
  name: string;
  width: number;
  height: number;
  videoBitrateKbps: number;
}

export interface ProbeResult {
  durationMs: number;
  width: number;
  height: number;
  audioSampleRate: number | null;
  hasAudio: boolean;
  /**
   * ffprobe `format.format_name` (may be a comma-separated list like
   * `mov,mp4,m4a,3gp,3g2,mj2` for the ISO BMFF family). Empty string if
   * ffprobe didn't surface one.
   */
  containerFormat: string;
  /** ffprobe video stream `codec_name`, lowercased. e.g. `h264`, `hevc`, `vp9`, `av1`. */
  videoCodec: string;
  /** ffprobe audio stream `codec_name`, lowercased. `null` when `hasAudio === false`. */
  audioCodec: string | null;
  /**
   * Rotation in degrees as reported by ffprobe — either via the rotate
   * side-data entry (modern container) or the legacy `tags.rotate` string
   * on the video stream. Normalised to one of 0 / 90 / 180 / 270.
   * A source tagged for rotation but with matrix baked into the stream
   * (after an editor "auto-rotate") reports 0.
   */
  rotationDegrees: 0 | 90 | 180 | 270;
}
