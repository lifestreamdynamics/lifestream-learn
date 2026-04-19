import { spawn } from 'node:child_process';
import readline from 'node:readline';
import type { Logger } from 'pino';
import { env } from '@/config/env';
import { logger as defaultLogger } from '@/config/logger';

const TAIL_LINES = 20;

/**
 * Spawn `ffmpeg` with the given argv. Streams stderr line-by-line through the
 * provided logger at debug level and keeps the last `TAIL_LINES` lines in a
 * ring buffer so a non-zero exit error includes useful tail context.
 */
export function runFfmpeg(
  args: string[],
  opts: { ffmpegBin?: string; logger?: Logger } = {},
): Promise<void> {
  const bin = opts.ffmpegBin ?? env.FFMPEG_BIN;
  const log = opts.logger ?? defaultLogger;
  return new Promise<void>((resolve, reject) => {
    const child = spawn(bin, args, { stdio: ['ignore', 'pipe', 'pipe'] });

    const tail: string[] = [];

    if (child.stderr) {
      const rl = readline.createInterface({ input: child.stderr });
      rl.on('line', (line: string) => {
        log.debug({ ffmpeg: line }, 'ffmpeg');
        tail.push(line);
        if (tail.length > TAIL_LINES) tail.shift();
      });
    }

    child.on('error', (err: Error) => reject(err));

    child.on('close', (code: number | null) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`ffmpeg exited ${code}: ${tail.join('\n')}`));
    });
  });
}
