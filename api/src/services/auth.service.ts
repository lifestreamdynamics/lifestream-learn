import { Prisma, type PrismaClient, type User } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { hashPassword, verifyPassword } from '@/utils/password';
import { signAccessToken, signRefreshToken } from '@/utils/jwt';
import { ConflictError, UnauthorizedError } from '@/utils/errors';
import { tryRevokeRefreshJti } from '@/services/refresh-token-store';
import {
  sessionService as defaultSessionService,
  SessionInvalidError,
  type RequestContext,
  type SessionService,
} from '@/services/session.service';
import {
  mfaTotpService as defaultMfaTotpService,
  type MfaTotpService,
} from '@/services/mfa-totp.service';

// Dummy hash used when the user lookup misses, so bcrypt runs in both paths
// and login latency can't be used to distinguish "no such user" from "wrong
// password". Computed lazily at first miss.
let DUMMY_HASH: string | undefined;
async function getDummyHash(): Promise<string> {
  if (!DUMMY_HASH) DUMMY_HASH = await hashPassword('not-a-real-password-placeholder');
  return DUMMY_HASH;
}

export interface PublicUser {
  id: string;
  email: string;
  role: User['role'];
  displayName: string;
  createdAt: Date;
  // Slice P1 — profile-screen fields that refresh through `/api/auth/me`
  // so a client reloading its session sees the up-to-date avatar /
  // preferences without a second round-trip.
  avatarKey: string | null;
  useGravatar: boolean;
  preferences: unknown;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

/**
 * Slice P7a — login step-up.
 *
 * When a user with `mfaEnabled == true` presents correct credentials,
 * the login endpoint does NOT return access/refresh tokens; instead it
 * returns a short-lived `mfaToken` (signed JWT, 5 min, kind=mfa-pending)
 * plus the list of MFA methods the client can use to complete the
 * challenge (currently `["totp", "backup"]`; P7b will append `"webauthn"`).
 * The client then hits `/api/auth/login/mfa/totp` (or `/backup`) to
 * exchange `{ mfaToken, code }` for the real token pair.
 */
export interface LoginMfaChallengeResponse {
  mfaPending: true;
  mfaToken: string;
  availableMethods: string[];
}

/**
 * Discriminated result: either a normal login (tokens + user) or an
 * MFA challenge. Controllers map the discriminator to the HTTP shape.
 */
export type LoginResult =
  | ({ mfaPending?: false; user: PublicUser } & AuthTokens)
  | LoginMfaChallengeResponse;

export interface AuthService {
  signup(input: {
    email: string;
    password: string;
    displayName: string;
    ctx?: RequestContext;
  }): Promise<{ user: PublicUser } & AuthTokens>;
  login(input: {
    email: string;
    password: string;
    ctx?: RequestContext;
  }): Promise<LoginResult>;
  /**
   * Slice P7a — second-step completion of an MFA-gated login. Called
   * by the `/api/auth/login/mfa/totp` and `/backup` endpoints after the
   * user presents a matching code. Mints tokens via the same
   * `issueTokensWithSession` seam as a normal login so User-Agent
   * parsing + Session minting + Redis sid claim all stay in lockstep.
   */
  completeMfaLogin(input: {
    userId: string;
    ctx?: RequestContext;
  }): Promise<{ user: PublicUser } & AuthTokens>;
  /**
   * Rotate a refresh token. The old `jti` is moved to the revocation set
   * so a second attempt with the same token fails even before the TTL
   * expires. Caller must have already verified the refresh token's
   * signature+audience before calling.
   *
   * Slice P5: `oldIat` (the refresh token's `iat` claim, in seconds
   * since epoch) is compared against the user's `passwordChangedAt`.
   * Tokens issued before the last password-change (or account delete)
   * are rejected — this is how we invalidate all refresh tokens on a
   * password change without a per-session Session table.
   *
   * Slice P6: after the iat/deletion gates pass, we also look up the
   * `Session` row by the old `jti`. A missing or already-revoked row
   * is a 401 — belt-and-braces with the Redis revocation set and the
   * source of truth for "user revoked this device from elsewhere".
   */
  refresh(input: {
    userId: string;
    oldJti: string;
    oldIat?: number;
    ctx?: RequestContext;
  }): Promise<AuthTokens>;
  findById(id: string): Promise<PublicUser>;
}

function toPublic(u: User): PublicUser {
  return {
    id: u.id,
    email: u.email,
    role: u.role,
    displayName: u.displayName,
    createdAt: u.createdAt,
    avatarKey: u.avatarKey,
    useGravatar: u.useGravatar,
    // `preferences` is `Prisma.JsonValue | null` at the Prisma layer; we
    // export it as `unknown` so downstream consumers don't import Prisma
    // types just to match the shape.
    preferences: u.preferences ?? null,
  };
}

/**
 * Slice P6 — every signup / login / refresh mints both tokens AND the
 * corresponding Session row in a single seam so the two can never drift.
 * The session id ends up inside the access token as the `sid` claim so
 * the sessions controller can flag the caller's own device as `current`.
 */
async function issueTokensWithSession(
  sessions: SessionService,
  user: User,
  ctx: RequestContext | undefined,
): Promise<AuthTokens> {
  const { token: refreshToken, jti } = signRefreshToken(user);
  const { id: sessionId } = await sessions.createSession(
    user.id,
    jti,
    ctx ?? {},
  );
  return { accessToken: signAccessToken(user, sessionId), refreshToken };
}

export function createAuthService(
  prisma: PrismaClient = defaultPrisma,
  sessions: SessionService = defaultSessionService,
  mfaTotp: MfaTotpService = defaultMfaTotpService,
): AuthService {
  return {
    async signup({ email, password, displayName, ctx }) {
      const passwordHash = await hashPassword(password);
      try {
        const user = await prisma.user.create({
          data: { email, passwordHash, displayName, role: 'LEARNER' },
        });
        const tokens = await issueTokensWithSession(sessions, user, ctx);
        return { user: toPublic(user), ...tokens };
      } catch (err) {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          throw new ConflictError('Email already registered');
        }
        throw err;
      }
    },

    async login({ email, password, ctx }) {
      const user = await prisma.user.findUnique({ where: { email } });
      // Always run bcrypt so the response time doesn't leak whether the email
      // exists: a missing user is compared against a dummy hash and the final
      // decision is gated on both the lookup result and the hash match.
      const hash = user?.passwordHash ?? (await getDummyHash());
      const passwordMatches = await verifyPassword(password, hash);
      // Slice P5: soft-deleted accounts reject with the SAME generic
      // "Invalid credentials" message as wrong-password, to avoid account
      // enumeration on the login surface.
      if (!user || !passwordMatches || user.deletedAt != null) {
        throw new UnauthorizedError('Invalid credentials');
      }
      // Slice P7a — step-up for MFA-enabled users. We verified the
      // password, but we do NOT mint tokens or a Session row yet; the
      // client must complete the challenge via
      // `/api/auth/login/mfa/{totp|backup}` to receive real credentials.
      // `mfaToken` is a short-lived (5 min) JWT whose only job is to
      // bind the second step to this specific user+login attempt.
      if (user.mfaEnabled) {
        const mfaToken = mfaTotp.mintLoginPendingToken(user.id);
        const availableMethods = await mfaTotp.availableMethodsForUser(user.id);
        return {
          mfaPending: true,
          mfaToken,
          availableMethods,
        };
      }
      // Slice P6: multiple devices are legitimate — do NOT revoke
      // existing sessions on a fresh login. Each login mints a new
      // Session row alongside the tokens.
      const tokens = await issueTokensWithSession(sessions, user, ctx);
      return { user: toPublic(user), ...tokens };
    },

    async completeMfaLogin({ userId, ctx }) {
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user || user.deletedAt != null) {
        // Keeps the error shape aligned with bad-code — no leakage of
        // "this user was deleted between mfaToken mint and completion".
        throw new UnauthorizedError('Invalid MFA code');
      }
      const tokens = await issueTokensWithSession(sessions, user, ctx);
      return { user: toPublic(user), ...tokens };
    },

    async refresh({ userId, oldJti, oldIat, ctx }) {
      // Atomic revoke: only the first caller with this jti wins the
      // SET NX and gets fresh tokens. A concurrent replay (or an
      // attacker racing a stolen token with the legitimate user)
      // loses the race and hits 401. This is the only correct way to
      // implement rotation — a separate `isRevoked → revoke` sequence
      // is a TOCTOU that lets both callers succeed.
      const claimed = await tryRevokeRefreshJti(oldJti);
      if (!claimed) {
        throw new UnauthorizedError('Invalid or expired token');
      }
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) throw new UnauthorizedError('Invalid or expired token');

      // Slice P5 — two cross-cutting security gates at refresh time.
      // Both yield the same 401 message as a plain "expired token" so
      // we don't leak *why* the session was invalidated.
      //
      // 1. Deleted accounts: the soft-delete path sets `deletedAt`; any
      //    lingering client that tries to refresh is demoted to logged-out.
      //    Access tokens remain valid up to 15 minutes after delete — this
      //    is the industry-standard grace window (Google, GitHub) and is
      //    an acceptable trade-off because the user just deleted their
      //    own account.
      //
      // 2. Stale iat: the password-change path bumps `passwordChangedAt`.
      //    Any refresh token whose `iat` is strictly earlier than that
      //    timestamp is from a pre-change session and gets rejected. We
      //    compare in seconds (JWT `iat` is seconds; `passwordChangedAt`
      //    is a JS Date in ms — convert with `Math.floor(... / 1000)`).
      if (user.deletedAt != null) {
        throw new UnauthorizedError('Invalid or expired token');
      }
      if (user.passwordChangedAt != null && oldIat != null) {
        // JWT `iat` has seconds granularity; `passwordChangedAt` is
        // millisecond-precision. Using `<=` (not `<`) closes the
        // same-second window: a refresh token minted in the same clock
        // second as the password change is still rejected. In practice
        // this can happen when a test logs in and immediately changes
        // the password; in production, it's a narrow sliver but still
        // worth closing so a token issued "just before" a change can't
        // be used "just after".
        const pwChangedAtSec = Math.floor(user.passwordChangedAt.getTime() / 1000);
        if (oldIat <= pwChangedAtSec) {
          throw new UnauthorizedError('Invalid or expired token');
        }
      }

      // Slice P6 — mint the new refresh token, then atomically rotate
      // the Session row: mark the old one revoked and create a fresh
      // row keyed by the new jti. If the old session row is missing or
      // already revoked (user signed out from another device between
      // the Redis claim above and now), the refresh is rejected.
      const { token: refreshToken, jti: newJti } = signRefreshToken(user);
      let sessionId: string;
      try {
        const rotated = await sessions.rotate(
          user.id,
          oldJti,
          newJti,
          ctx ?? {},
        );
        sessionId = rotated.id;
      } catch (e) {
        if (e instanceof SessionInvalidError) {
          throw new UnauthorizedError('Invalid or expired token');
        }
        throw e;
      }
      return {
        accessToken: signAccessToken(user, sessionId),
        refreshToken,
      };
    },

    async findById(id) {
      const user = await prisma.user.findUnique({ where: { id } });
      if (!user) throw new UnauthorizedError('Invalid or expired token');
      return toPublic(user);
    },
  };
}

export const authService = createAuthService();
