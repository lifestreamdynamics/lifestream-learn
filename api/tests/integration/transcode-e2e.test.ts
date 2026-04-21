import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';
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
const FIXTURE_ROTATED = path.resolve(
  __dirname,
  '..',
  'fixtures',
  'sample-rotated-portrait.mp4',
);
const FIXTURE_VP9 = path.resolve(__dirname, '..', 'fixtures', 'sample-vp9.webm');
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
      // URL shape: /hls/<sig>/<expires>/<videoId>/master.m3u8 (path-embedded token).
      expect(playback.body.masterPlaylistUrl).toMatch(
        /\/hls\/[A-Za-z0-9_-]+\/\d+\/[A-Za-z0-9-]+\/master\.m3u8$/,
      );

      // End-to-end playback verification: fetch the signed master URL
      // through nginx, then fetch the variant playlist + a segment using
      // the exact same path-embedded token — proving that a single
      // signature authorizes every URL under /hls/<sig>/<expires>/<id>/.
      // This mirrors what an HLS player (fvp, ExoPlayer) actually does
      // when it resolves relative URIs from inside the master playlist.
      const masterUrl: string = playback.body.masterPlaylistUrl;
      const masterFetch = await fetch(masterUrl);
      expect(masterFetch.status).toBe(200);
      const masterBody = await masterFetch.text();
      expect(masterBody.startsWith('#EXTM3U')).toBe(true);

      // Derive the base that a player would resolve relative URIs against
      // — the parent "directory" of the master URL, including the token.
      const masterBase = masterUrl.replace(/master\.m3u8$/, '');

      const firstVariantUri = variants[0]!.uri; // e.g. v_0/index.m3u8
      const variantFetch = await fetch(`${masterBase}${firstVariantUri}`);
      expect(variantFetch.status).toBe(200);
      const variantBody = await variantFetch.text();
      expect(variantBody).toMatch(/#EXTINF:/);

      // Pull a segment URI from the variant playlist and fetch it. The
      // variant's URIs are relative to the variant playlist's own URL,
      // which is one path level below master — so the token is still in
      // the resolved segment URL.
      const segLine = variantBody
        .split(/\r?\n/)
        .find((l) => /\.m4s$/.test(l.trim()));
      expect(segLine).toBeDefined();
      const variantDir = firstVariantUri.replace(/\/[^/]+$/, '');
      const segFetch = await fetch(`${masterBase}${variantDir}/${segLine!.trim()}`);
      expect(segFetch.status).toBe(200);

      // Negative: tamper the sig segment of the path — nginx must reject.
      const tampered = masterUrl.replace(
        /\/hls\/([^/]+)\//,
        (_m, sig: string) => {
          const swap = sig[0] === 'a' ? 'b' : 'a';
          return `/hls/${swap}${sig.slice(1)}/`;
        },
      );
      const tamperedFetch = await fetch(tampered);
      expect(tamperedFetch.status).toBe(403);
    },
    90_000,
  );

  it(
    'generates a poster.jpg alongside the HLS tree and serves it via the playback response',
    async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);

      const create = await request(app)
        .post('/api/videos')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ courseId: course.id, title: 'e2e-poster', orderIndex: 0 });
      expect(create.status).toBe(201);
      const videoId: string = create.body.videoId;

      const bytes = await readFile(FIXTURE);
      await tusUpload(TUSD_URL, videoId, bytes);
      await pollStatus(app, designer.accessToken, videoId, 'READY', 60_000);

      // The poster must live at the canonical key.
      const posterHead = await s3Client.send(
        new HeadObjectCommand({
          Bucket: env.S3_VOD_BUCKET,
          Key: `vod/${videoId}/poster.jpg`,
        }),
      );
      expect(posterHead.$metadata.httpStatusCode).toBe(200);
      // A 3s 640x360 testsrc encodes to a small JPEG, but "small" here
      // just means >0 bytes — a truncated poster is the failure mode.
      expect(Number(posterHead.ContentLength ?? 0)).toBeGreaterThan(1024);

      const playback = await request(app)
        .get(`/api/videos/${videoId}/playback`)
        .set('authorization', `Bearer ${designer.accessToken}`);
      expect(playback.status).toBe(200);
      expect(playback.body.posterUrl).toMatch(/\/poster\.jpg$/);

      // Fetch the signed poster URL through nginx — same secure_link
      // signature that guards the master playlist must authorise this
      // path.
      const posterFetch = await fetch(playback.body.posterUrl);
      expect(posterFetch.status).toBe(200);
    },
    90_000,
  );

  it(
    'accepts a rotated phone-capture source and outputs an upright HLS ladder',
    async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);

      const create = await request(app)
        .post('/api/videos')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ courseId: course.id, title: 'e2e-rotated', orderIndex: 0 });
      const videoId: string = create.body.videoId;

      const bytes = await readFile(FIXTURE_ROTATED);
      await tusUpload(TUSD_URL, videoId, bytes);
      await pollStatus(app, designer.accessToken, videoId, 'READY', 60_000);

      // The source is 640×360 frames with a rotation=90 matrix → display
      // width 360, display height 640. The pipeline pre-rotates the
      // pixels and clears the rotation tag, so the RAW decoded frames
      // at the 360p rung should be 640×360 again (same as the coded
      // frames of a landscape source, not portrait). Fetch the init
      // segment of v_0 and probe it.
      const tmpDir = await mkdtemp(path.join(os.tmpdir(), 'e2e-rot-'));
      try {
        const initObj = await s3Client.send(
          new GetObjectCommand({
            Bucket: env.S3_VOD_BUCKET,
            Key: `vod/${videoId}/v_0/init_0.mp4`,
          }),
        );
        const initBytes = Buffer.from(await initObj.Body!.transformToByteArray());
        const seg1Obj = await s3Client.send(
          new GetObjectCommand({
            Bucket: env.S3_VOD_BUCKET,
            Key: `vod/${videoId}/v_0/seg_001.m4s`,
          }),
        );
        const seg1Bytes = Buffer.from(await seg1Obj.Body!.transformToByteArray());
        // Concatenate init + first segment so ffprobe can parse a
        // self-contained stream. fmp4 init alone is not decodable; a
        // segment alone has no sample table.
        const full = Buffer.concat([initBytes, seg1Bytes]);
        const localPath = path.join(tmpDir, 'v_0.mp4');
        await writeFile(localPath, full);

        const probe = await probeWithFfprobe(localPath);
        // Our canonical ladder's 360p rung is 640×360 landscape, so a
        // correctly rotated output has width > height.
        expect(probe.width).toBeGreaterThan(probe.height);
        // And the rotation side-data / tag must be absent (or 0) — a
        // residual tag would make compliant players double-rotate.
        expect(probe.rotation).toBe(0);
      } finally {
        await rm(tmpDir, { recursive: true, force: true });
      }
    },
    120_000,
  );

  it(
    'accepts a VP9/WebM source and transcodes it into the canonical H.264 HLS ladder',
    async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const course = await createCourse(designer.id);

      const create = await request(app)
        .post('/api/videos')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({ courseId: course.id, title: 'e2e-vp9', orderIndex: 0 });
      const videoId: string = create.body.videoId;

      const bytes = await readFile(FIXTURE_VP9);
      await tusUpload(TUSD_URL, videoId, bytes);
      await pollStatus(app, designer.accessToken, videoId, 'READY', 60_000);

      // Master landed; codec string in the variant is H.264 + AAC
      // regardless of the VP9/Opus source — this is the "mono-codec
      // output" guarantee.
      const masterObj = await s3Client.send(
        new GetObjectCommand({
          Bucket: env.S3_VOD_BUCKET,
          Key: `vod/${videoId}/master.m3u8`,
        }),
      );
      const masterText = await masterObj.Body!.transformToString();
      const streamInf = masterText
        .split(/\r?\n/)
        .find((l) => l.startsWith('#EXT-X-STREAM-INF:'));
      expect(streamInf).toBeDefined();
      expect(streamInf!).toMatch(/CODECS="[^"]*avc1\./);
      expect(streamInf!).toMatch(/CODECS="[^"]*mp4a\./);
    },
    120_000,
  );
});

/**
 * Thin wrapper around `ffprobe` for a single local file. Returns the
 * first video stream's width, height, and normalized rotation (0 if
 * neither side-data nor tags.rotate is set). The e2e rotation test
 * uses this to prove the pipeline's transpose + metadata-clear path
 * produces the right output on a real transcode.
 */
function probeWithFfprobe(
  localPath: string,
): Promise<{ width: number; height: number; rotation: number }> {
  return new Promise((resolve, reject) => {
    const child = spawn('ffprobe', [
      '-v', 'error',
      '-print_format', 'json',
      '-show_streams',
      localPath,
    ], { stdio: ['ignore', 'pipe', 'pipe'] });
    const out: Buffer[] = [];
    const errBuf: Buffer[] = [];
    child.stdout.on('data', (c: Buffer) => out.push(c));
    child.stderr.on('data', (c: Buffer) => errBuf.push(c));
    child.on('close', (code: number | null) => {
      if (code !== 0) {
        reject(new Error(`ffprobe failed: ${Buffer.concat(errBuf).toString('utf8').slice(-200)}`));
        return;
      }
      try {
        interface ProbeSide { rotation?: number }
        interface ProbeStream {
          codec_type?: string;
          width?: number;
          height?: number;
          tags?: { rotate?: string | number };
          side_data_list?: ProbeSide[];
        }
        const parsed = JSON.parse(Buffer.concat(out).toString('utf8')) as {
          streams?: ProbeStream[];
        };
        const v = parsed.streams?.find((s) => s.codec_type === 'video');
        if (!v || typeof v.width !== 'number' || typeof v.height !== 'number') {
          reject(new Error('ffprobe: no video stream'));
          return;
        }
        const sideRot = v.side_data_list?.find(
          (s) => typeof s.rotation === 'number',
        )?.rotation;
        let rot = typeof sideRot === 'number' ? sideRot : 0;
        if (!rot && v.tags?.rotate != null) {
          const parsed = parseInt(String(v.tags.rotate), 10);
          rot = Number.isFinite(parsed) ? parsed : 0;
        }
        resolve({
          width: v.width,
          height: v.height,
          rotation: ((rot % 360) + 360) % 360,
        });
      } catch (err) {
        reject(err instanceof Error ? err : new Error(String(err)));
      }
    });
  });
}
