/**
 * Load-test seeder for Slice G2. Idempotent.
 *
 * What this creates:
 *  - One COURSE_DESIGNER user  (`load-designer@example.local`).
 *  - One published course      (`Load Test Course`).
 *  - One READY-faked Video row with a tiny HLS ladder (`master.m3u8` plus
 *    four per-variant playlists and ~8 single-byte segments) written
 *    directly to the `learn-vod` SeaweedFS bucket. Enough surface for
 *    `GET /api/videos/:id/playback` + a masterPlaylist fetch + a couple of
 *    segment requests to hit nginx `secure_link` end-to-end. This is NOT a
 *    full transcode — the pipeline has its own integration tests, and
 *    coupling k6's seed to FFmpeg would balloon the seed time beyond
 *    "quickly reproducible." (Stressing the pipeline itself is out of
 *    scope for G2; the plan is clear that this slice stresses the API +
 *    nginx + SeaweedFS S3 proxy.)
 *  - Three cues on the video (one MCQ, one BLANKS, one MATCHING).
 *  - N LEARNER users (`load-learner-000 .. load-learner-N-1`) enrolled in
 *    the course. N defaults to 200 (matching the plan's VU target).
 *
 * Isolation guard:
 *  - Refuses to run if DATABASE_URL points at `learn_api_test` or
 *    `learn_api_production`. Only `learn_api_development` is allowed.
 *  - Refuses to run if NODE_ENV === 'production'. Belt and suspenders.
 *
 * Run:
 *    npx ts-node -r tsconfig-paths/register --transpile-only api/load/seed.ts
 *    npx ts-node ... api/load/seed.ts --learners 50        # override N
 */
import { randomUUID } from 'node:crypto';
import { PutObjectCommand } from '@aws-sdk/client-s3';
import type { Prisma } from '@prisma/client';
import bcrypt from 'bcrypt';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { prisma } from '@/config/prisma';
import { s3Client } from '@/config/s3';

const LOAD_DESIGNER_EMAIL = 'load-designer@example.local';
const LOAD_COURSE_SLUG = 'load-test-course';
const LOAD_VIDEO_TITLE = 'Load Test Video';
const LOAD_LEARNER_PREFIX = 'load-learner-';
const LOAD_PASSWORD = 'CorrectHorseBattery1'; // dev-only; never deploy.

function assertDevOnly(): void {
  if (env.NODE_ENV === 'production') {
    throw new Error('seed.ts refuses to run with NODE_ENV=production');
  }
  const url = env.DATABASE_URL;
  if (url.includes('learn_api_test')) {
    throw new Error(
      'seed.ts refuses to run against learn_api_test — that DB is owned by the integration suite',
    );
  }
  if (url.includes('learn_api_production')) {
    throw new Error('seed.ts refuses to run against learn_api_production');
  }
  if (!url.includes('learn_api_development')) {
    throw new Error(
      `seed.ts requires DATABASE_URL pointing at learn_api_development (got: ${url.replace(/:[^@]+@/, ':***@')})`,
    );
  }
}

function parseLearnerCount(): number {
  const idx = process.argv.indexOf('--learners');
  if (idx >= 0 && process.argv[idx + 1]) {
    const n = Number(process.argv[idx + 1]);
    if (!Number.isInteger(n) || n < 1 || n > 1000) {
      throw new Error(`--learners must be an integer in [1, 1000], got ${process.argv[idx + 1]}`);
    }
    return n;
  }
  return 200;
}

async function upsertUser(
  email: string,
  role: 'COURSE_DESIGNER' | 'LEARNER',
  displayName: string,
): Promise<{ id: string }> {
  const passwordHash = await bcrypt.hash(LOAD_PASSWORD, 12);
  const user = await prisma.user.upsert({
    where: { email },
    update: { role, displayName },
    create: { email, role, passwordHash, displayName },
    select: { id: true },
  });
  return user;
}

/**
 * Byte-level minimal HLS ladder. Each variant gets a 5-segment playlist;
 * each segment is a single-byte file. Enough to:
 *   - let `video_player` / ffprobe parse the master,
 *   - let k6 fetch a segment URL and hit nginx secure_link,
 * without putting non-trivial bytes through SeaweedFS.
 */
const MASTER_M3U8 = `#EXTM3U
#EXT-X-VERSION:7
#EXT-X-STREAM-INF:BANDWIDTH=400000,AVERAGE-BANDWIDTH=350000,RESOLUTION=640x360,CODECS="avc1.64001e,mp4a.40.2"
v_0/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=900000,AVERAGE-BANDWIDTH=800000,RESOLUTION=960x540,CODECS="avc1.64001f,mp4a.40.2"
v_1/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1800000,AVERAGE-BANDWIDTH=1600000,RESOLUTION=1280x720,CODECS="avc1.64001f,mp4a.40.2"
v_2/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3500000,AVERAGE-BANDWIDTH=3200000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
v_3/index.m3u8
`;

const VARIANT_PLAYLIST = `#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:4
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-MAP:URI="init.mp4"
#EXTINF:4.0,
seg_0.m4s
#EXTINF:4.0,
seg_1.m4s
#EXTINF:4.0,
seg_2.m4s
#EXT-X-ENDLIST
`;

async function writeHlsLadder(videoId: string): Promise<string> {
  // nginx rewrites `/hls/<videoId>/...` → `/learn-vod/vod/<videoId>/...`
  // (see infra/nginx/local.conf). The API's `hlsPrefix` on the Video row
  // is informational; the binding truth for secure_link is the bucket key
  // layout, so we must write under `vod/<id>/`.
  const prefix = `vod/${videoId}/`;
  const putText = async (key: string, body: string): Promise<void> => {
    await s3Client.send(
      new PutObjectCommand({
        Bucket: env.S3_VOD_BUCKET,
        Key: `${prefix}${key}`,
        Body: body,
        ContentType: key.endsWith('.m3u8') ? 'application/vnd.apple.mpegurl' : 'application/octet-stream',
      }),
    );
  };
  const putBytes = async (key: string): Promise<void> => {
    await s3Client.send(
      new PutObjectCommand({
        Bucket: env.S3_VOD_BUCKET,
        Key: `${prefix}${key}`,
        Body: Buffer.from([0]),
        ContentType: 'application/octet-stream',
      }),
    );
  };

  await putText('master.m3u8', MASTER_M3U8);
  for (const v of ['v_0', 'v_1', 'v_2', 'v_3']) {
    await putText(`${v}/index.m3u8`, VARIANT_PLAYLIST);
    await putBytes(`${v}/init.mp4`);
    await putBytes(`${v}/seg_0.m4s`);
    await putBytes(`${v}/seg_1.m4s`);
    await putBytes(`${v}/seg_2.m4s`);
  }
  return prefix;
}

const MCQ_PAYLOAD: Prisma.InputJsonValue = {
  question: 'What year did learn-api ship its k6 baseline?',
  choices: ['2024', '2025', '2026', '2027'],
  answerIndex: 2,
  explanation: 'Phase 7 hardening landed in 2026-04.',
};

const BLANKS_PAYLOAD: Prisma.InputJsonValue = {
  sentenceTemplate: 'The object store is {{0}} and the upload server is {{1}}.',
  blanks: [
    { accept: ['SeaweedFS', 'seaweedfs'] },
    { accept: ['tusd'] },
  ],
};

const MATCHING_PAYLOAD: Prisma.InputJsonValue = {
  prompt: 'Match the component to its port',
  left: ['API', 'tusd', 'SeaweedFS S3'],
  right: ['3011', '1080', '8333'],
  pairs: [
    [0, 0],
    [1, 1],
    [2, 2],
  ],
};

async function upsertCue(
  videoId: string,
  orderIndex: number,
  type: 'MCQ' | 'BLANKS' | 'MATCHING',
  payload: Prisma.InputJsonValue,
  atMs: number,
): Promise<void> {
  // Cues lack a natural unique key beyond (videoId, atMs, orderIndex). Use
  // findFirst + conditional create so re-running the seed doesn't multiply
  // cues.
  const existing = await prisma.cue.findFirst({
    where: { videoId, type, orderIndex },
    select: { id: true },
  });
  if (existing) {
    await prisma.cue.update({
      where: { id: existing.id },
      data: { payload, atMs, pause: true },
    });
    return;
  }
  await prisma.cue.create({
    data: { videoId, atMs, pause: true, type, payload, orderIndex },
  });
}

async function main(): Promise<void> {
  assertDevOnly();
  const learnerCount = parseLearnerCount();

  logger.info(
    { learnerCount, database: env.DATABASE_URL.replace(/:[^@]+@/, ':***@') },
    'seed: starting',
  );

  const designer = await upsertUser(LOAD_DESIGNER_EMAIL, 'COURSE_DESIGNER', 'Load Designer');

  const course = await prisma.course.upsert({
    where: { slug: LOAD_COURSE_SLUG },
    update: { ownerId: designer.id, published: true, title: 'Load Test Course' },
    create: {
      ownerId: designer.id,
      slug: LOAD_COURSE_SLUG,
      title: 'Load Test Course',
      description: 'Seeded by api/load/seed.ts for k6 baseline runs.',
      published: true,
    },
    select: { id: true },
  });

  // Videos don't have a natural unique key in our schema — find by
  // (courseId, orderIndex=0) and upsert.
  const existingVideo = await prisma.video.findFirst({
    where: { courseId: course.id, orderIndex: 0 },
    select: { id: true, status: true, hlsPrefix: true },
  });
  let videoId: string;
  if (existingVideo) {
    videoId = existingVideo.id;
  } else {
    videoId = randomUUID();
    await prisma.video.create({
      data: {
        id: videoId,
        courseId: course.id,
        title: LOAD_VIDEO_TITLE,
        orderIndex: 0,
        status: 'READY',
        sourceKey: `uploads/${videoId}`,
        durationMs: 12_000,
      },
    });
  }

  // Always re-write the HLS ladder — object store might have been reset.
  const hlsPrefix = await writeHlsLadder(videoId);
  await prisma.video.update({
    where: { id: videoId },
    data: { status: 'READY', hlsPrefix, durationMs: 12_000 },
  });

  await upsertCue(videoId, 0, 'MCQ', MCQ_PAYLOAD, 2_000);
  await upsertCue(videoId, 1, 'BLANKS', BLANKS_PAYLOAD, 6_000);
  await upsertCue(videoId, 2, 'MATCHING', MATCHING_PAYLOAD, 10_000);

  const learnerIds: string[] = [];
  for (let i = 0; i < learnerCount; i++) {
    const email = `${LOAD_LEARNER_PREFIX}${String(i).padStart(4, '0')}@example.local`;
    const displayName = `Load Learner ${i}`;
    const { id } = await upsertUser(email, 'LEARNER', displayName);
    learnerIds.push(id);
  }

  await prisma.enrollment.createMany({
    data: learnerIds.map((userId) => ({ userId, courseId: course.id })),
    skipDuplicates: true,
  });

  logger.info(
    {
      designer: LOAD_DESIGNER_EMAIL,
      course: LOAD_COURSE_SLUG,
      videoId,
      learnerCount,
      hlsPrefix,
    },
    'seed: complete',
  );

  // Emit the k6-friendly summary on stdout so the operator can pipe it.
  /* eslint-disable no-console */
  console.log('---');
  console.log(`LEARN_LOAD_DESIGNER_EMAIL=${LOAD_DESIGNER_EMAIL}`);
  console.log(`LEARN_LOAD_PASSWORD=${LOAD_PASSWORD}`);
  console.log(`LEARN_LOAD_COURSE_ID=${course.id}`);
  console.log(`LEARN_LOAD_VIDEO_ID=${videoId}`);
  console.log(`LEARN_LOAD_LEARNER_PREFIX=${LOAD_LEARNER_PREFIX}`);
  console.log(`LEARN_LOAD_LEARNER_COUNT=${learnerCount}`);
  /* eslint-enable no-console */
}

main()
  .then(async () => {
    await prisma.$disconnect();
    process.exit(0);
  })
  .catch(async (err) => {
    logger.error({ err }, 'seed failed');
    await prisma.$disconnect();
    process.exit(1);
  });
