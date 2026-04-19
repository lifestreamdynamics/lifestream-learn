import '@tests/unit/setup';
import { EventEmitter } from 'node:events';
import { Readable } from 'node:stream';

jest.mock('node:child_process', () => ({
  spawn: jest.fn(),
}));

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { spawn } = require('node:child_process') as { spawn: jest.Mock };
import { runFfmpeg } from '@/services/ffmpeg/run-ffmpeg';

interface FakeChild extends EventEmitter {
  stdout: EventEmitter;
  stderr: Readable;
}

function makeChild(): FakeChild {
  const child = new EventEmitter() as FakeChild;
  child.stdout = new EventEmitter();
  // Use a real Readable so readline.createInterface can consume it.
  child.stderr = new Readable({ read() {} });
  return child;
}

describe('runFfmpeg', () => {
  beforeEach(() => {
    spawn.mockReset();
  });

  it('resolves on exit code 0', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const promise = runFfmpeg(['-y', '-i', 'in.mp4', 'out.mp4']);
    setImmediate(() => {
      child.stderr.push('frame=  1 fps=0 q=-1.0\n');
      child.stderr.push(null);
      child.emit('close', 0);
    });

    await expect(promise).resolves.toBeUndefined();
    expect(spawn).toHaveBeenCalledTimes(1);
    const [, args] = spawn.mock.calls[0];
    expect(args).toEqual(['-y', '-i', 'in.mp4', 'out.mp4']);
  });

  it('rejects with stderr tail (last 20 lines) on non-zero exit', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const promise = runFfmpeg(['-y', '-i', 'in.mp4', 'out.mp4']);
    setImmediate(() => {
      // Emit 30 lines; expect the rejection message to contain the LAST
      // line and NOT the first.
      for (let i = 0; i < 30; i += 1) {
        child.stderr.push(`line ${i}\n`);
      }
      child.stderr.push(null);
      child.emit('close', 1);
    });

    await expect(promise).rejects.toThrow(/ffmpeg exited 1/);
    // Re-issue to inspect the message body.
    const child2 = makeChild();
    spawn.mockReturnValueOnce(child2);
    const p2 = runFfmpeg(['x']);
    setImmediate(() => {
      for (let i = 0; i < 30; i += 1) child2.stderr.push(`line ${i}\n`);
      child2.stderr.push(null);
      child2.emit('close', 7);
    });
    try {
      await p2;
      throw new Error('expected rejection');
    } catch (err) {
      const msg = (err as Error).message;
      expect(msg).toContain('ffmpeg exited 7');
      expect(msg).toContain('line 29');
      expect(msg).toContain('line 10'); // 20 lines means lines 10..29 retained
      expect(msg).not.toContain('line 9');
    }
  });

  it('rejects on spawn error', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const promise = runFfmpeg(['x']);
    setImmediate(() => {
      child.emit('error', new Error('ENOENT: ffmpeg not found'));
    });

    await expect(promise).rejects.toThrow(/ENOENT: ffmpeg not found/);
  });
});
