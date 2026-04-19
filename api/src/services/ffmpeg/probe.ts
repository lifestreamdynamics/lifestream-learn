import { spawn } from 'node:child_process';
import { env } from '@/config/env';
import type { ProbeResult } from '@/queues/transcode.types';

interface FfprobeStream {
  codec_type?: string;
  width?: number;
  height?: number;
  sample_rate?: string | number;
}

interface FfprobeFormat {
  duration?: string;
}

interface FfprobeOutput {
  format?: FfprobeFormat;
  streams?: FfprobeStream[];
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
        resolve({
          durationMs: Math.round(durationSec * 1000),
          width: videoStream.width,
          height: videoStream.height,
          audioSampleRate: Number.isFinite(audioSampleRate) ? audioSampleRate : null,
          hasAudio: !!audioStream,
        });
      } catch (err) {
        reject(err instanceof Error ? err : new Error(String(err)));
      }
    });
  });
}
