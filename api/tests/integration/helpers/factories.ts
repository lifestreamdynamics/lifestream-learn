import { randomUUID } from 'node:crypto';
import type { CueType, Role } from '@prisma/client';
import { Prisma } from '@prisma/client';
import { prisma } from '@/config/prisma';
import { hashPassword } from '@/utils/password';
import { signAccessToken } from '@/utils/jwt';

export async function createUser(
  overrides: { email?: string; role?: Role; displayName?: string; password?: string } = {},
): Promise<{ id: string; email: string; role: Role; displayName: string; accessToken: string }> {
  const email = overrides.email ?? `u_${randomUUID()}@example.local`;
  const role = overrides.role ?? 'LEARNER';
  const displayName = overrides.displayName ?? 'Test User';
  const password = overrides.password ?? 'CorrectHorseBattery1';
  const passwordHash = await hashPassword(password);
  const user = await prisma.user.create({
    data: { email, passwordHash, role, displayName },
  });
  return {
    id: user.id,
    email: user.email,
    role: user.role,
    displayName: user.displayName,
    accessToken: signAccessToken(user),
  };
}

export async function createCourse(
  ownerId: string,
  overrides: { title?: string; slug?: string; published?: boolean } = {},
): Promise<{ id: string; ownerId: string }> {
  const course = await prisma.course.create({
    data: {
      ownerId,
      title: overrides.title ?? 'Test Course',
      slug: overrides.slug ?? `course-${randomUUID()}`,
      description: 'desc',
      published: overrides.published ?? false,
    },
  });
  return { id: course.id, ownerId: course.ownerId };
}

export async function addCollaborator(courseId: string, userId: string): Promise<void> {
  await prisma.courseCollaborator.create({ data: { courseId, userId } });
}

export async function enroll(userId: string, courseId: string): Promise<void> {
  await prisma.enrollment.create({ data: { userId, courseId } });
}

export async function createVideoDirect(
  courseId: string,
  overrides: {
    id?: string;
    title?: string;
    orderIndex?: number;
    status?: 'UPLOADING' | 'TRANSCODING' | 'READY' | 'FAILED';
    hlsPrefix?: string | null;
    durationMs?: number | null;
  } = {},
): Promise<{ id: string }> {
  const id = overrides.id ?? randomUUID();
  const video = await prisma.video.create({
    data: {
      id,
      courseId,
      title: overrides.title ?? 'Test Video',
      orderIndex: overrides.orderIndex ?? 0,
      status: overrides.status ?? 'UPLOADING',
      sourceKey: `uploads/${id}`,
      hlsPrefix: overrides.hlsPrefix ?? null,
      durationMs: overrides.durationMs ?? null,
    },
  });
  return { id: video.id };
}

export async function createCueDirect(
  videoId: string,
  opts: {
    type: CueType;
    payload: Prisma.InputJsonValue;
    atMs?: number;
    pause?: boolean;
    orderIndex?: number;
  },
): Promise<{ id: string; type: CueType }> {
  const cue = await prisma.cue.create({
    data: {
      videoId,
      atMs: opts.atMs ?? 0,
      pause: opts.pause ?? true,
      type: opts.type,
      payload: opts.payload,
      orderIndex: opts.orderIndex ?? 0,
    },
  });
  return { id: cue.id, type: cue.type };
}
