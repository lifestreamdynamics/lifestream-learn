/**
 * Map a filename to a Content-Type for HLS / fMP4 outputs.
 * Returns `application/octet-stream` for unknown extensions.
 */
export function contentTypeForPath(filename: string): string {
  const lower = filename.toLowerCase();
  if (lower.endsWith('.m3u8')) return 'application/vnd.apple.mpegurl';
  if (lower.endsWith('.m4s')) return 'video/iso.segment';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.ts')) return 'video/mp2t';
  return 'application/octet-stream';
}
