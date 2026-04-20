import { readFile } from 'node:fs/promises';
import path from 'node:path';
import type { Server } from 'node:http';
import type { Express } from 'express';
import request from 'supertest';
import { GetObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
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

      // Slice G3: programmatic assertion that the master playlist
      // conforms to the HLS authoring spec AND advertises the right
      // ladder. Pre-G3 this was a "run ffprobe by hand" smoke in the
      // plan file; now it's a hard test.
      //
      // IMPORTANT: DEFAULT_LADDER in src/services/ffmpeg/ladder.ts is
      // filtered by source resolution (`rung.height <= probe.height`)
      // so upscaling is never attempted. Our fixture sample-3s.mp4 is
      // 640×360, so only the 360p rung survives the filter. A future
      // higher-resolution fixture would exercise more variants; this
      // assertion reads the ladder dynamically rather than hard-coding
      // a count so the test stays honest about what the pipeline
      // actually produced.
      const masterObj = await s3Client.send(
        new GetObjectCommand({
          Bucket: env.S3_VOD_BUCKET,
          Key: `vod/${videoId}/master.m3u8`,
        }),
      );
      const masterText = await masterObj.Body!.transformToString();

      // Structural checks.
      expect(masterText.startsWith('#EXTM3U')).toBe(true);
      expect(masterText).toMatch(/#EXT-X-VERSION:\s*[67]/);

      // Parse every #EXT-X-STREAM-INF rendition into a structured
      // record. Failing this parse means ffmpeg's hls muxer emitted
      // something the authoring spec disallows.
      const lines = masterText.split(/\r?\n/);
      const variants: Array<{
        bandwidth: number;
        resolution: { w: number; h: number } | null;
        codecs: string | null;
        uri: string;
      }> = [];
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
        const attrs = line.slice('#EXT-X-STREAM-INF:'.length);
        const bwMatch = /(?:^|,)BANDWIDTH=(\d+)/.exec(attrs);
        const resMatch = /(?:^|,)RESOLUTION=(\d+)x(\d+)/.exec(attrs);
        const codecsMatch = /(?:^|,)CODECS="([^"]+)"/.exec(attrs);
        expect(bwMatch).not.toBeNull();
        const next = lines[i + 1]?.trim() ?? '';
        expect(next.length).toBeGreaterThan(0);
        expect(next.startsWith('#')).toBe(false); // URI line, not a directive
        variants.push({
          bandwidth: Number(bwMatch![1]),
          resolution: resMatch ? { w: Number(resMatch[1]), h: Number(resMatch[2]) } : null,
          codecs: codecsMatch?.[1] ?? null,
          uri: next,
        });
      }
      expect(variants.length).toBeGreaterThan(0);

      // Every advertised variant must have a real index.m3u8 in the
      // bucket — no dangling URIs.
      for (const v of variants) {
        await s3Client.send(
          new HeadObjectCommand({
            Bucket: env.S3_VOD_BUCKET,
            // Variant URIs in the master are relative (e.g. v_0/index.m3u8).
            Key: `vod/${videoId}/${v.uri}`,
          }),
        );
        // HeadObject throws on 404; reaching here means the variant
        // playlist exists.
        expect(v.bandwidth).toBeGreaterThan(0);
        expect(v.codecs).toMatch(/avc1\./); // H.264 Main per ADR 0004 scope
        expect(v.codecs).toMatch(/mp4a\./); // AAC
      }

      const playback = await request(app)
        .get(`/api/videos/${videoId}/playback`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(playback.status).toBe(200);
      expect(playback.body.masterPlaylistUrl).toMatch(/\?md5=.+&expires=\d+$/);
    },
    90_000,
  );
});
