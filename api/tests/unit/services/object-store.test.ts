import '@tests/unit/setup';
import { Readable } from 'node:stream';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  type S3Client,
} from '@aws-sdk/client-s3';

// Mock fs/promises so we can stub readdir/mkdir without touching the real
// filesystem. Both the named export and the default export must reference
// the SAME jest.fn instance — esModuleInterop maps `import fs from
// 'node:fs/promises'` to whichever shape commonjs produces, and tests need
// to assert against the calls regardless of import style.
jest.mock('node:fs/promises', () => {
  const actual = jest.requireActual('node:fs/promises');
  const readdir = jest.fn(actual.readdir);
  const mkdir = jest.fn(actual.mkdir);
  const mocked = { ...actual, readdir, mkdir };
  return {
    __esModule: true,
    ...mocked,
    default: mocked,
  };
});

// Mock fs (createReadStream / createWriteStream) so uploadFile / downloadToFile
// don't need real files on disk.
jest.mock('node:fs', () => {
  const actual = jest.requireActual('node:fs');
  return {
    __esModule: true,
    ...actual,
    createReadStream: jest.fn((p: string) => Readable.from([Buffer.from(`stream:${p}`)])),
    createWriteStream: jest.fn(() => {
      // A write stream that just sinks data and emits finish.
      const sink = new (jest.requireActual('node:stream').Writable)({
        write(_chunk: unknown, _enc: unknown, cb: () => void) { cb(); },
      });
      return sink;
    }),
  };
});

// eslint-disable-next-line @typescript-eslint/no-require-imports
const fsPromises = require('node:fs/promises') as { readdir: jest.Mock; mkdir: jest.Mock };

import { createObjectStore } from '@/services/object-store';

function fakeS3(): { client: S3Client; sendMock: jest.Mock } {
  const sendMock = jest.fn();
  const client = { send: sendMock } as unknown as S3Client;
  return { client, sendMock };
}

describe('createObjectStore', () => {
  beforeEach(() => {
    fsPromises.readdir.mockReset();
    fsPromises.mkdir.mockReset();
    fsPromises.mkdir.mockResolvedValue(undefined);
  });

  describe('downloadToFile', () => {
    it('issues GetObjectCommand and pipes Body to disk', async () => {
      const { client, sendMock } = fakeS3();
      const body = Readable.from([Buffer.from('hello')]);
      sendMock.mockResolvedValueOnce({ Body: body });
      const store = createObjectStore(client);

      await store.downloadToFile('learn-uploads', 'src/abc', '/tmp/x/source');

      expect(sendMock).toHaveBeenCalledTimes(1);
      const cmd = sendMock.mock.calls[0][0] as GetObjectCommand;
      expect(cmd).toBeInstanceOf(GetObjectCommand);
      expect(cmd.input).toEqual({ Bucket: 'learn-uploads', Key: 'src/abc' });
      // Parent dir was ensured.
      expect(fsPromises.mkdir).toHaveBeenCalledWith('/tmp/x', { recursive: true });
    });

    it('throws when GetObject returns no body', async () => {
      const { client, sendMock } = fakeS3();
      sendMock.mockResolvedValueOnce({});
      const store = createObjectStore(client);
      await expect(store.downloadToFile('b', 'k', '/tmp/x/y')).rejects.toThrow(/no body/);
    });
  });

  describe('uploadFile', () => {
    it('issues PutObjectCommand with provided content type', async () => {
      const { client, sendMock } = fakeS3();
      sendMock.mockResolvedValueOnce({});
      const store = createObjectStore(client);

      await store.uploadFile('learn-vod', 'vod/v1/master.m3u8', '/tmp/master.m3u8', 'application/vnd.apple.mpegurl');

      const cmd = sendMock.mock.calls[0][0] as PutObjectCommand;
      expect(cmd).toBeInstanceOf(PutObjectCommand);
      expect(cmd.input.Bucket).toBe('learn-vod');
      expect(cmd.input.Key).toBe('vod/v1/master.m3u8');
      expect(cmd.input.ContentType).toBe('application/vnd.apple.mpegurl');
    });
  });

  describe('deleteObject', () => {
    it('issues DeleteObjectCommand', async () => {
      const { client, sendMock } = fakeS3();
      sendMock.mockResolvedValueOnce({});
      const store = createObjectStore(client);

      await store.deleteObject('learn-uploads', 'src/abc');

      const cmd = sendMock.mock.calls[0][0] as DeleteObjectCommand;
      expect(cmd).toBeInstanceOf(DeleteObjectCommand);
      expect(cmd.input).toEqual({ Bucket: 'learn-uploads', Key: 'src/abc' });
    });
  });

  describe('uploadDirectory', () => {
    type FakeEntry = {
      name: string;
      parentPath: string;
      isFile: () => boolean;
    };

    function entry(name: string, parentPath: string, file = true): FakeEntry {
      return { name, parentPath, isFile: () => file };
    }

    it('uploads master.m3u8 last and maps content types per extension', async () => {
      const root = '/tmp/out';
      // A small ladder-shaped tree with two variants.
      fsPromises.readdir.mockResolvedValueOnce([
        entry('master.m3u8', root),
        entry('init_0.mp4', `${root}/v_0`),
        entry('seg_001.m4s', `${root}/v_0`),
        entry('index.m3u8', `${root}/v_0`),
        entry('init_1.mp4', `${root}/v_1`),
        entry('seg_001.m4s', `${root}/v_1`),
        entry('index.m3u8', `${root}/v_1`),
      ]);

      const { client, sendMock } = fakeS3();
      sendMock.mockResolvedValue({});
      const store = createObjectStore(client);

      const res = await store.uploadDirectory('learn-vod', 'vod/abc', root, { concurrency: 2 });

      expect(res).toEqual({ uploaded: 7 });
      expect(sendMock).toHaveBeenCalledTimes(7);

      // Inspect the last call — must be master.m3u8.
      const lastCmd = sendMock.mock.calls.at(-1)?.[0] as PutObjectCommand;
      expect(lastCmd).toBeInstanceOf(PutObjectCommand);
      expect(lastCmd.input.Key).toBe('vod/abc/master.m3u8');
      expect(lastCmd.input.ContentType).toBe('application/vnd.apple.mpegurl');

      // Master must NOT appear before the last call.
      for (let i = 0; i < sendMock.mock.calls.length - 1; i += 1) {
        const cmd = sendMock.mock.calls[i][0] as PutObjectCommand;
        expect(cmd.input.Key).not.toBe('vod/abc/master.m3u8');
      }

      // Spot-check content types for the other extensions.
      const allKeys = sendMock.mock.calls.map((c) => (c[0] as PutObjectCommand).input.Key);
      expect(allKeys).toEqual(expect.arrayContaining([
        'vod/abc/v_0/init_0.mp4',
        'vod/abc/v_0/seg_001.m4s',
        'vod/abc/v_0/index.m3u8',
        'vod/abc/v_1/init_1.mp4',
      ]));
      const m4sCmd = sendMock.mock.calls.find(
        (c) => (c[0] as PutObjectCommand).input.Key === 'vod/abc/v_0/seg_001.m4s',
      )?.[0] as PutObjectCommand;
      expect(m4sCmd.input.ContentType).toBe('video/iso.segment');
      const mp4Cmd = sendMock.mock.calls.find(
        (c) => (c[0] as PutObjectCommand).input.Key === 'vod/abc/v_0/init_0.mp4',
      )?.[0] as PutObjectCommand;
      expect(mp4Cmd.input.ContentType).toBe('video/mp4');
    });

    it('respects concurrency: never more than N puts in flight at once', async () => {
      const root = '/tmp/out';
      // 6 non-master files; concurrency=2.
      fsPromises.readdir.mockResolvedValueOnce([
        entry('a.m4s', root),
        entry('b.m4s', root),
        entry('c.m4s', root),
        entry('d.m4s', root),
        entry('e.m4s', root),
        entry('f.m4s', root),
      ]);

      const { client, sendMock } = fakeS3();
      let inflight = 0;
      let peak = 0;
      sendMock.mockImplementation(() => {
        inflight += 1;
        peak = Math.max(peak, inflight);
        return new Promise((resolve) => {
          setImmediate(() => {
            inflight -= 1;
            resolve({});
          });
        });
      });

      const store = createObjectStore(client);
      const res = await store.uploadDirectory('learn-vod', 'vod/abc', root, { concurrency: 2 });

      expect(res).toEqual({ uploaded: 6 });
      expect(peak).toBeLessThanOrEqual(2);
      expect(peak).toBeGreaterThan(0);
    });

    it('handles a directory with no master.m3u8', async () => {
      const root = '/tmp/out';
      fsPromises.readdir.mockResolvedValueOnce([
        entry('init_0.mp4', `${root}/v_0`),
        entry('seg_001.m4s', `${root}/v_0`),
      ]);

      const { client, sendMock } = fakeS3();
      sendMock.mockResolvedValue({});
      const store = createObjectStore(client);

      const res = await store.uploadDirectory('learn-vod', 'vod/x', root);
      expect(res).toEqual({ uploaded: 2 });
      expect(sendMock).toHaveBeenCalledTimes(2);
    });

    it('skips non-file dirents (directories)', async () => {
      const root = '/tmp/out';
      fsPromises.readdir.mockResolvedValueOnce([
        entry('v_0', root, false), // a directory entry
        entry('seg_001.m4s', `${root}/v_0`),
      ]);

      const { client, sendMock } = fakeS3();
      sendMock.mockResolvedValue({});
      const store = createObjectStore(client);

      const res = await store.uploadDirectory('learn-vod', 'vod/x', root);
      expect(res).toEqual({ uploaded: 1 });
    });
  });
});
