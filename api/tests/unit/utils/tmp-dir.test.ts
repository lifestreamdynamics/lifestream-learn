import '@tests/unit/setup';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { makeJobTmpDir, cleanupJobTmpDir } from '@/utils/tmp-dir';

describe('tmp-dir utils', () => {
  it('makeJobTmpDir creates a directory under TRANSCODE_TMP_DIR', async () => {
    const jobId = `test-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    const dir = await makeJobTmpDir(jobId);
    try {
      expect(dir.startsWith(path.join(os.tmpdir(), 'learn-transcode'))).toBe(true);
      const stat = await fs.stat(dir);
      expect(stat.isDirectory()).toBe(true);
      // Idempotent — second call should not throw.
      await expect(makeJobTmpDir(jobId)).resolves.toBe(dir);
    } finally {
      await fs.rm(dir, { recursive: true, force: true });
    }
  });

  it('cleanupJobTmpDir removes the directory and its contents', async () => {
    const jobId = `test-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    const dir = await makeJobTmpDir(jobId);
    await fs.writeFile(path.join(dir, 'a.txt'), 'hello');
    await fs.mkdir(path.join(dir, 'sub'));
    await fs.writeFile(path.join(dir, 'sub', 'b.txt'), 'world');

    await cleanupJobTmpDir(dir);

    await expect(fs.stat(dir)).rejects.toMatchObject({ code: 'ENOENT' });
  });

  it('cleanupJobTmpDir is a no-op for a missing directory', async () => {
    const dir = path.join(os.tmpdir(), `learn-transcode-missing-${Date.now()}`);
    await expect(cleanupJobTmpDir(dir)).resolves.toBeUndefined();
  });
});
