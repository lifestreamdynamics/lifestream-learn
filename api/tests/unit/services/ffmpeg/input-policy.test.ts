import '@tests/unit/setup';
import {
  assertInputAcceptable,
  VideoPolicyError,
  type InputPolicy,
} from '@/services/ffmpeg/input-policy';
import type { ProbeResult } from '@/queues/transcode.types';

function makeProbe(overrides: Partial<ProbeResult> = {}): ProbeResult {
  return {
    durationMs: 10_000,
    width: 1920,
    height: 1080,
    audioSampleRate: 48000,
    hasAudio: true,
    containerFormat: 'mov,mp4,m4a,3gp,3g2,mj2',
    videoCodec: 'h264',
    audioCodec: 'aac',
    rotationDegrees: 0,
    ...overrides,
  };
}

function makePolicy(overrides: Partial<InputPolicy> = {}): InputPolicy {
  return {
    maxBytes: 1024 * 1024 * 1024, // 1 GiB
    maxDurationMs: 180_000,
    allowedContainers: ['mov', 'mp4', 'matroska', 'webm', 'avi'],
    allowedVideoCodecs: ['h264', 'hevc', 'vp8', 'vp9', 'av1'],
    allowedAudioCodecs: ['aac', 'mp3', 'opus'],
    ...overrides,
  };
}

describe('assertInputAcceptable', () => {
  it('accepts a canonical H.264/AAC MP4 within caps', () => {
    expect(() =>
      assertInputAcceptable(makeProbe(), 50 * 1024 * 1024, makePolicy()),
    ).not.toThrow();
  });

  it('accepts a WebM/VP9 with Opus audio', () => {
    expect(() =>
      assertInputAcceptable(
        makeProbe({
          containerFormat: 'matroska,webm',
          videoCodec: 'vp9',
          audioCodec: 'opus',
        }),
        50 * 1024 * 1024,
        makePolicy(),
      ),
    ).not.toThrow();
  });

  it('accepts a silent video regardless of audio allow-list', () => {
    expect(() =>
      assertInputAcceptable(
        makeProbe({ hasAudio: false, audioCodec: null }),
        50 * 1024 * 1024,
        makePolicy({ allowedAudioCodecs: [] }),
      ),
    ).not.toThrow();
  });

  it('rejects when the raw upload byte size exceeds the cap', () => {
    try {
      assertInputAcceptable(makeProbe(), 2 * 1024 * 1024 * 1024, makePolicy());
      fail('expected to throw');
    } catch (err) {
      expect(err).toBeInstanceOf(VideoPolicyError);
      expect((err as VideoPolicyError).reason).toBe('INPUT_TOO_LARGE');
    }
  });

  it('rejects when duration exceeds the cap', () => {
    try {
      assertInputAcceptable(
        makeProbe({ durationMs: 300_000 }),
        50 * 1024 * 1024,
        makePolicy(),
      );
      fail('expected to throw');
    } catch (err) {
      expect((err as VideoPolicyError).reason).toBe('DURATION_EXCEEDED');
    }
  });

  it('rejects an unsupported container', () => {
    try {
      assertInputAcceptable(
        makeProbe({ containerFormat: 'flv' }),
        50 * 1024 * 1024,
        makePolicy(),
      );
      fail('expected to throw');
    } catch (err) {
      expect((err as VideoPolicyError).reason).toBe('UNSUPPORTED_CONTAINER');
    }
  });

  it('rejects an empty container (ffprobe gave us nothing)', () => {
    try {
      assertInputAcceptable(
        makeProbe({ containerFormat: '' }),
        50 * 1024 * 1024,
        makePolicy(),
      );
      fail('expected to throw');
    } catch (err) {
      expect((err as VideoPolicyError).reason).toBe('UNSUPPORTED_CONTAINER');
    }
  });

  it('rejects an unsupported video codec', () => {
    try {
      assertInputAcceptable(
        makeProbe({ videoCodec: 'prores' }),
        50 * 1024 * 1024,
        makePolicy(),
      );
      fail('expected to throw');
    } catch (err) {
      expect((err as VideoPolicyError).reason).toBe('UNSUPPORTED_VIDEO_CODEC');
    }
  });

  it('rejects an unsupported audio codec when hasAudio', () => {
    try {
      assertInputAcceptable(
        makeProbe({ audioCodec: 'truehd' }),
        50 * 1024 * 1024,
        makePolicy(),
      );
      fail('expected to throw');
    } catch (err) {
      expect((err as VideoPolicyError).reason).toBe('UNSUPPORTED_AUDIO_CODEC');
    }
  });

  it('prioritises the size check over codec checks when both would fail', () => {
    // A 5 GiB file with an unsupported codec should surface INPUT_TOO_LARGE
    // so the operator sees the costlier problem first.
    try {
      assertInputAcceptable(
        makeProbe({ videoCodec: 'prores' }),
        5 * 1024 * 1024 * 1024,
        makePolicy(),
      );
      fail('expected to throw');
    } catch (err) {
      expect((err as VideoPolicyError).reason).toBe('INPUT_TOO_LARGE');
    }
  });

  it('matches compound container strings by any token', () => {
    // An MP4 reports `mov,mp4,m4a,3gp,3g2,mj2`. A policy that only
    // allow-lists `mp4` should still accept it.
    expect(() =>
      assertInputAcceptable(
        makeProbe(),
        50 * 1024 * 1024,
        makePolicy({ allowedContainers: ['mp4'] }),
      ),
    ).not.toThrow();
  });
});
