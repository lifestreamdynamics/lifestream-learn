import fs from 'node:fs/promises';
import type { ObjectStore } from '@/services/object-store';
import { uploadBytes } from '@/utils/object-store-utils';

describe('uploadBytes', () => {
  it('uses putObject fast-path when the store exposes it', async () => {
    const putObject = jest.fn().mockResolvedValue(undefined);
    const uploadFile = jest.fn().mockResolvedValue(undefined);
    const store = {
      downloadToFile: jest.fn(),
      uploadFile,
      uploadDirectory: jest.fn(),
      deleteObject: jest.fn(),
      getObjectStream: jest.fn(),
      putObject,
    } as unknown as ObjectStore;

    const bytes = Buffer.from('hello world', 'utf8');
    await uploadBytes(store, 'learn-uploads', 'k/1.txt', bytes, 'text/plain');

    expect(putObject).toHaveBeenCalledWith('learn-uploads', 'k/1.txt', bytes, 'text/plain');
    expect(uploadFile).not.toHaveBeenCalled();
  });

  it('falls back to tempfile + uploadFile when putObject is absent', async () => {
    // Capture the temp path the fallback wrote to so we can assert the
    // bytes landed correctly before uploadFile was invoked.
    const observed: { tmpPath: string | null; tmpBytes: Buffer | null } = {
      tmpPath: null,
      tmpBytes: null,
    };
    const uploadFile = jest
      .fn()
      .mockImplementation(async (_bucket: string, _key: string, tmpPath: string) => {
        observed.tmpPath = tmpPath;
        observed.tmpBytes = await fs.readFile(tmpPath);
      });
    const store = {
      downloadToFile: jest.fn(),
      uploadFile,
      uploadDirectory: jest.fn(),
      deleteObject: jest.fn(),
      getObjectStream: jest.fn(),
    } as unknown as ObjectStore;

    const bytes = Buffer.from('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n', 'utf8');
    await uploadBytes(store, 'learn-vod', 'vod/v1/captions/en.vtt', bytes, 'text/vtt; charset=utf-8');

    expect(uploadFile).toHaveBeenCalledWith(
      'learn-vod',
      'vod/v1/captions/en.vtt',
      expect.any(String),
      'text/vtt; charset=utf-8',
    );
    expect(observed.tmpBytes?.equals(bytes)).toBe(true);

    // Temp dir is cleaned up after the call returns — the spooled path
    // must no longer exist.
    if (observed.tmpPath) {
      await expect(fs.access(observed.tmpPath)).rejects.toThrow();
    }
  });

  it('cleans up the tempfile even when uploadFile throws', async () => {
    const observed: { tmpPath: string | null } = { tmpPath: null };
    const uploadFile = jest
      .fn()
      .mockImplementation(async (_bucket: string, _key: string, tmpPath: string) => {
        observed.tmpPath = tmpPath;
        throw new Error('boom');
      });
    const store = {
      downloadToFile: jest.fn(),
      uploadFile,
      uploadDirectory: jest.fn(),
      deleteObject: jest.fn(),
      getObjectStream: jest.fn(),
    } as unknown as ObjectStore;

    await expect(
      uploadBytes(store, 'b', 'k', Buffer.from('x'), 'text/plain'),
    ).rejects.toThrow('boom');

    // Cleanup happens in finally — the temp dir must be gone.
    if (observed.tmpPath) {
      await expect(fs.access(observed.tmpPath)).rejects.toThrow();
    }
  });
});
