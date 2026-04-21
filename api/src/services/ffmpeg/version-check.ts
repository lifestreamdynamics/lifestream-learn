import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import type { Logger } from 'pino';
import { env } from '@/config/env';

const execFileAsync = promisify(execFile);

// We require FFmpeg 6.0+ because the CMAF fMP4 HLS muxer flags we use
// (`-hls_segment_type fmp4`, `-hls_flags independent_segments`) landed
// in 6.0; older builds produce inconsistent segment boundaries that
// break ExoPlayer ABR. The ladder in build-args.ts is tuned for 6.x.
const MIN_MAJOR = 6;

/**
 * Runs `ffprobe -version` at worker startup and logs the result. If the
 * detected major is below `MIN_MAJOR`, emits a warning so operators notice
 * before a real job fails mid-transcode. Never throws: a missing or
 * unparseable `ffprobe` is surfaced as a warn so the worker can still boot
 * and fail the first job loudly instead of refusing to start.
 */
export async function logFfmpegVersion(log: Logger): Promise<void> {
  try {
    const { stdout } = await execFileAsync(env.FFPROBE_BIN, ['-version']);
    const firstLine = stdout.split('\n')[0] ?? '';
    const match = firstLine.match(/ffprobe version (\d+)\.(\d+)/);
    if (!match) {
      log.warn({ firstLine }, 'ffprobe version string not recognised');
      return;
    }
    const major = Number(match[1]);
    const minor = Number(match[2]);
    if (major < MIN_MAJOR) {
      log.warn(
        { detectedVersion: `${major}.${minor}`, minimum: `${MIN_MAJOR}.0` },
        'ffprobe below minimum supported version — transcodes may fail',
      );
    } else {
      log.info({ ffprobeVersion: `${major}.${minor}` }, 'ffprobe version ok');
    }
  } catch (err) {
    log.warn({ err }, 'unable to determine ffprobe version at startup');
  }
}
