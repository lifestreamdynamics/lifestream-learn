import { ValidationError } from '@/utils/errors';

// Matches SRT timing lines: HH:MM:SS,mmm --> HH:MM:SS,mmm (HH may be 1-2 digits or absent)
// The optional trailing portion captures SRT positioning attributes (dropped in output).
const SRT_TIMING_RE =
  /^(\d{1,2}:)?(\d{2}:\d{2},\d{3})\s+-->\s+(\d{1,2}:)?(\d{2}:\d{2},\d{3})(?:\s.*)?$/;

// Matches WebVTT timing lines per spec; optional trailing cue settings allowed.
const VTT_TIMING_RE =
  /^(?:\d{1,2}:)?\d{2}:\d{2}\.\d{3}\s+-->\s+(?:\d{1,2}:)?\d{2}:\d{2}\.\d{3}(?:\s.+)?$/;

const UTF8_BOM = '﻿';

/**
 * Normalise a possibly-abbreviated SRT timestamp to HH:MM:SS.mmm (WebVTT form).
 * Input examples:
 *   "12:34,567"   => "00:12:34.567"  (no-hour form)
 *   "01:12:34,567" => "01:12:34.567" (with hour)
 */
function normaliseSrtTimestamp(hourPart: string | undefined, rest: string): string {
  const dotRest = rest.replace(',', '.');
  if (hourPart !== undefined) {
    // Strip the trailing colon that the regex captured with the group
    const hour = hourPart.endsWith(':') ? hourPart.slice(0, -1) : hourPart;
    const paddedHour = hour.padStart(2, '0');
    return `${paddedHour}:${dotRest}`;
  }
  return `00:${dotRest}`;
}

/**
 * Convert an SRT subtitle buffer to a WebVTT buffer.
 * Pure synchronous; no I/O.
 */
export function parseSrtToVtt(buf: Buffer): Buffer {
  let text = buf.toString('utf8');

  // Strip UTF-8 BOM if present
  if (text.startsWith(UTF8_BOM)) {
    text = text.slice(1);
  }

  if (text.trim().length === 0) {
    throw new ValidationError('SRT file is empty');
  }

  // Normalise line endings
  text = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

  // Track cumulative line number for error messages (1-based)
  // Build a parallel array: for each block's first line, what is its line number?
  const lines = text.split('\n');
  const blocks: Array<{ firstLine: number; lines: string[] }> = [];

  let blockStart = 0;
  let currentBlock: string[] = [];

  for (let i = 0; i <= lines.length; i++) {
    const line = i < lines.length ? lines[i] : '';
    if (line.trim() === '' && i < lines.length) {
      // blank line — flush current block if non-empty
      if (currentBlock.length > 0) {
        blocks.push({ firstLine: blockStart + 1, lines: currentBlock });
        currentBlock = [];
      }
      blockStart = i + 1;
    } else if (i === lines.length) {
      // end of input — flush any remaining block
      if (currentBlock.length > 0) {
        blocks.push({ firstLine: blockStart + 1, lines: currentBlock });
      }
    } else {
      if (currentBlock.length === 0) {
        blockStart = i;
      }
      currentBlock.push(line);
    }
  }

  const output: string[] = ['WEBVTT', ''];

  for (const block of blocks) {
    const nonEmpty = block.lines.filter((l) => l.trim().length > 0);

    if (nonEmpty.length < 2) {
      throw new ValidationError(`Invalid SRT block at line ${block.firstLine}`);
    }

    // First non-empty line: cue index — skip it (must be a bare integer, but we
    // only validate "has at least 2 non-empty lines" to stay permissive for editors
    // that add metadata after the index).
    const timingLine = nonEmpty[1];
    const match = SRT_TIMING_RE.exec(timingLine);

    if (match === null) {
      // Find the actual line number of the timing line within the file
      const timingIdx = block.lines.indexOf(timingLine);
      const absoluteLine = block.firstLine + timingIdx;
      throw new ValidationError(`Invalid SRT block at line ${absoluteLine}`);
    }

    // Groups: [1]=startHour?, [2]=startRest, [3]=endHour?, [4]=endRest
    const startTs = normaliseSrtTimestamp(match[1], match[2]);
    const endTs = normaliseSrtTimestamp(match[3], match[4]);
    const timingOut = `${startTs} --> ${endTs}`;

    // Everything after the timing line (preserve empty lines within cue text)
    const cueTextLines = block.lines.slice(block.lines.indexOf(timingLine) + 1);

    output.push(timingOut);
    output.push(...cueTextLines);
    output.push(''); // blank line separator between cues
  }

  // Ensure the file ends with exactly one trailing newline
  while (output.length > 0 && output[output.length - 1] === '') {
    output.pop();
  }
  output.push('');

  return Buffer.from(output.join('\n'), 'utf8');
}

/**
 * Validate that `text` is syntactically valid WebVTT.
 * Throws ValidationError for any structural violation.
 * NOTE/STYLE blocks are accepted but do not satisfy the "at least one cue" requirement.
 */
export function validateVtt(text: string): void {
  const lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');

  if (lines.length === 0 || !lines[0].trimEnd().match(/^WEBVTT(\s.*)?$/)) {
    throw new ValidationError('WebVTT file must start with WEBVTT');
  }

  let cueCount = 0;
  let i = 1;

  while (i < lines.length) {
    // Skip blank lines between blocks
    if (lines[i].trim() === '') {
      i++;
      continue;
    }

    // Collect all lines of this block
    const blockStart = i;
    const blockLines: string[] = [];
    while (i < lines.length && lines[i].trim() !== '') {
      blockLines.push(lines[i]);
      i++;
    }

    if (blockLines.length === 0) continue;

    const firstLine = blockLines[0];

    // NOTE block — acceptable, skip
    if (firstLine.startsWith('NOTE')) {
      continue;
    }

    // STYLE block — acceptable, skip
    if (firstLine.startsWith('STYLE')) {
      continue;
    }

    // REGION block — acceptable, skip
    if (firstLine.startsWith('REGION')) {
      continue;
    }

    // A cue may optionally start with an identifier line (not matching timing pattern),
    // followed by a timing line, followed by cue text.
    let timingIdx = 0;
    if (!VTT_TIMING_RE.test(firstLine)) {
      // The first line is an identifier — timing must be next
      timingIdx = 1;
    }

    if (timingIdx >= blockLines.length || !VTT_TIMING_RE.test(blockLines[timingIdx])) {
      throw new ValidationError(
        `WebVTT: block at line ${blockStart + 1} is not a valid cue, NOTE, STYLE, or REGION block`,
      );
    }

    // There must be at least one non-empty text line after the timing line
    const hasText = blockLines.slice(timingIdx + 1).some((l) => l.trim().length > 0);
    if (!hasText) {
      throw new ValidationError(
        `WebVTT: cue at line ${blockStart + 1} has no text`,
      );
    }

    cueCount++;
  }

  if (cueCount === 0) {
    throw new ValidationError('WebVTT file contains no cues');
  }
}
