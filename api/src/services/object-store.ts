import { createReadStream, createWriteStream } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import { pipeline } from 'node:stream/promises';
import type { Readable } from 'node:stream';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  type S3Client,
} from '@aws-sdk/client-s3';
import { s3Client } from '@/config/s3';
import { contentTypeForPath } from '@/utils/content-type';

export interface ObjectStore {
  downloadToFile(bucket: string, key: string, localPath: string): Promise<void>;
  uploadFile(bucket: string, key: string, localPath: string, contentType: string): Promise<void>;
  uploadDirectory(
    bucket: string,
    keyPrefix: string,
    localDir: string,
    opts?: { concurrency?: number },
  ): Promise<{ uploaded: number }>;
  deleteObject(bucket: string, key: string): Promise<void>;
}

/**
 * Build an ObjectStore over an S3-compatible client (SeaweedFS today, R2/S3
 * later). All seams that need swapping for a managed CDN go through here.
 */
export function createObjectStore(s3: S3Client = s3Client): ObjectStore {
  async function downloadToFile(bucket: string, key: string, localPath: string): Promise<void> {
    await fs.mkdir(path.dirname(localPath), { recursive: true });
    const res = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
    if (!res.Body) {
      throw new Error(`s3 GetObject returned no body for ${bucket}/${key}`);
    }
    // The S3 SDK's `Body` type in node is a `Readable` at runtime even though
    // the union is wider; the runtime path is fine for stream.pipeline.
    await pipeline(res.Body as Readable, createWriteStream(localPath));
  }

  async function uploadFile(
    bucket: string,
    key: string,
    localPath: string,
    contentType: string,
  ): Promise<void> {
    await s3.send(new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: createReadStream(localPath),
      ContentType: contentType,
    }));
  }

  async function uploadDirectory(
    bucket: string,
    keyPrefix: string,
    localDir: string,
    opts: { concurrency?: number } = {},
  ): Promise<{ uploaded: number }> {
    const concurrency = Math.max(1, opts.concurrency ?? 4);
    // Recursively enumerate files; readdir(recursive: true) returns Dirent
    // entries with `parentPath` so we can re-derive an absolute path.
    // `parentPath` is documented from Node 20+; cast handled below for
    // compatibility with @types/node.
    interface RecursiveDirent {
      name: string;
      parentPath?: string;
      path?: string;
      isFile(): boolean;
    }
    const entries = (await fs.readdir(localDir, {
      recursive: true,
      withFileTypes: true,
    })) as unknown as RecursiveDirent[];

    const files: { absPath: string; relPath: string; key: string; contentType: string }[] = [];
    for (const entry of entries) {
      if (!entry.isFile()) continue;
      const parent = entry.parentPath ?? entry.path ?? localDir;
      const absPath = path.join(parent, entry.name);
      const relPath = path.relative(localDir, absPath).split(path.sep).join('/');
      const key = `${keyPrefix}/${relPath}`;
      files.push({ absPath, relPath, key, contentType: contentTypeForPath(entry.name) });
    }

    // Upload everything except master.m3u8 first. Then upload master.m3u8 last
    // so any client polling early never sees a master that points at variant
    // playlists / segments that aren't there yet.
    const masterFiles = files.filter((f) => path.basename(f.relPath) === 'master.m3u8');
    const otherFiles = files.filter((f) => path.basename(f.relPath) !== 'master.m3u8');

    let uploaded = 0;
    const inflight = new Set<Promise<unknown>>();

    const enqueue = (file: typeof files[number]): void => {
      const p = uploadFile(bucket, file.key, file.absPath, file.contentType)
        .then(() => {
          uploaded += 1;
        })
        .finally(() => {
          inflight.delete(p);
        });
      inflight.add(p);
    };

    for (const file of otherFiles) {
      if (inflight.size >= concurrency) {
        await Promise.race(inflight);
      }
      enqueue(file);
    }
    await Promise.all(inflight);

    // Now master playlists, sequentially (typically only one).
    for (const file of masterFiles) {
      await uploadFile(bucket, file.key, file.absPath, file.contentType);
      uploaded += 1;
    }

    return { uploaded };
  }

  async function deleteObject(bucket: string, key: string): Promise<void> {
    await s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
  }

  return { downloadToFile, uploadFile, uploadDirectory, deleteObject };
}

/**
 * Default singleton wired to the production S3 client. Workers and route
 * handlers should import this rather than calling `createObjectStore()`
 * themselves; tests construct their own with a mock client.
 */
export const objectStore = createObjectStore();
