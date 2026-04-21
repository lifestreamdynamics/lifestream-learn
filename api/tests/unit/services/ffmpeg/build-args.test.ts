import '@tests/unit/setup';
import path from 'node:path';
import { buildFfmpegArgs } from '@/services/ffmpeg/build-args';
import { DEFAULT_LADDER } from '@/services/ffmpeg/ladder';
import type { LadderRung } from '@/queues/transcode.types';

const INPUT = '/tmp/in/source';
const OUT = '/tmp/out';

function joined(args: string[]): string {
  return args.join(' ');
}

function pairValueAfter(args: string[], flag: string): string | undefined {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : undefined;
}

describe('buildFfmpegArgs', () => {
  it('throws on empty ladder', () => {
    expect(() => buildFfmpegArgs([], INPUT, OUT)).toThrow(/must not be empty/);
  });

  describe('1-rung ladder (360p only)', () => {
    const ladder: LadderRung[] = [DEFAULT_LADDER[0]];
    const args = buildFfmpegArgs(ladder, INPUT, OUT);
    const text = joined(args);

    it('passes input path with -i', () => {
      expect(pairValueAfter(args, '-i')).toBe(INPUT);
    });

    it('selects HLS output format', () => {
      expect(args).toContain('-f');
      expect(text).toContain('-f hls');
    });

    it('uses 4-second segments', () => {
      expect(text).toContain('-hls_time 4');
    });

    it('includes a single var_stream_map entry', () => {
      const v = pairValueAfter(args, '-var_stream_map');
      expect(v).toBe('v:0,a:0');
    });

    it('sets the 360p video bitrate', () => {
      expect(text).toContain('-b:v:0 800k');
      expect(text).toContain('-maxrate:v:0 856k'); // 800 * 1.07 = 856
      expect(text).toContain('-bufsize:v:0 1600k'); // 800 * 2 = 1600
    });

    it('declares scale filter for the rung', () => {
      const fc = pairValueAfter(args, '-filter_complex');
      expect(fc).toContain('split=1');
      expect(fc).toContain('[v0]scale=w=640:h=360[v0out]');
    });

    it('writes outputs under the requested directory', () => {
      expect(args).toContain(path.join(OUT, 'v_%v/index.m3u8'));
      const segFlag = pairValueAfter(args, '-hls_segment_filename');
      expect(segFlag).toBe(path.join(OUT, 'v_%v/seg_%03d.m4s'));
    });
  });

  describe('2-rung ladder (360p + 540p)', () => {
    const ladder: LadderRung[] = DEFAULT_LADDER.slice(0, 2);
    const args = buildFfmpegArgs(ladder, INPUT, OUT);
    const text = joined(args);

    it('var_stream_map has 2 entries', () => {
      const v = pairValueAfter(args, '-var_stream_map');
      expect(v).toBe('v:0,a:0 v:1,a:1');
    });

    it('emits per-rung bitrate flags', () => {
      expect(text).toContain('-b:v:0 800k');
      expect(text).toContain('-b:v:1 1400k');
      expect(text).toContain('-maxrate:v:1 1498k'); // round(1400 * 1.07)
      expect(text).toContain('-bufsize:v:1 2800k');
    });

    it('emits split=2 with two scale clauses', () => {
      const fc = pairValueAfter(args, '-filter_complex');
      expect(fc).toContain('split=2');
      expect(fc).toContain('[v0]scale=w=640:h=360[v0out]');
      expect(fc).toContain('[v1]scale=w=960:h=540[v1out]');
    });
  });

  describe('4-rung ladder (full default)', () => {
    const ladder = DEFAULT_LADDER;
    const args = buildFfmpegArgs(ladder, INPUT, OUT);
    const text = joined(args);

    it('var_stream_map length matches ladder length', () => {
      const v = pairValueAfter(args, '-var_stream_map') ?? '';
      expect(v.split(' ')).toHaveLength(ladder.length);
      expect(v).toBe('v:0,a:0 v:1,a:1 v:2,a:2 v:3,a:3');
    });

    it('emits all per-rung video bitrates', () => {
      expect(text).toContain('-b:v:0 800k');
      expect(text).toContain('-b:v:1 1400k');
      expect(text).toContain('-b:v:2 2800k');
      expect(text).toContain('-b:v:3 5000k');
    });

    it('emits all per-rung audio bitrates', () => {
      for (let i = 0; i < ladder.length; i += 1) {
        expect(text).toContain(`-b:a:${i} 96k`);
      }
    });

    it('declares fmp4 packaging and master playlist name', () => {
      expect(text).toContain('-hls_segment_type fmp4');
      expect(text).toContain('-master_pl_name master.m3u8');
      expect(text).toContain('-hls_fmp4_init_filename init_%v.mp4');
    });

    it('sets a single global -ar and -ac', () => {
      expect(args.filter((a) => a === '-ar')).toHaveLength(1);
      expect(args.filter((a) => a === '-ac')).toHaveLength(1);
      expect(pairValueAfter(args, '-ar')).toBe('48000');
      expect(pairValueAfter(args, '-ac')).toBe('2');
    });

    it('emits split=4 with four scale clauses', () => {
      const fc = pairValueAfter(args, '-filter_complex');
      expect(fc).toContain('split=4');
      expect(fc).toContain('[v0]scale=w=640:h=360[v0out]');
      expect(fc).toContain('[v1]scale=w=960:h=540[v1out]');
      expect(fc).toContain('[v2]scale=w=1280:h=720[v2out]');
      expect(fc).toContain('[v3]scale=w=1920:h=1080[v3out]');
    });

    it('forces yuv420p pixel format per rung for universal decoder compat', () => {
      for (let i = 0; i < ladder.length; i += 1) {
        expect(text).toContain(`-pix_fmt:v:${i} yuv420p`);
      }
    });

    it('emits BT.709 colour metadata per rung so HDR lands as well-behaved SDR', () => {
      for (let i = 0; i < ladder.length; i += 1) {
        expect(text).toContain(`-colorspace:v:${i} bt709`);
        expect(text).toContain(`-color_primaries:v:${i} bt709`);
        expect(text).toContain(`-color_trc:v:${i} bt709`);
        expect(text).toContain(`-color_range:v:${i} tv`);
      }
    });

    it('clears the rotation tag on every output stream', () => {
      for (let i = 0; i < ladder.length; i += 1) {
        expect(text).toContain(`-metadata:s:v:${i} rotate=0`);
      }
    });

    it('applies EBU R128 loudness normalisation once at the global audio stage', () => {
      expect(args.filter((a) => a === '-af')).toHaveLength(1);
      expect(pairValueAfter(args, '-af')).toBe('loudnorm=I=-16:LRA=11:TP=-1.5');
    });
  });

  describe('rotation', () => {
    it('prepends transpose=1 into each scale branch for 90° clockwise', () => {
      const args = buildFfmpegArgs(
        DEFAULT_LADDER.slice(0, 2),
        INPUT,
        OUT,
        { rotationDegrees: 90 },
      );
      const fc = pairValueAfter(args, '-filter_complex') ?? '';
      expect(fc).toContain('[v0]transpose=1,scale=w=640:h=360[v0out]');
      expect(fc).toContain('[v1]transpose=1,scale=w=960:h=540[v1out]');
    });

    it('uses transpose=2 for 270° (-90°) rotation', () => {
      const args = buildFfmpegArgs(
        [DEFAULT_LADDER[0]],
        INPUT,
        OUT,
        { rotationDegrees: 270 },
      );
      const fc = pairValueAfter(args, '-filter_complex') ?? '';
      expect(fc).toContain('[v0]transpose=2,scale=w=640:h=360[v0out]');
    });

    it('uses hflip,vflip for 180° rotation', () => {
      const args = buildFfmpegArgs(
        [DEFAULT_LADDER[0]],
        INPUT,
        OUT,
        { rotationDegrees: 180 },
      );
      const fc = pairValueAfter(args, '-filter_complex') ?? '';
      expect(fc).toContain('[v0]hflip,vflip,scale=w=640:h=360[v0out]');
    });

    it('does not alter the scale chain when rotation is 0', () => {
      const args = buildFfmpegArgs(
        [DEFAULT_LADDER[0]],
        INPUT,
        OUT,
        { rotationDegrees: 0 },
      );
      const fc = pairValueAfter(args, '-filter_complex') ?? '';
      expect(fc).toContain('[v0]scale=w=640:h=360[v0out]');
      expect(fc).not.toContain('transpose');
      expect(fc).not.toContain('hflip');
    });
  });

  describe('silent source (hasAudio=false)', () => {
    const args = buildFfmpegArgs(
      DEFAULT_LADDER.slice(0, 2),
      INPUT,
      OUT,
      { hasAudio: false },
    );
    const text = joined(args);

    it('omits -map 0:a audio maps', () => {
      // Only the two video maps should appear.
      expect(args.filter((a) => a === '-map')).toHaveLength(2);
      for (const mapValue of ['0:a:0?', '0:a:1?', '0:a:2?']) {
        expect(args).not.toContain(mapValue);
      }
    });

    it('omits -c:a and -b:a codec flags', () => {
      expect(text).not.toMatch(/-c:a/);
      expect(text).not.toMatch(/-b:a/);
    });

    it('omits the global -ar / -ac / -af flags', () => {
      expect(args).not.toContain('-ar');
      expect(args).not.toContain('-ac');
      expect(args).not.toContain('-af');
    });

    it('emits a video-only var_stream_map', () => {
      const v = pairValueAfter(args, '-var_stream_map');
      expect(v).toBe('v:0 v:1');
    });

    it('still sets per-rung video codec flags', () => {
      expect(text).toContain('-b:v:0 800k');
      expect(text).toContain('-pix_fmt:v:1 yuv420p');
    });
  });
});
