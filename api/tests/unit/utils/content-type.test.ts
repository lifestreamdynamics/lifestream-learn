import '@tests/unit/setup';
import { contentTypeForPath } from '@/utils/content-type';

describe('contentTypeForPath', () => {
  const cases: Array<[string, string]> = [
    ['master.m3u8', 'application/vnd.apple.mpegurl'],
    ['index.M3U8', 'application/vnd.apple.mpegurl'],
    ['v_0/index.m3u8', 'application/vnd.apple.mpegurl'],
    ['seg_001.m4s', 'video/iso.segment'],
    ['init_0.mp4', 'video/mp4'],
    ['source.MP4', 'video/mp4'],
    ['legacy.ts', 'video/mp2t'],
    // WebVTT captions — charset=utf-8 must be included for multibyte content.
    ['captions/en.vtt', 'text/vtt; charset=utf-8'],
    ['captions/zh-CN.VTT', 'text/vtt; charset=utf-8'],
    ['unknown.bin', 'application/octet-stream'],
    ['noext', 'application/octet-stream'],
    ['', 'application/octet-stream'],
  ];

  it.each(cases)('maps %s -> %s', (filename, expected) => {
    expect(contentTypeForPath(filename)).toBe(expected);
  });
});
