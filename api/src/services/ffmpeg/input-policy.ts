import type { ProbeResult } from '@/queues/transcode.types';

/**
 * Stable, DB-persisted failure reasons for videos that the pipeline
 * refuses to process. Keeping this a closed string-literal union (and
 * mirroring it as the `VideoFailureReason` Prisma enum) means the
 * Flutter client can ship a friendly localised message per reason
 * without ever needing to interpret an ffmpeg stack trace.
 *
 * Order matters for priority: bytes/duration are cheaper to check than
 * codec whitelists and are checked first in `assertInputAcceptable`, so
 * a single upload that trips multiple rules surfaces the outermost one.
 */
export type VideoFailureReason =
  | 'INPUT_TOO_LARGE'
  | 'DURATION_EXCEEDED'
  | 'UNSUPPORTED_CONTAINER'
  | 'UNSUPPORTED_VIDEO_CODEC'
  | 'UNSUPPORTED_AUDIO_CODEC'
  | 'CORRUPT_OR_UNREADABLE'
  | 'TRANSCODE_FAILED';

/**
 * A policy-rejection error carries the stable reason code so the
 * pipeline can persist it on `Video.failureReason` and the API can
 * surface it to the client without leaking stderr. The message is for
 * server logs; clients should map `reason` themselves.
 */
export class VideoPolicyError extends Error {
  readonly reason: VideoFailureReason;

  constructor(reason: VideoFailureReason, message: string) {
    super(message);
    this.name = 'VideoPolicyError';
    this.reason = reason;
  }
}

export interface InputPolicy {
  /** Hard byte cap on the raw upload. Re-checked against the downloaded file. */
  maxBytes: number;
  /** Re-use of the existing VIDEO_MAX_DURATION_MS. */
  maxDurationMs: number;
  /**
   * ffprobe `format.format_name` tokens. Matched by substring because
   * ffprobe returns compound names (`mov,mp4,m4a,3gp,3g2,mj2`,
   * `matroska,webm`). If any token from the probe's comma-split name
   * appears in the allow-list, the input passes.
   */
  allowedContainers: string[];
  /** ffprobe video `codec_name` tokens, lowercased. */
  allowedVideoCodecs: string[];
  /**
   * ffprobe audio `codec_name` tokens, lowercased. Only consulted when
   * the probe reports `hasAudio === true`; silent sources are allowed
   * through the audio codec gate unconditionally.
   */
  allowedAudioCodecs: string[];
}

/**
 * Throw a `VideoPolicyError` if the probed input violates any rule.
 * Pure function — no I/O, no logging, no side effects. The caller is
 * responsible for persisting the reason on the Video row and emitting
 * whatever metric is appropriate.
 *
 * Order of checks (first match wins):
 *   1) size cap
 *   2) duration cap
 *   3) container allow-list
 *   4) video codec allow-list
 *   5) audio codec allow-list (only if hasAudio)
 */
export function assertInputAcceptable(
  probe: ProbeResult,
  sizeBytes: number,
  policy: InputPolicy,
): void {
  if (sizeBytes > policy.maxBytes) {
    throw new VideoPolicyError(
      'INPUT_TOO_LARGE',
      `source size ${sizeBytes}B exceeds cap ${policy.maxBytes}B`,
    );
  }
  if (probe.durationMs > policy.maxDurationMs) {
    throw new VideoPolicyError(
      'DURATION_EXCEEDED',
      `source duration ${probe.durationMs}ms exceeds cap ${policy.maxDurationMs}ms`,
    );
  }
  if (!containerAllowed(probe.containerFormat, policy.allowedContainers)) {
    throw new VideoPolicyError(
      'UNSUPPORTED_CONTAINER',
      `container "${probe.containerFormat}" is not in the allow-list`,
    );
  }
  if (!policy.allowedVideoCodecs.includes(probe.videoCodec)) {
    throw new VideoPolicyError(
      'UNSUPPORTED_VIDEO_CODEC',
      `video codec "${probe.videoCodec}" is not in the allow-list`,
    );
  }
  if (probe.hasAudio && probe.audioCodec) {
    if (!policy.allowedAudioCodecs.includes(probe.audioCodec)) {
      throw new VideoPolicyError(
        'UNSUPPORTED_AUDIO_CODEC',
        `audio codec "${probe.audioCodec}" is not in the allow-list`,
      );
    }
  }
}

/**
 * ffprobe surfaces the MP4/MOV family as the compound string
 * `mov,mp4,m4a,3gp,3g2,mj2`. Split on commas and accept if any token
 * appears in the allow-list. Empty probe string → reject (we never saw
 * a format_name, so we can't vouch for it).
 */
function containerAllowed(probed: string, allowed: string[]): boolean {
  if (!probed) return false;
  const tokens = probed.split(',').map((t) => t.trim()).filter(Boolean);
  return tokens.some((t) => allowed.includes(t));
}
