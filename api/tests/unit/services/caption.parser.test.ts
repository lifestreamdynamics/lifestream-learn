import { parseSrtToVtt, validateVtt } from '@/services/caption.parser';
import { ValidationError } from '@/utils/errors';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/** Three-cue SRT with Unicode text (CJK + Arabic + accented chars + em-dash). */
const SAMPLE_SRT = [
  '1',
  '00:00:01,000 --> 00:00:03,500',
  'Hello — café',
  '',
  '2',
  '00:00:05,000 --> 00:00:08,000',
  '中文字幕',
  '',
  '3',
  '00:00:10,250 --> 00:00:13,750',
  'العربية',
  '',
].join('\n');

/** Same SRT with CRLF line endings. */
const SAMPLE_SRT_CRLF = SAMPLE_SRT.replace(/\n/g, '\r\n');

/** UTF-8 BOM prefix. */
const BOM = Buffer.from([0xef, 0xbb, 0xbf]);

function srtBuf(s: string): Buffer {
  return Buffer.from(s, 'utf8');
}

function bomBuf(s: string): Buffer {
  return Buffer.concat([BOM, Buffer.from(s, 'utf8')]);
}

// ---------------------------------------------------------------------------
// parseSrtToVtt — happy paths
// ---------------------------------------------------------------------------

describe('parseSrtToVtt', () => {
  describe('happy path — 3-cue Unicode SRT', () => {
    let result: string;

    beforeEach(() => {
      result = parseSrtToVtt(srtBuf(SAMPLE_SRT)).toString('utf8');
    });

    it('starts with WEBVTT header', () => {
      expect(result.startsWith('WEBVTT\n\n')).toBe(true);
    });

    it('converts comma decimal separator to dot in all timing lines', () => {
      const timingLines = result
        .split('\n')
        .filter((l) => l.includes('-->'));
      expect(timingLines).toHaveLength(3);
      for (const line of timingLines) {
        expect(line).not.toContain(',');
        // Timestamps must use dot notation
        expect(line).toMatch(/\d{2}:\d{2}:\d{2}\.\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}\.\d{3}/);
      }
    });

    it('first cue timing is correct', () => {
      expect(result).toContain('00:00:01.000 --> 00:00:03.500');
    });

    it('preserves em-dash cue text verbatim', () => {
      expect(result).toContain('Hello — café');
    });

    it('preserves CJK text verbatim', () => {
      expect(result).toContain('中文字幕');
    });

    it('preserves Arabic text verbatim', () => {
      expect(result).toContain('العربية');
    });

    it('returns a Buffer', () => {
      expect(parseSrtToVtt(srtBuf(SAMPLE_SRT))).toBeInstanceOf(Buffer);
    });
  });

  describe('CRLF normalisation', () => {
    it('produces LF-only output from CRLF input', () => {
      const out = parseSrtToVtt(srtBuf(SAMPLE_SRT_CRLF)).toString('utf8');
      expect(out).not.toContain('\r');
    });

    it('round-trips correctly to the same content as LF input', () => {
      const lfOut = parseSrtToVtt(srtBuf(SAMPLE_SRT)).toString('utf8');
      const crlfOut = parseSrtToVtt(srtBuf(SAMPLE_SRT_CRLF)).toString('utf8');
      expect(crlfOut).toBe(lfOut);
    });
  });

  describe('UTF-8 BOM stripping', () => {
    it('handles BOM-prefixed input transparently', () => {
      const noBomOut = parseSrtToVtt(srtBuf(SAMPLE_SRT)).toString('utf8');
      const bomOut = parseSrtToVtt(bomBuf(SAMPLE_SRT)).toString('utf8');
      expect(bomOut).toBe(noBomOut);
    });
  });

  describe('missing-hour timestamp form', () => {
    const noHourSrt = [
      '1',
      '00:00,500 --> 00:02,800',
      'No hour in timestamps',
      '',
    ].join('\n');

    it('expands MM:SS,mmm to 00:MM:SS.mmm', () => {
      const out = parseSrtToVtt(srtBuf(noHourSrt)).toString('utf8');
      expect(out).toContain('00:00:00.500 --> 00:00:02.800');
    });
  });

  describe('cue text with an internal blank line', () => {
    // SRT doesn't officially support blank lines in cue text, but some tools
    // emit them; we preserve what's there between the timing line and the next
    // blank-line separator.
    const multiLineCueSrt = [
      '1',
      '00:00:01,000 --> 00:00:04,000',
      'Line one',
      'Line two',
      '',
    ].join('\n');

    it('preserves all cue text lines', () => {
      const out = parseSrtToVtt(srtBuf(multiLineCueSrt)).toString('utf8');
      expect(out).toContain('Line one\nLine two');
    });
  });

  // ---------------------------------------------------------------------------
  // Error cases
  // ---------------------------------------------------------------------------

  describe('rejects invalid input', () => {
    it('throws ValidationError for empty buffer', () => {
      expect(() => parseSrtToVtt(Buffer.from(''))).toThrow(ValidationError);
      expect(() => parseSrtToVtt(Buffer.from(''))).toThrow(/empty/i);
    });

    it('throws ValidationError for whitespace-only buffer', () => {
      expect(() => parseSrtToVtt(srtBuf('   \n\n  '))).toThrow(ValidationError);
    });

    it('throws ValidationError for a block with no timing line', () => {
      const bad = ['1', 'Just text, no timing', ''].join('\n');
      expect(() => parseSrtToVtt(srtBuf(bad))).toThrow(ValidationError);
    });

    it('throws ValidationError for timing line using dot instead of comma', () => {
      // WebVTT uses dots; SRT must use commas — a dot is malformed SRT input
      const bad = ['1', '00:00:01.000 --> 00:00:03.000', 'Text', ''].join('\n');
      expect(() => parseSrtToVtt(srtBuf(bad))).toThrow(ValidationError);
    });

    it('throws ValidationError with line reference for a deep bad block (line 5)', () => {
      // Block 1 is fine (lines 1-3), blank line is line 4, block 2 starts at line 5.
      const srt = [
        '1',
        '00:00:01,000 --> 00:00:02,000',
        'Good cue',
        '',
        '2',
        'No timing here',
        '',
      ].join('\n');
      // Block 2 starts at line 5 (1-based); timing line is line 6
      expect(() => parseSrtToVtt(srtBuf(srt))).toThrow(ValidationError);
      expect(() => parseSrtToVtt(srtBuf(srt))).toThrow(/line 6/);
    });

    it('throws ValidationError for a block with only the index and nothing else', () => {
      const bad = ['1', ''].join('\n');
      expect(() => parseSrtToVtt(srtBuf(bad))).toThrow(ValidationError);
    });
  });
});

// ---------------------------------------------------------------------------
// validateVtt
// ---------------------------------------------------------------------------

describe('validateVtt', () => {
  const MINIMAL_VTT = 'WEBVTT\n\n00:00:01.000 --> 00:00:03.000\nHello world\n';

  describe('happy path', () => {
    it('accepts minimal valid VTT', () => {
      expect(() => validateVtt(MINIMAL_VTT)).not.toThrow();
    });

    it('accepts VTT with descriptor text after WEBVTT', () => {
      const vtt = 'WEBVTT - My captions\n\n00:00:01.000 --> 00:00:03.000\nText\n';
      expect(() => validateVtt(vtt)).not.toThrow();
    });

    it('accepts cues with optional cue identifier', () => {
      const vtt = 'WEBVTT\n\ncue-1\n00:00:01.000 --> 00:00:03.000\nText\n';
      expect(() => validateVtt(vtt)).not.toThrow();
    });

    it('accepts cue with trailing settings on timing line', () => {
      const vtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:03.000 line:80%\nText\n';
      expect(() => validateVtt(vtt)).not.toThrow();
    });

    it('accepts VTT with hours in timestamps', () => {
      const vtt = 'WEBVTT\n\n01:00:00.000 --> 01:00:05.000\nHour cue\n';
      expect(() => validateVtt(vtt)).not.toThrow();
    });
  });

  describe('tolerates NOTE and STYLE blocks', () => {
    it('accepts a NOTE block before the first cue', () => {
      const vtt = [
        'WEBVTT',
        '',
        'NOTE This is a comment',
        '',
        '00:00:01.000 --> 00:00:03.000',
        'Text',
        '',
      ].join('\n');
      expect(() => validateVtt(vtt)).not.toThrow();
    });

    it('accepts a STYLE block', () => {
      const vtt = [
        'WEBVTT',
        '',
        'STYLE',
        '::cue { color: white; }',
        '',
        '00:00:01.000 --> 00:00:03.000',
        'Text',
        '',
      ].join('\n');
      expect(() => validateVtt(vtt)).not.toThrow();
    });

    it('does not count NOTE/STYLE blocks as cues', () => {
      const vttNoRealCues = [
        'WEBVTT',
        '',
        'NOTE Only a comment, no actual cue',
        '',
      ].join('\n');
      expect(() => validateVtt(vttNoRealCues)).toThrow(ValidationError);
      expect(() => validateVtt(vttNoRealCues)).toThrow(/no cues/i);
    });
  });

  describe('rejects invalid VTT', () => {
    it('throws when WEBVTT header is missing', () => {
      const vtt = '00:00:01.000 --> 00:00:03.000\nText\n';
      expect(() => validateVtt(vtt)).toThrow(ValidationError);
      expect(() => validateVtt(vtt)).toThrow(/WEBVTT/);
    });

    it('throws when there are no cues at all', () => {
      expect(() => validateVtt('WEBVTT\n\n')).toThrow(ValidationError);
      expect(() => validateVtt('WEBVTT\n\n')).toThrow(/no cues/i);
    });

    it('throws when a cue has no text lines', () => {
      const vtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:03.000\n';
      expect(() => validateVtt(vtt)).toThrow(ValidationError);
    });

    it('throws for a malformed timing line (SRT comma form instead of dot)', () => {
      const vtt = 'WEBVTT\n\n00:00:01,000 --> 00:00:03,000\nText\n';
      expect(() => validateVtt(vtt)).toThrow(ValidationError);
    });

    it('throws for a block that is not a cue, NOTE, STYLE, or REGION', () => {
      const vtt = [
        'WEBVTT',
        '',
        '00:00:01.000 --> 00:00:03.000',
        'Good cue',
        '',
        'BOGUS_BLOCK',
        'random content',
        '',
      ].join('\n');
      expect(() => validateVtt(vtt)).toThrow(ValidationError);
    });
  });
});
