import path from 'node:path';

/**
 * Build the argv for a one-shot "extract a JPEG poster" ffmpeg run.
 *
 * The intent is to emit a single 640-wide JPEG at or near the 1-second
 * mark of the source. 1s avoids the black intro frames typical of phone
 * captures while staying safely within any realistic duration. We
 * request `-update 1` so ffmpeg knows the output is a single still image
 * (silences its "you asked for 1 frame but we opened a muxer" warning).
 *
 * Rotation is NOT applied here: the main transcode already rotated the
 * pixels, and the source-facing poster extractor just re-reads the raw
 * file's first second (the main transcode output is HLS, not a still).
 * If a portrait source produces a sideways thumbnail that's still
 * correctable by the Flutter side via ImageRotation — but the vast
 * majority of content is landscape and the poster preview is small
 * enough that a one-off rotation regression is low-impact. Keeping this
 * builder pure and rotation-blind keeps the surface minimal.
 *
 * Output is a JPEG because a still-image CDN path is cheaper to serve
 * than a WebP one and already has `image/jpeg` MIME coverage in nginx
 * and SeaweedFS. Quality 3 hits a good size/quality point for a feed
 * thumbnail (Q=2 is the floor per ffmpeg docs; Q=3 is ~70kB at 640w).
 */
export function buildPosterArgs(inputPath: string, outputPath: string): string[] {
  return [
    '-y',
    '-ss', '1',
    '-i', inputPath,
    '-vframes', '1',
    '-vf', 'scale=640:-2',
    '-q:v', '3',
    '-update', '1',
    '-f', 'image2',
    outputPath,
  ];
}

/** Canonical poster file name inside the VOD bucket's per-video prefix. */
export const POSTER_FILENAME = 'poster.jpg';

/** Full bucket key a pipeline writes the poster to. */
export function posterKey(videoId: string): string {
  return path.posix.join('vod', videoId, POSTER_FILENAME);
}
