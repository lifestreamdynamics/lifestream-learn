import '@tests/unit/setup';
import { EventEmitter } from 'node:events';

// Mock child_process.execFile before importing the module under test.
// We simulate ffprobe output (or failure) by driving a fake stdout.
jest.mock('node:child_process', () => {
  const actual = jest.requireActual('node:child_process');
  return {
    ...actual,
    execFile: jest.fn(),
  };
});

import { execFile } from 'node:child_process';
import type { Logger } from 'pino';
import { logFfmpegVersion } from '@/services/ffmpeg/version-check';

function makeLogger(): jest.Mocked<Pick<Logger, 'info' | 'warn'>> {
  return {
    info: jest.fn(),
    warn: jest.fn(),
  } as unknown as jest.Mocked<Pick<Logger, 'info' | 'warn'>>;
}

// Signature matches node's promisified execFile: (err, { stdout, stderr }).
// The actual module uses promisify(execFile), which accepts the callback-style
// execFile that we're mocking here.
function mockExecFileOutput(stdout: string): void {
  (execFile as unknown as jest.Mock).mockImplementationOnce(
    (_bin: string, _args: string[], cb: (err: Error | null, result: { stdout: string; stderr: string }) => void) => {
      cb(null, { stdout, stderr: '' });
      return new EventEmitter();
    },
  );
}

function mockExecFileError(err: Error): void {
  (execFile as unknown as jest.Mock).mockImplementationOnce(
    (_bin: string, _args: string[], cb: (err: Error | null) => void) => {
      cb(err);
      return new EventEmitter();
    },
  );
}

describe('logFfmpegVersion', () => {
  beforeEach(() => {
    (execFile as unknown as jest.Mock).mockReset();
  });

  it('logs info with the parsed version when ffprobe >= 6.0', async () => {
    mockExecFileOutput('ffprobe version 6.1.1-3ubuntu5 Copyright (c) 2007-2023 the FFmpeg developers\n');
    const log = makeLogger();
    await logFfmpegVersion(log as unknown as Logger);
    expect(log.info).toHaveBeenCalledWith(
      expect.objectContaining({ ffprobeVersion: '6.1' }),
      expect.stringContaining('ok'),
    );
    expect(log.warn).not.toHaveBeenCalled();
  });

  it('warns when the detected major is below 6', async () => {
    mockExecFileOutput('ffprobe version 4.4.2-0ubuntu0 Copyright (c) 2007-2021 the FFmpeg developers\n');
    const log = makeLogger();
    await logFfmpegVersion(log as unknown as Logger);
    expect(log.warn).toHaveBeenCalledWith(
      expect.objectContaining({ detectedVersion: '4.4', minimum: '6.0' }),
      expect.stringContaining('below minimum'),
    );
    expect(log.info).not.toHaveBeenCalled();
  });

  it('warns when the output does not match the expected format', async () => {
    mockExecFileOutput('garbled nonsense\n');
    const log = makeLogger();
    await logFfmpegVersion(log as unknown as Logger);
    expect(log.warn).toHaveBeenCalledWith(
      expect.objectContaining({ firstLine: 'garbled nonsense' }),
      expect.stringContaining('not recognised'),
    );
  });

  it('does not throw when ffprobe is missing entirely — logs warn instead', async () => {
    mockExecFileError(Object.assign(new Error('ENOENT'), { code: 'ENOENT' }));
    const log = makeLogger();
    await expect(logFfmpegVersion(log as unknown as Logger)).resolves.toBeUndefined();
    expect(log.warn).toHaveBeenCalledWith(
      expect.objectContaining({ err: expect.any(Error) }),
      expect.stringContaining('unable to determine'),
    );
  });
});
