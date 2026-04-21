import type { PrismaClient } from '@prisma/client';
import jwt, { type SignOptions } from 'jsonwebtoken';
import { generateSecret, generateURI, verify } from 'otplib';
import * as qrcode from 'qrcode';
import { prisma as defaultPrisma } from '@/config/prisma';
import { env } from '@/config/env';
import { JWT_AUDIENCE } from '@/utils/jwt';
import {
  ConflictError,
  NotFoundError,
  UnauthorizedError,
} from '@/utils/errors';
import { requireCurrentPassword } from '@/utils/password';
import {
  encryptTotpSecret,
  decryptTotpSecret,
} from '@/services/mfa/crypto';
import {
  generateBackupCodes,
  verifyBackupCode,
} from '@/services/mfa/backup-codes';

/**
 * Slice P7a — MFA TOTP service.
 *
 * Flow summary:
 *  - `startEnrol` mints a fresh base32 secret + otpauth URI + QR data
 *    URL and hands back a short-lived (10 min) JWT whose payload holds
 *    the secret. The secret is NOT persisted yet: a user who abandons
 *    enrolment leaves nothing behind.
 *  - `confirmEnrol` verifies the pending JWT + the 6-digit code, then
 *    atomically:
 *      (a) writes an `MfaCredential(kind=TOTP)` row with the secret
 *          AES-256-GCM encrypted,
 *      (b) flips `User.mfaEnabled = true`,
 *      (c) hashes a fresh batch of backup codes and stores the hashes
 *          on `User.mfaBackupCodes`,
 *      (d) returns the plaintext codes to the caller ONCE.
 *  - `verify` / `verifyBackup` are the login-flow entry points; they
 *    decrypt the stored secret, run otplib with a ±1-step (30s) skew
 *    window, and burn a backup code on match.
 *  - `disable` requires current password + valid TOTP code, deletes the
 *    row, clears backup codes, and flips `mfaEnabled = false` — but
 *    ONLY if no other MFA rows exist. P7b's WebAuthn rows are checked
 *    here today (for zero at the moment) so the drop-in extension is
 *    a zero-change lift.
 *
 * Security invariants enforced at this layer (see tests for coverage):
 *  - Secret never leaves the process except inside the pending JWT (short
 *    TTL) or base32-encoded in the enrol start response (the client
 *    displays it exactly once during setup).
 *  - Skew window is ±30 seconds (one step). Any wider weakens the factor.
 *  - Backup codes are returned plaintext exactly once; they're burned on
 *    verify and can never be retrieved again.
 *  - Disable requires BOTH password and a current TOTP code — same
 *    re-auth posture as P5 destructive account operations.
 */

/**
 * Issuer label shown to authenticator apps. Defaults to
 * `env.MFA_TOTP_ISSUER` ("Lifestream Learn" in prod). Exported for
 * test injection.
 */
export function totpIssuer(): string {
  return env.MFA_TOTP_ISSUER;
}

/**
 * Kind tag on the pending JWT issued by `startEnrol`. Keeps this JWT
 * family disjoint from access / refresh tokens so a bug that lets
 * a caller swap them surfaces as a schema mismatch rather than a
 * silent acceptance.
 */
export const MFA_ENROL_JWT_KIND = 'mfa-enrol-totp';
/** Kind tag on the pending JWT issued by `authService.login` when MFA is enabled. */
export const MFA_LOGIN_JWT_KIND = 'mfa-pending';

/** TTL for the enrol pending token. 10 min is enough for a user to scan the QR. */
const ENROL_JWT_TTL = '10m';
/** TTL for the login pending token. 5 min — short so a stolen token has a narrow window. */
export const LOGIN_MFA_JWT_TTL = '5m';

/**
 * Skew tolerance on TOTP verify: ±1 step of 30 seconds. otplib's
 * `epochTolerance` is in seconds — NOT number of steps.
 */
const TOTP_EPOCH_TOLERANCE_SEC = 30;

export interface TotpStartEnrolResult {
  /** Base32 secret the user can hand-enter if they can't scan the QR. */
  secret: string;
  /** `data:image/png;base64,...` QR code of the otpauth URI. */
  qrDataUrl: string;
  /** `otpauth://totp/...` URI (same data encoded in the QR). */
  otpauthUrl: string;
  /** Short-lived JWT the client returns to `confirmEnrol` — holds the secret. */
  pendingEnrolmentToken: string;
}

export interface TotpConfirmEnrolInput {
  pendingToken: string;
  code: string;
  label?: string;
}

export interface TotpConfirmEnrolResult {
  backupCodes: string[];
}

export interface TotpDisableInput {
  currentPassword: string;
  code: string;
}

export interface MfaMethodsSummary {
  totp: boolean;
  webauthnCount: number;
  hasBackupCodes: boolean;
  backupCodesRemaining: number;
}

export interface LoginMfaChallenge {
  mfaPending: true;
  mfaToken: string;
  availableMethods: string[]; // e.g. ["totp", "backup"], P7b will append "webauthn"
}

export interface MfaTotpService {
  startEnrol(userId: string): Promise<TotpStartEnrolResult>;
  confirmEnrol(
    userId: string,
    input: TotpConfirmEnrolInput,
  ): Promise<TotpConfirmEnrolResult>;
  disable(userId: string, input: TotpDisableInput): Promise<void>;
  /**
   * Verify a live 6-digit TOTP code against the user's enrolled secret.
   * Returns true on match, false otherwise. Controllers should map
   * `false` to a generic 401 — the error shape for "bad code" and
   * "bogus mfaToken" must be indistinguishable to avoid account
   * enumeration on the login-MFA surface.
   */
  verify(userId: string, code: string): Promise<boolean>;
  verifyBackup(userId: string, code: string): Promise<boolean>;
  listMethods(userId: string): Promise<MfaMethodsSummary>;
  /**
   * Mint the short-lived pending-login token the auth service hands
   * back when a user with MFA enabled logs in with a correct password.
   * Exposed here so both `authService.login` and the integration tests
   * can produce one without duplicating the JWT payload shape.
   */
  mintLoginPendingToken(userId: string): string;
  /** Inverse of {@link mintLoginPendingToken}. Throws 401 on any failure. */
  verifyLoginPendingToken(token: string): { userId: string };
  /** Return the "availableMethods" list the login response advertises. */
  availableMethodsForUser(userId: string): Promise<string[]>;
}

function signEnrolToken(userId: string, secret: string): string {
  return jwt.sign(
    { sub: userId, kind: MFA_ENROL_JWT_KIND, secret },
    env.JWT_ACCESS_SECRET,
    {
      expiresIn: ENROL_JWT_TTL as SignOptions['expiresIn'],
      audience: JWT_AUDIENCE,
    },
  );
}

function verifyEnrolToken(token: string): { userId: string; secret: string } {
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, {
      audience: JWT_AUDIENCE,
    });
    if (
      !decoded ||
      typeof decoded !== 'object' ||
      (decoded as { kind?: unknown }).kind !== MFA_ENROL_JWT_KIND
    ) {
      throw new Error('wrong-kind');
    }
    const sub = (decoded as { sub?: unknown }).sub;
    const secret = (decoded as { secret?: unknown }).secret;
    if (typeof sub !== 'string' || typeof secret !== 'string') {
      throw new Error('malformed');
    }
    return { userId: sub, secret };
  } catch {
    throw new UnauthorizedError('Invalid or expired enrolment token');
  }
}

/**
 * Thin wrapper over `otplib.verify` that returns a plain boolean.
 * otplib in v13 is async (the default NobleCryptoPlugin only exposes
 * the async HMAC path) and returns `{ valid, delta, ... }`; we flatten
 * it here so callers don't leak the library's shape.
 *
 * Skew: `epochTolerance` is in SECONDS, not TOTP steps — 30s equals
 * ±1 step at the default 30-second period, which matches the plan's
 * "±1 step" requirement.
 */
async function verifyTotp(secret: string, code: string): Promise<boolean> {
  const result = await verify({
    secret,
    token: code,
    epochTolerance: TOTP_EPOCH_TOLERANCE_SEC,
  });
  return Boolean(result?.valid);
}

export function createMfaTotpService(
  prisma: PrismaClient = defaultPrisma,
): MfaTotpService {
  async function loadTotpCredential(
    userId: string,
  ): Promise<{ id: string; secret: string } | null> {
    const row = await prisma.mfaCredential.findFirst({
      where: { userId, kind: 'TOTP' },
      select: { id: true, totpSecretEncrypted: true },
    });
    if (!row || !row.totpSecretEncrypted) return null;
    try {
      return { id: row.id, secret: decryptTotpSecret(row.totpSecretEncrypted) };
    } catch {
      // A decrypt failure means either the encryption key rotated
      // without re-wrap, or the ciphertext is corrupt. Both cases are
      // "this credential is dead"; the caller should surface as 401.
      return null;
    }
  }

  return {
    async startEnrol(userId) {
      // Check the user exists; also short-circuits if they're already
      // enrolled so we don't waste entropy on a secret they can't save.
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, email: true, mfaCredentials: { where: { kind: 'TOTP' }, select: { id: true } } },
      });
      if (!user) throw new NotFoundError('User not found');
      if (user.mfaCredentials.length > 0) {
        throw new ConflictError('TOTP already enrolled — disable the existing factor first');
      }

      const secret = generateSecret();
      const otpauthUrl = generateURI({
        strategy: 'totp',
        issuer: env.MFA_TOTP_ISSUER,
        label: user.email,
        secret,
      });
      // 256×256 is enough for a phone camera scan inside a typical
      // enrolment modal. `toDataURL` returns a `data:image/png;base64,...`
      // string the client can feed straight into an Image widget.
      const qrDataUrl = await qrcode.toDataURL(otpauthUrl, {
        width: 256,
        margin: 1,
      });
      const pendingEnrolmentToken = signEnrolToken(user.id, secret);
      return { secret, qrDataUrl, otpauthUrl, pendingEnrolmentToken };
    },

    async confirmEnrol(userId, { pendingToken, code, label }) {
      const { userId: tokenUserId, secret } = verifyEnrolToken(pendingToken);
      if (tokenUserId !== userId) {
        // Pending tokens are user-scoped; an attacker mint from one
        // account and attempt to confirm against another is rejected.
        throw new UnauthorizedError('Invalid or expired enrolment token');
      }

      // Re-check idempotence. If another tab already confirmed, we
      // don't want to silently overwrite — 409 is the right answer.
      const existing = await prisma.mfaCredential.findFirst({
        where: { userId, kind: 'TOTP' },
        select: { id: true },
      });
      if (existing) {
        throw new ConflictError('TOTP already enrolled');
      }

      const ok = await verifyTotp(secret, code);
      if (!ok) {
        throw new UnauthorizedError('Invalid MFA code');
      }

      const { codes, hashes } = await generateBackupCodes();

      // Two writes (MfaCredential INSERT + User UPDATE) in a single
      // transaction so a crash between them never leaves the user
      // stranded with mfaEnabled=true but no credential row (or vice
      // versa — a stranded credential that can't verify).
      await prisma.$transaction([
        prisma.mfaCredential.create({
          data: {
            userId,
            kind: 'TOTP',
            label: label ?? null,
            totpSecretEncrypted: encryptTotpSecret(secret),
          },
        }),
        prisma.user.update({
          where: { id: userId },
          data: {
            mfaEnabled: true,
            mfaBackupCodes: hashes,
          },
        }),
      ]);

      return { backupCodes: codes };
    },

    async disable(userId, { currentPassword, code }) {
      // Constant-shape re-auth — see `requireCurrentPassword`'s doc for why.
      await requireCurrentPassword(prisma, userId, currentPassword);

      const cred = await loadTotpCredential(userId);
      if (!cred) {
        // Nothing to disable — treat as bad-code so the shape stays
        // constant. A user without TOTP hitting this endpoint is
        // either a bug in the client or an attacker probing.
        throw new UnauthorizedError('Invalid MFA code');
      }
      const ok = await verifyTotp(cred.secret, code);
      if (!ok) {
        throw new UnauthorizedError('Invalid MFA code');
      }

      // Drop the TOTP row. If a WebAuthn credential also exists (P7b)
      // we intentionally do NOT flip `mfaEnabled` off — the account
      // still has at least one factor. This check lives here today so
      // P7b's rollout is a pure additive change.
      await prisma.mfaCredential.delete({ where: { id: cred.id } });
      const remainingMfa = await prisma.mfaCredential.count({
        where: { userId, kind: { in: ['TOTP', 'WEBAUTHN'] } },
      });
      if (remainingMfa === 0) {
        await prisma.user.update({
          where: { id: userId },
          data: { mfaEnabled: false, mfaBackupCodes: [] },
        });
      }
    },

    async verify(userId, code) {
      const cred = await loadTotpCredential(userId);
      if (!cred) return false;
      const ok = await verifyTotp(cred.secret, code);
      if (ok) {
        // Bookkeeping — lets the profile UI show "last used X" and
        // helps an operator spot a stolen authenticator.
        await prisma.mfaCredential.update({
          where: { id: cred.id },
          data: { lastUsedAt: new Date() },
        });
      }
      return ok;
    },

    async verifyBackup(userId, code) {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { mfaBackupCodes: true },
      });
      if (!user) return false;
      const { matched, remainingHashes } = await verifyBackupCode(
        code,
        user.mfaBackupCodes,
      );
      if (!matched) return false;
      await prisma.user.update({
        where: { id: userId },
        data: { mfaBackupCodes: remainingHashes },
      });
      return true;
    },

    async listMethods(userId) {
      const [user, totp, webauthnCount] = await Promise.all([
        prisma.user.findUnique({
          where: { id: userId },
          select: { mfaBackupCodes: true },
        }),
        prisma.mfaCredential.findFirst({
          where: { userId, kind: 'TOTP' },
          select: { id: true },
        }),
        prisma.mfaCredential.count({
          where: { userId, kind: 'WEBAUTHN' },
        }),
      ]);
      const codes = user?.mfaBackupCodes ?? [];
      return {
        totp: !!totp,
        webauthnCount,
        hasBackupCodes: codes.length > 0,
        backupCodesRemaining: codes.length,
      };
    },

    mintLoginPendingToken(userId) {
      return jwt.sign(
        { sub: userId, kind: MFA_LOGIN_JWT_KIND },
        env.JWT_ACCESS_SECRET,
        {
          expiresIn: LOGIN_MFA_JWT_TTL as SignOptions['expiresIn'],
          audience: JWT_AUDIENCE,
        },
      );
    },

    verifyLoginPendingToken(token) {
      try {
        const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, {
          audience: JWT_AUDIENCE,
        });
        if (
          !decoded ||
          typeof decoded !== 'object' ||
          (decoded as { kind?: unknown }).kind !== MFA_LOGIN_JWT_KIND
        ) {
          throw new Error('wrong-kind');
        }
        const sub = (decoded as { sub?: unknown }).sub;
        if (typeof sub !== 'string') {
          throw new Error('malformed');
        }
        return { userId: sub };
      } catch {
        // Generic 401 — caller MUST NOT distinguish "bad token" from
        // "bad code" per the plan's account-enumeration guardrail.
        throw new UnauthorizedError('Invalid MFA code');
      }
    },

    async availableMethodsForUser(userId) {
      const methods: string[] = [];
      const [totp, webauthn, user] = await Promise.all([
        prisma.mfaCredential.findFirst({
          where: { userId, kind: 'TOTP' },
          select: { id: true },
        }),
        // Slice P7b — advertise webauthn whenever at least one
        // credential exists. The login flow reads this list to decide
        // which second-step endpoints to expose on the challenge UI.
        prisma.mfaCredential.findFirst({
          where: { userId, kind: 'WEBAUTHN' },
          select: { id: true },
        }),
        prisma.user.findUnique({
          where: { id: userId },
          select: { mfaBackupCodes: true },
        }),
      ]);
      if (totp) methods.push('totp');
      if (webauthn) methods.push('webauthn');
      if ((user?.mfaBackupCodes.length ?? 0) > 0) methods.push('backup');
      return methods;
    },
  };
}

export const mfaTotpService = createMfaTotpService();
