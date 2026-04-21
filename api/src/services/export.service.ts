import type { Prisma, PrismaClient } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { NotFoundError } from '@/utils/errors';

/**
 * Slice P8 — Personal data export (GDPR "right of access").
 *
 * Produces a typed JSON document of everything we hold about the caller.
 * Philosophy:
 *
 *   - **Owner-only.** The endpoint that calls this service is behind
 *     `authenticate` and scoped to the caller's own userId — no admin
 *     path, no operator backdoor.
 *   - **Credentials never leave the DB.** `passwordHash`,
 *     `totpSecretEncrypted`, `mfaBackupCodes`, WebAuthn `publicKey` /
 *     `credentialId` bytes are intentionally excluded. The export is
 *     "what we hold about you", not "a backup you can re-import".
 *   - **Bounded size.** Heavy users can accumulate tens of thousands of
 *     `AnalyticsEvent` rows; we cap the payload at a sensible ceiling
 *     and flag truncation so tooling can detect it.
 *   - **Owned content is separate.** Courses the user authored are NOT
 *     included — that's copyrightable content with its own lifecycle.
 *     We include a count-only pointer instead.
 *   - **Schema is versioned.** `schemaVersion` is bumped on any
 *     backwards-incompatible shape change; clients branching on the
 *     field remain deterministic across upgrades.
 *
 * Called from `GET /api/me/export` via `export.controller.ts`.
 */

/** Version the export payload shape. Bump on any shape change so clients
 * that branch on the value stay deterministic. */
export const EXPORT_SCHEMA_VERSION = 1;

/** Cap on the number of analytics events we return. A single user can
 * accumulate thousands — most-recent first, with a truncation flag. */
export const ANALYTICS_EVENT_EXPORT_CAP = 10_000;

/** Cap on revoked sessions returned (non-revoked are always included). */
export const REVOKED_SESSION_EXPORT_CAP = 100;

export interface UserDataExport {
  schemaVersion: typeof EXPORT_SCHEMA_VERSION;
  exportedAt: string;
  user: {
    id: string;
    email: string;
    displayName: string;
    role: string;
    createdAt: string;
    updatedAt: string;
    avatarKey: string | null;
    useGravatar: boolean;
    preferences: Prisma.JsonValue | null;
    mfaEnabled: boolean;
    deletedAt: string | null;
    deletionPurgeAt: string | null;
    passwordChangedAt: string | null;
  };
  enrollments: Array<{
    id: string;
    courseId: string;
    courseTitle: string;
    startedAt: string;
    lastVideoId: string | null;
    lastPosMs: number | null;
    updatedAt: string;
  }>;
  attempts: Array<{
    id: string;
    cueId: string;
    videoId: string;
    correct: boolean;
    scoreJson: Prisma.JsonValue | null;
    submittedAt: string;
  }>;
  analyticsEvents: Array<{
    id: string;
    eventType: string;
    videoId: string | null;
    cueId: string | null;
    payload: Prisma.JsonValue;
    occurredAt: string;
    receivedAt: string;
  }>;
  analyticsEventsTruncated: boolean;
  achievements: Array<{
    achievementId: string;
    title: string;
    unlockedAt: string;
  }>;
  sessions: Array<{
    id: string;
    deviceLabel: string | null;
    ipHashPrefix: string | null;
    createdAt: string;
    lastSeenAt: string;
    revokedAt: string | null;
  }>;
  ownedCoursesCount: number;
  collaboratorCoursesCount: number;
}

export interface ExportService {
  /**
   * Assemble the full export payload for `userId`. Throws
   * `NotFoundError` when the user row is missing — the controller maps
   * that to 404. Soft-deleted users are rejected at the controller
   * boundary (GDPR "right of erasure" supersedes "right of access"
   * for already-deleted accounts).
   */
  exportUserData(userId: string): Promise<UserDataExport>;
}

/**
 * Produce a partial IP-hash prefix for the export, matching the public
 * sessions list shape. We NEVER return the full hash — the first 8 hex
 * chars give the owner enough to spot "same device" between two rows
 * without giving anyone with a copy of the export a full rainbow-table
 * target on their own IP history.
 */
function ipHashPrefix(ipHash: string | null): string | null {
  return ipHash ? ipHash.slice(0, 8) : null;
}

export function createExportService(
  prisma: PrismaClient = defaultPrisma,
): ExportService {
  return {
    async exportUserData(userId) {
      // Fetch the user row first — a missing user here means the token
      // references a row that's been hard-purged. The controller already
      // rejects soft-deleted users up front; we still defend-in-depth.
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) throw new NotFoundError('User not found');

      // Fan out the per-model queries in parallel. Each is scoped to
      // `userId` — no cross-account leakage possible. The one exception
      // is the enrollments query, which joins to Course for the title
      // (we could emit the title separately, but the nested fetch keeps
      // the client-side contract simpler).
      const [
        enrollments,
        attempts,
        // We fetch cap+1 to detect truncation without a second COUNT.
        analyticsEvents,
        analyticsEventTotal,
        achievements,
        activeSessions,
        revokedSessions,
        ownedCoursesCount,
        collaboratorCoursesCount,
      ] = await Promise.all([
        prisma.enrollment.findMany({
          where: { userId },
          select: {
            id: true,
            courseId: true,
            startedAt: true,
            lastVideoId: true,
            lastPosMs: true,
            updatedAt: true,
            course: { select: { title: true } },
          },
          orderBy: { startedAt: 'asc' },
        }),
        prisma.attempt.findMany({
          where: { userId },
          select: {
            id: true,
            cueId: true,
            videoId: true,
            correct: true,
            scoreJson: true,
            submittedAt: true,
          },
          orderBy: { submittedAt: 'asc' },
        }),
        prisma.analyticsEvent.findMany({
          where: { userId },
          select: {
            id: true,
            eventType: true,
            videoId: true,
            cueId: true,
            payload: true,
            occurredAt: true,
            receivedAt: true,
          },
          orderBy: { occurredAt: 'desc' },
          take: ANALYTICS_EVENT_EXPORT_CAP,
        }),
        prisma.analyticsEvent.count({ where: { userId } }),
        prisma.userAchievement.findMany({
          where: { userId },
          select: {
            achievementId: true,
            unlockedAt: true,
            achievement: { select: { title: true } },
          },
          orderBy: { unlockedAt: 'asc' },
        }),
        prisma.session.findMany({
          where: { userId, revokedAt: null },
          select: {
            id: true,
            deviceLabel: true,
            ipHash: true,
            createdAt: true,
            lastSeenAt: true,
            revokedAt: true,
          },
          orderBy: { lastSeenAt: 'desc' },
        }),
        prisma.session.findMany({
          where: { userId, revokedAt: { not: null } },
          select: {
            id: true,
            deviceLabel: true,
            ipHash: true,
            createdAt: true,
            lastSeenAt: true,
            revokedAt: true,
          },
          orderBy: { revokedAt: 'desc' },
          take: REVOKED_SESSION_EXPORT_CAP,
        }),
        prisma.course.count({ where: { ownerId: userId } }),
        prisma.courseCollaborator.count({ where: { userId } }),
      ]);

      // Ordered: active first (matches the plan's "non-revoked first").
      const sessionsCombined = [...activeSessions, ...revokedSessions];

      return {
        schemaVersion: EXPORT_SCHEMA_VERSION,
        exportedAt: new Date().toISOString(),
        user: {
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          role: user.role,
          createdAt: user.createdAt.toISOString(),
          updatedAt: user.updatedAt.toISOString(),
          avatarKey: user.avatarKey,
          useGravatar: user.useGravatar,
          preferences: user.preferences ?? null,
          mfaEnabled: user.mfaEnabled,
          deletedAt: user.deletedAt?.toISOString() ?? null,
          deletionPurgeAt: user.deletionPurgeAt?.toISOString() ?? null,
          passwordChangedAt: user.passwordChangedAt?.toISOString() ?? null,
          // NOTE: passwordHash, mfaBackupCodes intentionally omitted.
        },
        enrollments: enrollments.map((e) => ({
          id: e.id,
          courseId: e.courseId,
          courseTitle: e.course.title,
          startedAt: e.startedAt.toISOString(),
          lastVideoId: e.lastVideoId,
          lastPosMs: e.lastPosMs,
          updatedAt: e.updatedAt.toISOString(),
        })),
        attempts: attempts.map((a) => ({
          id: a.id,
          cueId: a.cueId,
          videoId: a.videoId,
          correct: a.correct,
          scoreJson: a.scoreJson ?? null,
          submittedAt: a.submittedAt.toISOString(),
        })),
        analyticsEvents: analyticsEvents.map((ev) => ({
          id: ev.id,
          eventType: ev.eventType,
          videoId: ev.videoId,
          cueId: ev.cueId,
          payload: ev.payload ?? null,
          occurredAt: ev.occurredAt.toISOString(),
          receivedAt: ev.receivedAt.toISOString(),
        })),
        analyticsEventsTruncated: analyticsEventTotal > ANALYTICS_EVENT_EXPORT_CAP,
        achievements: achievements.map((u) => ({
          achievementId: u.achievementId,
          title: u.achievement.title,
          unlockedAt: u.unlockedAt.toISOString(),
        })),
        sessions: sessionsCombined.map((s) => ({
          id: s.id,
          deviceLabel: s.deviceLabel,
          ipHashPrefix: ipHashPrefix(s.ipHash),
          createdAt: s.createdAt.toISOString(),
          lastSeenAt: s.lastSeenAt.toISOString(),
          revokedAt: s.revokedAt?.toISOString() ?? null,
        })),
        ownedCoursesCount,
        collaboratorCoursesCount,
      };
    },
  };
}

export const exportService = createExportService();
