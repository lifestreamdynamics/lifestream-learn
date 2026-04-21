import '@tests/unit/setup';
import { EventEmitter } from 'node:events';

// Mock node:child_process before importing the module under test so the
// module captures our mock at load time.
jest.mock('node:child_process', () => ({
  spawn: jest.fn(),
}));

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { spawn } = require('node:child_process') as { spawn: jest.Mock };
import { probeVideo } from '@/services/ffmpeg/probe';

interface FakeChild extends EventEmitter {
  stdout: EventEmitter;
  stderr: EventEmitter;
}

function makeChild(): FakeChild {
  const child = new EventEmitter() as FakeChild;
  child.stdout = new EventEmitter();
  child.stderr = new EventEmitter();
  return child;
}

describe('probeVideo', () => {
  beforeEach(() => {
    spawn.mockReset();
  });

  it('parses ffprobe JSON output into a ProbeResult', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const sample = JSON.stringify({
      format: { duration: '3.045000', format_name: 'mov,mp4,m4a,3gp,3g2,mj2' },
      streams: [
        { codec_type: 'video', codec_name: 'h264', width: 640, height: 360 },
        { codec_type: 'audio', codec_name: 'aac', sample_rate: '48000' },
      ],
    });

    const promise = probeVideo('/tmp/source.mp4');
    // Emit data then close on next tick to mimic real spawn lifecycle.
    setImmediate(() => {
      child.stdout.emit('data', Buffer.from(sample));
      child.emit('close', 0);
    });

    const probe = await promise;
    expect(probe).toEqual({
      durationMs: 3045,
      width: 640,
      height: 360,
      audioSampleRate: 48000,
      hasAudio: true,
      containerFormat: 'mov,mp4,m4a,3gp,3g2,mj2',
      videoCodec: 'h264',
      audioCodec: 'aac',
      rotationDegrees: 0,
    });

    // Verify spawn was called with the right argv shape.
    expect(spawn).toHaveBeenCalledTimes(1);
    const [, args] = spawn.mock.calls[0];
    expect(args).toEqual(expect.arrayContaining([
      '-v', 'error',
      '-print_format', 'json',
      '-show_streams',
      '-show_format',
      '/tmp/source.mp4',
    ]));
  });

  it('reports no audio stream as hasAudio=false', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const sample = JSON.stringify({
      format: { duration: '5.000000' },
      streams: [{ codec_type: 'video', width: 1920, height: 1080 }],
    });

    const promise = probeVideo('/tmp/silent.mp4');
    setImmediate(() => {
      child.stdout.emit('data', Buffer.from(sample));
      child.emit('close', 0);
    });

    const probe = await promise;
    expect(probe.hasAudio).toBe(false);
    expect(probe.audioSampleRate).toBeNull();
    expect(probe.audioCodec).toBeNull();
    expect(probe.durationMs).toBe(5000);
  });

  it('extracts rotation from side_data_list (modern ffprobe)', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const sample = JSON.stringify({
      format: { duration: '3.000000', format_name: 'mov,mp4,m4a,3gp,3g2,mj2' },
      streams: [
        {
          codec_type: 'video',
          codec_name: 'h264',
          width: 1080,
          height: 1920,
          side_data_list: [{ side_data_type: 'Display Matrix', rotation: -90 }],
        },
      ],
    });
    const promise = probeVideo('/tmp/portrait.mp4');
    setImmediate(() => {
      child.stdout.emit('data', Buffer.from(sample));
      child.emit('close', 0);
    });
    const probe = await promise;
    // -90 CCW → 270 CW after normalisation.
    expect(probe.rotationDegrees).toBe(270);
    expect(probe.width).toBe(1080);
    expect(probe.height).toBe(1920);
  });

  it('extracts rotation from legacy tags.rotate', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const sample = JSON.stringify({
      format: { duration: '3.000000', format_name: 'mov,mp4' },
      streams: [
        {
          codec_type: 'video',
          codec_name: 'h264',
          width: 1080,
          height: 1920,
          tags: { rotate: '90' },
        },
      ],
    });
    const promise = probeVideo('/tmp/portrait-legacy.mp4');
    setImmediate(() => {
      child.stdout.emit('data', Buffer.from(sample));
      child.emit('close', 0);
    });
    const probe = await promise;
    expect(probe.rotationDegrees).toBe(90);
  });

  it('returns rotationDegrees=0 when rotation is unspecified or non-right-angle', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const sample = JSON.stringify({
      format: { duration: '3.000000', format_name: 'matroska,webm' },
      streams: [
        {
          codec_type: 'video',
          codec_name: 'vp9',
          width: 1280,
          height: 720,
          side_data_list: [{ side_data_type: 'Display Matrix', rotation: 45 }],
        },
      ],
    });
    const promise = probeVideo('/tmp/weird.webm');
    setImmediate(() => {
      child.stdout.emit('data', Buffer.from(sample));
      child.emit('close', 0);
    });
    const probe = await promise;
    expect(probe.rotationDegrees).toBe(0);
    expect(probe.videoCodec).toBe('vp9');
    expect(probe.containerFormat).toBe('matroska,webm');
  });

  it('rejects when ffprobe exits non-zero with stderr tail', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const tail = 'a'.repeat(500);
    const promise = probeVideo('/tmp/missing.mp4');
    setImmediate(() => {
      child.stderr.emit('data', Buffer.from(tail));
      child.emit('close', 2);
    });

    await expect(promise).rejects.toThrow(/ffprobe failed/);
    await expect(probeVideoFresh(tail, 2)).rejects.toThrow(/a{200}$/);
  });

  it('rejects on spawn error', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const promise = probeVideo('/tmp/x.mp4');
    setImmediate(() => child.emit('error', new Error('ENOENT')));

    await expect(promise).rejects.toThrow(/ENOENT/);
  });

  it('rejects when ffprobe stdout is not valid JSON', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const promise = probeVideo('/tmp/x.mp4');
    setImmediate(() => {
      child.stdout.emit('data', Buffer.from('not json'));
      child.emit('close', 0);
    });

    await expect(promise).rejects.toThrow();
  });

  it('rejects when no video stream is present', async () => {
    const child = makeChild();
    spawn.mockReturnValue(child);

    const sample = JSON.stringify({
      format: { duration: '3.000000' },
      streams: [{ codec_type: 'audio', sample_rate: '44100' }],
    });
    const promise = probeVideo('/tmp/x.mp4');
    setImmediate(() => {
      child.stdout.emit('data', Buffer.from(sample));
      child.emit('close', 0);
    });

    await expect(promise).rejects.toThrow(/no video stream/);
  });
});

// Helper that runs a fresh probe with the given stderr/exit code so the
// "tail of stderr" assertion can inspect the rejection message.
async function probeVideoFresh(stderr: string, code: number): Promise<unknown> {
  const child = makeChild();
  spawn.mockReturnValueOnce(child);
  const p = probeVideo('/tmp/x.mp4');
  setImmediate(() => {
    child.stderr.emit('data', Buffer.from(stderr));
    child.emit('close', code);
  });
  return p;
}
