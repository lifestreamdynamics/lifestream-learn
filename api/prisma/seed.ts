import crypto from 'node:crypto';
import path from 'node:path';
import fs from 'node:fs/promises';
import bcrypt from 'bcrypt';
import { Prisma, Role, VideoStatus } from '@prisma/client';
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

/**
 * Slice P3 — stable achievement catalog. Seeded idempotently via upsert
 * so re-runs reconcile title/description/iconKey changes without losing
 * user-unlock history (UserAchievement rows reference the slug id).
 *
 * `criteriaJson` is the discriminated-union payload interpreted by
 * `achievement.service.evaluateAndUnlock`. Adding a new criterion type
 * means adding both a seed row here and an evaluator branch there.
 *
 * VOICE cues are deliberately omitted — per ADR 0004 they are rejected
 * at the API boundary today.
 */
const ACHIEVEMENT_CATALOG: ReadonlyArray<{
  id: string;
  title: string;
  description: string;
  iconKey: string;
  criteriaJson: Prisma.InputJsonValue;
}> = [
  {
    id: 'first_lesson',
    title: 'First Lesson',
    description: 'Complete your first lesson',
    iconKey: 'school',
    criteriaJson: { type: 'lessons_completed', count: 1 },
  },
  {
    id: 'streak_3',
    title: '3-Day Streak',
    description: 'Learn 3 days in a row',
    iconKey: 'local_fire_department',
    criteriaJson: { type: 'streak', days: 3 },
  },
  {
    id: 'streak_7',
    title: 'Week-Long Streak',
    description: 'Learn 7 days in a row',
    iconKey: 'whatshot',
    criteriaJson: { type: 'streak', days: 7 },
  },
  {
    id: 'streak_30',
    title: 'Monthly Streak',
    description: 'Learn 30 days in a row',
    iconKey: 'emoji_events',
    criteriaJson: { type: 'streak', days: 30 },
  },
  {
    id: 'perfect_quiz',
    title: 'Perfect Quiz',
    description: 'Answer all cues in a lesson correctly on the first try',
    iconKey: 'verified',
    criteriaJson: { type: 'perfect_lesson' },
  },
  {
    id: 'course_complete',
    title: 'Course Complete',
    description: 'Complete every lesson in a course',
    iconKey: 'workspace_premium',
    criteriaJson: { type: 'course_complete' },
  },
  {
    id: '100_cues_correct',
    title: 'Century Club',
    description: 'Answer 100 cues correctly',
    iconKey: 'military_tech',
    criteriaJson: { type: 'cues_correct', count: 100 },
  },
  {
    id: 'mcq_master',
    title: 'MCQ Master',
    description: 'Answer 25 MCQ cues correctly',
    iconKey: 'radio_button_checked',
    criteriaJson: { type: 'cues_correct_by_type', cueType: 'MCQ', count: 25 },
  },
  {
    id: 'matching_master',
    title: 'Matching Master',
    description: 'Answer 25 MATCHING cues correctly',
    iconKey: 'extension',
    criteriaJson: { type: 'cues_correct_by_type', cueType: 'MATCHING', count: 25 },
  },
  {
    id: 'blanks_master',
    title: 'Fill-in Master',
    description: 'Answer 25 BLANKS cues correctly',
    iconKey: 'edit_note',
    criteriaJson: { type: 'cues_correct_by_type', cueType: 'BLANKS', count: 25 },
  },
];

async function seedAchievements(): Promise<void> {
  for (const ach of ACHIEVEMENT_CATALOG) {
    await prisma.achievement.upsert({
      where: { id: ach.id },
      // Re-running seed reconciles wording + icons; criteria too, since
      // a criteria-threshold tweak shouldn't require a manual DB edit.
      update: {
        title: ach.title,
        description: ach.description,
        iconKey: ach.iconKey,
        criteriaJson: ach.criteriaJson,
      },
      create: ach,
    });
  }
  logger.info(
    { count: ACHIEVEMENT_CATALOG.length },
    'seed: achievement catalog upserted',
  );
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
    await seedAchievements();
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
