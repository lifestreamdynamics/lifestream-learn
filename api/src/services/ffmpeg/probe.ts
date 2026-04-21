import { spawn } from 'node:child_process';
import { env } from '@/config/env';
import type { ProbeResult } from '@/queues/transcode.types';

interface FfprobeSideData {
  side_data_type?: string;
  rotation?: number;
}

interface FfprobeStream {
  codec_type?: string;
  codec_name?: string;
  width?: number;
  height?: number;
  sample_rate?: string | number;
  tags?: { rotate?: string | number };
  side_data_list?: FfprobeSideData[];
}

interface FfprobeFormat {
  duration?: string;
  format_name?: string;
}

interface FfprobeOutput {
  format?: FfprobeFormat;
  streams?: FfprobeStream[];
}

/**
 * Normalise ffprobe rotation metadata into one of 0 / 90 / 180 / 270.
 *
 * Containers expose rotation in two places:
 *   1) `side_data_list[*].rotation` on the video stream (modern MOV/MP4
 *      with a rotation matrix — ffprobe 5+).
 *   2) `tags.rotate` as a string on the video stream (legacy).
 *
 * A positive rotation from ffprobe means counter-clockwise. We fold all
 * values into the 0/90/180/270 clockwise convention the transpose filter
 * expects. A value ffprobe is unsure about (missing or non-multiple of
 * 90) is treated as 0 — the worst case is an unrotated render, which is
 * still playable and better than crashing the pipeline.
 */
function extractRotation(stream: FfprobeStream | undefined): 0 | 90 | 180 | 270 {
  if (!stream) return 0;
  let raw: number | null = null;
  const sideRot = stream.side_data_list?.find(
    (s) => typeof s.rotation === 'number',
  )?.rotation;
  if (typeof sideRot === 'number') {
    raw = sideRot;
  } else {
    const tag = stream.tags?.rotate;
    if (tag != null) {
      const parsed = typeof tag === 'number' ? tag : parseInt(String(tag), 10);
      if (Number.isFinite(parsed)) raw = parsed;
    }
  }
  if (raw == null) return 0;
  // ffprobe side-data rotation is CCW; `tags.rotate` is CW. Callers that
  // mix sources commonly see {-90, 90, 180, -180, 270, -270}. Normalise.
  const normalised = ((raw % 360) + 360) % 360;
  if (normalised === 90 || normalised === 180 || normalised === 270) {
    return normalised;
  }
  return 0;
}

/**
 * Run `ffprobe` against a local file and return a normalised summary.
 * Throws if ffprobe exits non-zero or stdout cannot be parsed as JSON.
 */
export function probeVideo(
  localPath: string,
  opts: { ffprobeBin?: string } = {},
): Promise<ProbeResult> {
  const bin = opts.ffprobeBin ?? env.FFPROBE_BIN;
  return new Promise<ProbeResult>((resolve, reject) => {
    // `-show_streams -show_format` already returns side_data_list entries
    // for the rotation matrix on modern MP4/MOV; older ffprobe versions
    // need `-show_entries stream_side_data_list` but FFmpeg 6.0+ (our
    // pinned minimum per version-check.ts) surfaces it by default.
    const child = spawn(bin, [
      '-v', 'error',
      '-print_format', 'json',
      '-show_streams',
      '-show_format',
      localPath,
    ], { stdio: ['ignore', 'pipe', 'pipe'] });

    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];

    child.stdout?.on('data', (chunk: Buffer) => stdoutChunks.push(chunk));
    child.stderr?.on('data', (chunk: Buffer) => stderrChunks.push(chunk));

    child.on('error', (err: Error) => reject(err));

    child.on('close', (code: number | null) => {
      if (code !== 0) {
        const stderr = Buffer.concat(stderrChunks).toString('utf8');
        reject(new Error(`ffprobe failed: ${stderr.slice(-200)}`));
        return;
      }
      try {
        const stdout = Buffer.concat(stdoutChunks).toString('utf8');
        const parsed = JSON.parse(stdout) as FfprobeOutput;
        const streams = parsed.streams ?? [];
        const videoStream = streams.find((s) => s.codec_type === 'video');
        const audioStream = streams.find((s) => s.codec_type === 'audio');
        if (!videoStream || typeof videoStream.width !== 'number' || typeof videoStream.height !== 'number') {
          reject(new Error('ffprobe: no video stream with width/height found'));
          return;
        }
        const durationSec = parseFloat(parsed.format?.duration ?? '0');
        const audioSampleRate = audioStream?.sample_rate != null
          ? parseInt(String(audioStream.sample_rate), 10)
          : null;
        const videoCodec = (videoStream.codec_name ?? '').toLowerCase();
        const audioCodec = audioStream?.codec_name
          ? audioStream.codec_name.toLowerCase()
          : null;
        const containerFormat = (parsed.format?.format_name ?? '').toLowerCase();
        resolve({
          durationMs: Math.round(durationSec * 1000),
          width: videoStream.width,
          height: videoStream.height,
          audioSampleRate: Number.isFinite(audioSampleRate) ? audioSampleRate : null,
          hasAudio: !!audioStream,
          containerFormat,
          videoCodec,
          audioCodec,
          rotationDegrees: extractRotation(videoStream),
        });
      } catch (err) {
        reject(err instanceof Error ? err : new Error(String(err)));
      }
    });
  });
}
