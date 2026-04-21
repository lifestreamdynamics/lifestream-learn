import type { ObjectStore } from '@/services/object-store';

/**
 * Bridge between a raw Buffer (what the HTTP layer hands us) and the
 * file-oriented `ObjectStore.uploadFile()`. Uses the S3 client's
 * PutObjectCommand directly when the concrete store exposes a
 * `putObject` helper; otherwise falls back to writing a temp file so
 * the public `ObjectStore` interface stays stable for existing callers.
 *
 * Shared between the avatar upload path (`user.service`) and the
 * caption upload path (`caption.service`). Both hand in modest-size
 * buffers (<=2 MB avatar, <=512 KB caption) that don't warrant
 * spooling to disk on the production S3 client.
 */
export async function uploadBytes(
  objectStore: ObjectStore,
  bucket: string,
  key: string,
  bytes: Buffer,
  contentType: string,
): Promise<void> {
  const maybePut = (objectStore as unknown as {
    putObject?: (b: string, k: string, body: Buffer, ct: string) => Promise<void>;
  }).putObject;
  if (typeof maybePut === 'function') {
    await maybePut.call(objectStore, bucket, key, bytes, contentType);
    return;
  }
  const os = await import('node:os');
  const path = await import('node:path');
  const fs = await import('node:fs/promises');
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'learn-upload-'));
  const tmpPath = path.join(tmpDir, 'blob.bin');
  try {
    await fs.writeFile(tmpPath, bytes);
    await objectStore.uploadFile(bucket, key, tmpPath, contentType);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true }).catch(() => {
      // Cleanup is best-effort.
    });
  }
}
