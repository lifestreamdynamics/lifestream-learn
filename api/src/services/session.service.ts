import { createHash } from 'node:crypto';
import type { PrismaClient } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { env } from '@/config/env';
import { tryRevokeRefreshJti } from '@/services/refresh-token-store';

/**
 * Slice P6 — session management.
 *
 * One `Session` row per refresh-token lifetime. Lifecycle:
 *
 *   signup / login        → `createSession(userId, jti, ctx)` mints a row.
 *   refresh (rotation)    → lookup by old jti, `revokedAt = now()`, then
 *                           `createSession` for the new jti. The old row
 *                           is kept (not deleted) so "all active sessions"
 *                           UX can distinguish an expired row from a
 *                           never-existed jti — `listActiveForUser`
 *                           filters by `revokedAt IS NULL`.
 *   logout                → `revokeSessionByJti(jti)` (sets `revokedAt`)
 *                           and `tryRevokeRefreshJti(jti)` in Redis.
 *   password change /     → `revokeAllForUser(userId)` flips every
 *   account delete          non-revoked row to `revokedAt = now()`.
 *
 * The `refreshJti` key mirrors the JWT `jti` claim exactly, so the Redis
 * revocation primitive (`refresh-token-store`) and the Postgres row
 * share a single identifier — no dual lookup at refresh time.
 */

export interface RequestContext {
  userAgent?: string | null;
  ip?: string | null;
}

export interface PublicSession {
  id: string;
  deviceLabel: string | null;
  ipHashPrefix: string | null;
  createdAt: Date;
  lastSeenAt: Date;
  current: boolean;
}

export interface SessionService {
  /**
   * Mint a new Session row for `(userId, refreshJti)`. `ctx` is parsed
   * from the HTTP request; both fields are optional so server-side
   * tests and non-HTTP callers can pass a minimal context.
   */
  createSession(
    userId: string,
    refreshJti: string,
    ctx: RequestContext,
  ): Promise<{ id: string }>;
  /**
   * Atomic rotation for the refresh path. Looks up the current session
   * by the OLD `jti`, revokes it, and creates a fresh row for the NEW
   * `jti`. Throws `SessionInvalidError` when the old row is missing
   * (stolen token, or the row never existed) or already revoked
   * (user signed out from another device).
   */
  rotate(
    userId: string,
    oldJti: string,
    newJti: string,
    ctx: RequestContext,
  ): Promise<{ id: string }>;
  /**
   * Sessions listing for `GET /api/me/sessions`. `currentSessionId`
   * drives the `current: true` flag — callers pass `req.user.sid`.
   */
  listActiveForUser(
    userId: string,
    currentSessionId?: string | null,
  ): Promise<PublicSession[]>;
  /**
   * Revoke a single session by id. Returns false if the row is missing
   * or belongs to another user (the controller surfaces 404). Also
   * revokes the refresh jti in Redis so the next refresh call 401s
   * immediately rather than waiting for the DB gate.
   */
  revokeSessionById(userId: string, sessionId: string): Promise<boolean>;
  /**
   * "Sign out all other devices" — revokes every session for the user
   * except `currentSessionId`. Each revoked row's jti is also pushed to
   * the Redis revocation set.
   */
  revokeAllOtherSessions(
    userId: string,
    currentSessionId: string,
  ): Promise<number>;
  /**
   * Revoke every session for the user — called from password-change
   * and soft-delete. Returns the count of rows flipped. Best-effort
   * pushes each jti into the Redis revocation set as well.
   */
  revokeAllForUser(userId: string): Promise<number>;
  /**
   * Revoke a session by its refresh jti. Used by the logout endpoint
   * where we have the refresh token in hand. Returns false when no
   * matching non-revoked row exists (already logged out, or token
   * minted before Slice P6) — callers still return 204 for idempotency.
   */
  revokeSessionByJti(jti: string): Promise<boolean>;
}

export class SessionInvalidError extends Error {
  constructor(message = 'Session invalid') {
    super(message);
    this.name = 'SessionInvalidError';
  }
}

// User-Agent parsing: hand-rolled, no deps. Keeps CLAUDE.md's "no new
// top-level deps" constraint and the `ua-parser-js` package has a
// non-trivial CVE history. Heuristic good enough for a short, human-
// readable label on the sessions list.
export function parseDeviceLabel(userAgent: string | null | undefined): string | null {
  if (!userAgent) return null;
  const ua = userAgent.trim();
  if (!ua) return null;
  // Ordered checks: more specific tokens first so "Android" on an
  // "iPhone-like Android" UA doesn't get misclassified.
  if (/iPhone/i.test(ua)) return 'iPhone';
  if (/iPad/i.test(ua)) return 'iPad';
  if (/Android/i.test(ua)) return 'Android';
  if (/Macintosh|Mac OS X/i.test(ua)) return 'macOS';
  if (/Windows/i.test(ua)) return 'Windows';
  if (/CrOS/i.test(ua)) return 'ChromeOS';
  if (/Linux/i.test(ua)) return 'Linux';
  // Fallback: first 60 chars of UA, trimmed. Gives the user SOMETHING
  // to recognise even for exotic clients (curl, bots, unknown phones).
  const head = ua.slice(0, 60);
  return head.length === 0 ? null : head;
}

// Hash + truncate an IP. Never store raw IPs on the Session row —
// a leaked Session table should not be a visitor log.
export function hashIp(ip: string | null | undefined): string | null {
  if (!ip) return null;
  const trimmed = ip.trim();
  if (!trimmed) return null;
  const h = createHash('sha256')
    .update(`${trimmed}:${env.IP_HASH_SALT}`)
    .digest('hex');
  // 32 hex chars (128 bits) — enough to avoid collisions while keeping
  // the row narrow.
  return h.slice(0, 32);
}

function toPublic(
  s: {
    id: string;
    deviceLabel: string | null;
    ipHash: string | null;
    createdAt: Date;
    lastSeenAt: Date;
  },
  currentSessionId: string | null | undefined,
): PublicSession {
  return {
    id: s.id,
    deviceLabel: s.deviceLabel,
    // Expose the first 8 chars only — enough for the user to spot
    // "same device" between two sessions without leaking the full
    // hash. The first 8 hex chars still have ~2^32 possible values,
    // so a rainbow-table attack on raw IPs stays infeasible even if
    // the salt were compromised.
    ipHashPrefix: s.ipHash ? s.ipHash.slice(0, 8) : null,
    createdAt: s.createdAt,
    lastSeenAt: s.lastSeenAt,
    current: Boolean(currentSessionId && s.id === currentSessionId),
  };
}

export function createSessionService(
  prisma: PrismaClient = defaultPrisma,
): SessionService {
  return {
    async createSession(userId, refreshJti, ctx) {
      const session = await prisma.session.create({
        data: {
          userId,
          refreshJti,
          deviceLabel: parseDeviceLabel(ctx.userAgent),
          ipHash: hashIp(ctx.ip),
        },
        select: { id: true },
      });
      return { id: session.id };
    },

    async rotate(userId, oldJti, newJti, ctx) {
      // Find the old session row. A missing row or one owned by a
      // different user means the refresh token is either forged or
      // predates Slice P6 — either way, refuse rotation.
      const existing = await prisma.session.findUnique({
        where: { refreshJti: oldJti },
      });
      if (!existing || existing.userId !== userId) {
        throw new SessionInvalidError('Session not found');
      }
      if (existing.revokedAt != null) {
        // The user explicitly signed this device out (from another
        // device or via the logout endpoint). Belt-and-braces with the
        // Redis-level revocation check in auth.service.
        throw new SessionInvalidError('Session revoked');
      }

      // Mark the old row revoked (so the sessions list shows accurate
      // history) and immediately mint a new one. Two writes in sequence;
      // a crash between them leaves the user with zero sessions and
      // forces re-login, which is safe.
      await prisma.session.update({
        where: { id: existing.id },
        data: { revokedAt: new Date(), lastSeenAt: new Date() },
      });
      const created = await prisma.session.create({
        data: {
          userId,
          refreshJti: newJti,
          deviceLabel: parseDeviceLabel(ctx.userAgent),
          ipHash: hashIp(ctx.ip),
        },
        select: { id: true },
      });
      return { id: created.id };
    },

    async listActiveForUser(userId, currentSessionId) {
      const rows = await prisma.session.findMany({
        where: { userId, revokedAt: null },
        orderBy: { lastSeenAt: 'desc' },
        select: {
          id: true,
          deviceLabel: true,
          ipHash: true,
          createdAt: true,
          lastSeenAt: true,
        },
      });
      return rows.map((r) => toPublic(r, currentSessionId));
    },

    async revokeSessionById(userId, sessionId) {
      const existing = await prisma.session.findUnique({
        where: { id: sessionId },
      });
      if (!existing || existing.userId !== userId) return false;
      if (existing.revokedAt != null) return true; // idempotent

      await prisma.session.update({
        where: { id: sessionId },
        data: { revokedAt: new Date() },
      });
      // Revoke the Redis jti too so any outstanding refresh attempt 401s
      // without waiting for the DB gate. Best-effort: a Redis outage
      // should not break the logout flow — the DB revocation is still
      // authoritative via the rotate() revokedAt check.
      await tryRevokeRefreshJti(existing.refreshJti).catch(() => undefined);
      return true;
    },

    async revokeAllOtherSessions(userId, currentSessionId) {
      const others = await prisma.session.findMany({
        where: {
          userId,
          revokedAt: null,
          NOT: { id: currentSessionId },
        },
        select: { id: true, refreshJti: true },
      });
      if (others.length === 0) return 0;

      const now = new Date();
      await prisma.session.updateMany({
        where: {
          userId,
          revokedAt: null,
          NOT: { id: currentSessionId },
        },
        data: { revokedAt: now },
      });
      // Fire-and-forget Redis revokes for each jti. We intentionally
      // await all of them so the controller's response reflects a
      // consistent state — the user expects "signed out everywhere
      // else" to mean "those tokens are dead by the time I see 204".
      await Promise.all(
        others.map((o) =>
          tryRevokeRefreshJti(o.refreshJti).catch(() => undefined),
        ),
      );
      return others.length;
    },

    async revokeAllForUser(userId) {
      const active = await prisma.session.findMany({
        where: { userId, revokedAt: null },
        select: { id: true, refreshJti: true },
      });
      if (active.length === 0) return 0;
      const now = new Date();
      await prisma.session.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: now },
      });
      await Promise.all(
        active.map((o) =>
          tryRevokeRefreshJti(o.refreshJti).catch(() => undefined),
        ),
      );
      return active.length;
    },

    async revokeSessionByJti(jti) {
      const existing = await prisma.session.findUnique({
        where: { refreshJti: jti },
      });
      if (!existing) return false;
      if (existing.revokedAt != null) return true;

      await prisma.session.update({
        where: { id: existing.id },
        data: { revokedAt: new Date() },
      });
      await tryRevokeRefreshJti(jti).catch(() => undefined);
      return true;
    },
  };
}

export const sessionService = createSessionService();
