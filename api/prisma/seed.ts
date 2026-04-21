import crypto from 'node:crypto';
import path from 'node:path';
import fs from 'node:fs/promises';
import bcrypt from 'bcrypt';
import { Role, VideoStatus } from '@prisma/client';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { prisma } from '@/config/prisma';
import { objectStore } from '@/services/object-store';
import { enqueueTranscode, closeTranscodeQueue } from '@/queues/transcode.queue';

interface SeedUser {
  email: string;
  role: Role;
  displayName: string;
  providedPassword: string | undefined;
}

async function upsertUser(spec: SeedUser): Promise<{
  userId: string;
  email: string;
  password: string;
  generated: boolean;
}> {
  const generated = spec.providedPassword === undefined;
  const password = spec.providedPassword ?? crypto.randomBytes(12).toString('base64url');
  const passwordHash = await bcrypt.hash(password, 12);
  // When the operator explicitly supplied a password via env, we rehash on
  // every seed run so re-running seed always reconciles the DB to env state.
  // When seed generated a random password, we leave the existing hash alone
  // so re-runs don't rotate credentials under the operator.
  const update = generated ? {} : { passwordHash };
  const user = await prisma.user.upsert({
    where: { email: spec.email },
    update,
    create: {
      email: spec.email,
      passwordHash,
      role: spec.role,
      displayName: spec.displayName,
    },
  });
  return { userId: user.id, email: spec.email, password, generated };
}

const SAMPLE_COURSE_SLUG = 'dev-sample-101';
const SAMPLE_FIXTURE_REL = '../../ops/fixtures/sample-module.mp4';

async function ensureSampleCourse(ownerId: string): Promise<string> {
  const course = await prisma.course.upsert({
    where: { slug: SAMPLE_COURSE_SLUG },
    update: { ownerId, published: true },
    create: {
      slug: SAMPLE_COURSE_SLUG,
      title: 'Dev Sample 101',
      description: 'Bootstrap fixture course for local development.',
      ownerId,
      published: true,
    },
  });
  return course.id;
}

// Poll until video reaches READY or FAILED, or timeout expires.
async function waitForTranscode(videoId: string, timeoutMs: number): Promise<VideoStatus> {
  const deadline = Date.now() + timeoutMs;
  let lastLoggedStatus: VideoStatus | null = null;
  while (Date.now() < deadline) {
    const v = await prisma.video.findUnique({ where: { id: videoId }, select: { status: true } });
    if (!v) throw new Error(`video ${videoId} disappeared while polling`);
    if (v.status !== lastLoggedStatus) {
      logger.info({ videoId, status: v.status }, 'seed: transcode status');
      lastLoggedStatus = v.status;
    }
    if (v.status === 'READY' || v.status === 'FAILED') return v.status;
    await new Promise((r) => setTimeout(r, 2000));
  }
  throw new Error(`transcode for ${videoId} did not complete within ${timeoutMs}ms`);
}

async function ensureSampleVideo(courseId: string): Promise<void> {
  const existing = await prisma.video.findFirst({
    where: { courseId, orderIndex: 0, status: 'READY' },
    select: { id: true },
  });
  if (existing) {
    logger.info({ courseId, videoId: existing.id }, 'seed: sample video already READY, skipping');
    return;
  }

  const fixturePath = path.resolve(__dirname, SAMPLE_FIXTURE_REL);
  try {
    await fs.access(fixturePath);
  } catch {
    logger.warn(
      { fixturePath },
      'seed: sample video fixture missing — skipping sample-video seed (this is fine if you are not running the bootstrap for the first time)',
    );
    return;
  }

  // Clean up any non-READY orphan from a previous aborted seed so the
  // orderIndex=0 slot is free. Safe because we only delete rows that never
  // became READY.
  await prisma.video.deleteMany({
    where: { courseId, orderIndex: 0, status: { not: 'READY' } },
  });

  const video = await prisma.video.create({
    data: {
      courseId,
      title: 'Module 01',
      orderIndex: 0,
      status: 'UPLOADING',
    },
  });
  const sourceKey = `seed-sample/${video.id}.mp4`;

  logger.info({ videoId: video.id, sourceKey, fixturePath }, 'seed: uploading sample to S3');
  await objectStore.uploadFile(env.S3_UPLOAD_BUCKET, sourceKey, fixturePath, 'video/mp4');

  await prisma.video.update({
    where: { id: video.id },
    data: { sourceKey, status: 'TRANSCODING' },
  });

  logger.info({ videoId: video.id }, 'seed: enqueuing transcode');
  await enqueueTranscode({ videoId: video.id, sourceKey });

  const finalStatus = await waitForTranscode(video.id, 180_000);
  if (finalStatus === 'FAILED') {
    throw new Error(`sample video transcode FAILED (videoId=${video.id}) — check worker logs`);
  }
  logger.info({ videoId: video.id }, 'seed: sample video READY');
}

async function main(): Promise<void> {
  const dev = env.SEED_DEV_USER_PASSWORD;

  const seeds: SeedUser[] = [
    {
      email: env.SEED_ADMIN_EMAIL,
      role: 'ADMIN',
      displayName: 'Admin',
      providedPassword: env.SEED_ADMIN_PASSWORD,
    },
    {
      email: env.SEED_DESIGNER_EMAIL,
      role: 'COURSE_DESIGNER',
      displayName: 'Dev Designer',
      providedPassword: dev,
    },
    {
      email: env.SEED_LEARNER_EMAIL,
      role: 'LEARNER',
      displayName: 'Dev Learner',
      providedPassword: dev,
    },
  ];

  try {
    const results = await Promise.all(seeds.map(upsertUser));
    for (const r of results) {
      if (r.generated) {
        logger.warn(
          { email: r.email, password: r.password },
          'seed: generated password (save this — it will not be shown again)',
        );
      } else {
        logger.info({ email: r.email }, 'seed: user upserted');
      }
    }

    if (env.SEED_SAMPLE_VIDEO) {
      const designer = results.find((r) => r.email === env.SEED_DESIGNER_EMAIL);
      if (!designer) throw new Error('seed: designer user missing after upsert');
      const courseId = await ensureSampleCourse(designer.userId);
      await ensureSampleVideo(courseId);
    } else {
      logger.info('seed: SEED_SAMPLE_VIDEO=false, skipping sample course/video');
    }
  } finally {
    await closeTranscodeQueue();
    await prisma.$disconnect();
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    logger.error({ err }, 'seed failed');
    process.exit(1);
  });
