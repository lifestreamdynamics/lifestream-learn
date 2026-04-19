import { readFile } from 'node:fs/promises';
import path from 'node:path';
import type { Server } from 'node:http';
import type { Express } from 'express';
import request from 'supertest';
import { HeadObjectCommand } from '@aws-sdk/client-s3';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import {
  createUser,
  createCourse,
} from '@tests/integration/helpers/factories';
import { startTestWorker, type TestWorkerHandle } from '@tests/integration/helpers/test-worker';
import { closeTranscodeQueue } from '@/queues/transcode.queue';
import { env } from '@/config/env';
import { s3Client } from '@/config/s3';

const API_PORT = 3011;

const FIXTURE = path.resolve(__dirname, '..', 'fixtures', 'sample-3s.mp4');
const TUSD_URL = env.TUSD_PUBLIC_URL; // e.g. http://localhost:1081/files

async function tusUpload(uploadUrl: string, videoId: string, bytes: Buffer): Promise<void> {
  const b64 = Buffer.from(videoId).toString('base64').replace(/=+$/, '');
  const createRes = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      'Tus-Resumable': '1.0.0',
      'Upload-Length': String(bytes.length),
      'Upload-Metadata': `videoId ${b64}`,
    },
  });
  if (createRes.status !== 201) {
    throw new Error(`tus POST returned ${createRes.status}`);
  }
  const location = createRes.headers.get('location');
  if (!location) throw new Error('tus POST returned no Location header');

  // If tusd is reachable via a port-mapped URL, Location may be the internal
  // URL (http://tusd:1080/files/<id>); normalize to TUSD_URL host.
  const tusHost = new URL(uploadUrl);
  const locUrl = new URL(location, uploadUrl);
  locUrl.protocol = tusHost.protocol;
  locUrl.host = tusHost.host;

  const patchRes = await fetch(locUrl.toString(), {
    method: 'PATCH',
    headers: {
      'Tus-Resumable': '1.0.0',
      'Upload-Offset': '0',
      'Content-Type': 'application/offset+octet-stream',
    },
    body: bytes,
  });
  if (patchRes.status !== 204) {
    const text = await patchRes.text().catch(() => '');
    throw new Error(
      `tus PATCH to ${locUrl.toString()} returned ${patchRes.status}: ${text.slice(0, 200)}`,
    );
  }
}

async function pollStatus(
  app: Express,
  token: string,
  videoId: string,
  target: string,
  timeoutMs = 60_000,
): Promise<string> {
  const start = Date.now();
  let last = 'unknown';
  while (Date.now() - start < timeoutMs) {
    const res = await request(app)
      .get(`/api/videos/${videoId}`)
      .set('authorization', `Bearer ${token}`);
    last = res.body?.status ?? 'unknown';
    if (last === target) return last;
    if (last === 'FAILED') throw new Error('video entered FAILED state');
    await new Promise((r) => setTimeout(r, 1000));
  }
  throw new Error(`timeout waiting for status=${target}, last=${last}`);
}

describe('Transcode end-to-end (real tusd + worker)', () => {
  let workerHandle: TestWorkerHandle | null = null;
  let server: Server | null = null;

  beforeAll(async () => {
    // The real tusd → API hook requires the API to listen on the port that
    // docker-compose's tusd service points at (host.docker.internal:3011).
    // supertest alone binds ephemerally, so we need a real listener.
    const app = await getTestApp();
    server = await new Promise<Server>((resolve) => {
      const s = app.listen(API_PORT, () => resolve(s));
    });
    workerHandle = startTestWorker();
  }, 30_000);

  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    if (workerHandle) await workerHandle.close();
    await closeTranscodeQueue();
    if (server) await new Promise<void>((resolve) => server!.close(() => resolve()));
    await closeConnections();
  }, 30_000);

  it(
    'uploads a 3s clip via tus, transcodes to READY, and serves a signed playback URL',
    async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);

      const create = await request(app)
        .post('/api/videos')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ courseId: course.id, title: 'e2e', orderIndex: 0 });
      expect(create.status).toBe(201);
      const videoId: string = create.body.videoId;

      const bytes = await readFile(FIXTURE);
      await tusUpload(TUSD_URL, videoId, bytes);

      await pollStatus(app, designer.accessToken, videoId, 'READY', 60_000);

      // Assert master.m3u8 landed in the VOD bucket.
      const head = await s3Client.send(
        new HeadObjectCommand({
          Bucket: env.S3_VOD_BUCKET,
          Key: `vod/${videoId}/master.m3u8`,
        }),
      );
      expect(head.$metadata.httpStatusCode).toBe(200);

      const playback = await request(app)
        .get(`/api/videos/${videoId}/playback`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(playback.status).toBe(200);
      expect(playback.body.masterPlaylistUrl).toMatch(/\?md5=.+&expires=\d+$/);
    },
    90_000,
  );
});
