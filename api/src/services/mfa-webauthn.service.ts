import type { PrismaClient } from '@prisma/client';
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} from '@simplewebauthn/server';
import type {
  PublicKeyCredentialCreationOptionsJSON,
  PublicKeyCredentialRequestOptionsJSON,
  RegistrationResponseJSON,
  AuthenticationResponseJSON,
  AuthenticatorTransportFuture,
} from '@simplewebauthn/server';
import jwt, { type SignOptions } from 'jsonwebtoken';
import { Prisma } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { env } from '@/config/env';
import { JWT_AUDIENCE } from '@/utils/jwt';
import { logger } from '@/config/logger';
import {
  ConflictError,
  NotFoundError,
  UnauthorizedError,
} from '@/utils/errors';
import { requireCurrentPassword } from '@/utils/password';
import { generateBackupCodes } from '@/services/mfa/backup-codes';

/**
 * Slice P7b — MFA WebAuthn (passkeys) service.
 *
 * Mirrors the shape of `mfa-totp.service.ts`: factory + singleton, with
 * start/verify pairs for both registration (enrol a new credential)
 * and authentication (login-time challenge). Challenge nonces live in
 * short-lived JWTs rather than Redis — they're single-use, bound to a
 * specific user via the `sub` claim, and the 5-minute TTL matches the
 * P7a login pending-token window.
 *
 * Security invariants enforced at this layer (see tests for coverage):
 *  - Challenge nonce is never reusable: the JWT `jti` claim makes each
 *    challenge token uniquely identifiable, and `verify*Response` binds
 *    it to the `clientDataJSON` the authenticator returns.
 *  - Sign-count regression is a hard reject. If the verifier reports
 *    `newCounter <= stored` (and either side > 0), we log a warning and
 *    throw 401 — a regression is the WebAuthn spec's "cloned authenticator"
 *    signal. The stored counter is NOT updated on reject so legitimate
 *    re-use of a fresh authenticator still works.
 *  - `userVerification: 'preferred'` (not `'required'`) so a Pixel that
 *    has a lock-screen PIN but no enrolled biometric can still register.
 *  - Duplicate credential IDs at registration → 409. Never silently
 *    clobber an existing row.
 *
 * Challenge-as-JWT: `generateRegistrationOptions` / `generateAuthenticationOptions`
 * return a base64url-encoded challenge that the client must send back inside
 * `clientDataJSON`. We embed the SAME challenge string in a signed JWT
 * ("pendingToken" / "challengeToken") with a 5-minute TTL, and verify
 * the response against the challenge carried inside that JWT. Storing
 * the challenge server-side (Redis) would work too, but JWT keeps the
 * store stateless — and P7a already uses `JWT_ACCESS_SECRET` for a
 * similar `mfa-pending` pattern.
 */

export const MFA_WEBAUTHN_REG_JWT_KIND = 'mfa-enrol-webauthn';
export const MFA_WEBAUTHN_AUTH_JWT_KIND = 'mfa-auth-webauthn';

/** TTL for reg + auth challenge tokens. 5 min matches the P7a login pending token. */
const CHALLENGE_JWT_TTL = '5m';

/**
 * User verification policy. `'preferred'` lets authenticators without
 * biometrics (e.g. a Pixel with a PIN-only lock screen) still complete
 * the ceremony — the operator's trade-off is "nudge biometrics, accept
 * PIN" rather than "biometric or bust". Flip to `'required'` if the
 * deployment's threat model demands it, but be ready for users with
 * hardware security keys that can't assert UV to fail.
 */
const USER_VERIFICATION = 'preferred' as const;

export interface WebauthnCredentialSummary {
  id: string;
  credentialId: string;
  label: string | null;
  createdAt: Date;
  lastUsedAt: Date | null;
  transports: string[];
  aaguid: string | null;
}

export interface WebauthnRegistrationStart {
  options: PublicKeyCredentialCreationOptionsJSON;
  pendingToken: string;
}

export interface WebauthnAuthenticationStart {
  options: PublicKeyCredentialRequestOptionsJSON;
  challengeToken: string;
}

export interface WebauthnRegistrationVerifyInput {
  pendingToken: string;
  attestationResponse: RegistrationResponseJSON;
  label?: string;
}

export interface WebauthnRegistrationVerifyResult {
  credentialId: string;
  /**
   * Backup codes are minted ONCE — on the first MFA factor enrolment. If
   * TOTP was already enabled (and thus backup codes already issued),
   * this is `undefined`. Controllers relay only when present.
   */
  backupCodes?: string[];
}

export interface WebauthnAuthenticationVerifyInput {
  challengeToken: string;
  assertionResponse: AuthenticationResponseJSON;
}

export interface WebauthnDeleteInput {
  currentPassword: string;
}

export interface MfaWebauthnService {
  startRegistration(userId: string): Promise<WebauthnRegistrationStart>;
  verifyRegistration(
    userId: string,
    input: WebauthnRegistrationVerifyInput,
  ): Promise<WebauthnRegistrationVerifyResult>;
  listCredentials(userId: string): Promise<WebauthnCredentialSummary[]>;
  deleteCredential(
    userId: string,
    credentialId: string,
    input: WebauthnDeleteInput,
  ): Promise<void>;
  startAuthentication(userId: string): Promise<WebauthnAuthenticationStart>;
  /**
   * Returns `true` on success (counter updated + lastUsedAt bumped).
   * Throws `UnauthorizedError` on sign-count regression (possible cloned
   * authenticator) so callers can distinguish "wrong credential" (false)
   * from "actively suspicious" (throw). Callers mapping both to 401 get
   * the right UX — only log/metrics consumers need to tell the two apart.
   */
  verifyAuthentication(
    userId: string,
    input: WebauthnAuthenticationVerifyInput,
  ): Promise<boolean>;
}

interface RegistrationJwtPayload {
  sub: string;
  kind: typeof MFA_WEBAUTHN_REG_JWT_KIND;
  challenge: string;
}

interface AuthenticationJwtPayload {
  sub: string;
  kind: typeof MFA_WEBAUTHN_AUTH_JWT_KIND;
  challenge: string;
}

function signRegistrationToken(userId: string, challenge: string): string {
  return jwt.sign(
    { sub: userId, kind: MFA_WEBAUTHN_REG_JWT_KIND, challenge },
    env.JWT_ACCESS_SECRET,
    {
      expiresIn: CHALLENGE_JWT_TTL as SignOptions['expiresIn'],
      audience: JWT_AUDIENCE,
      jwtid: challenge, // binds jti to the challenge so a replayed JWT is self-evident.
    },
  );
}

function verifyRegistrationToken(token: string): RegistrationJwtPayload {
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, {
      audience: JWT_AUDIENCE,
    });
    if (
      !decoded ||
      typeof decoded !== 'object' ||
      (decoded as { kind?: unknown }).kind !== MFA_WEBAUTHN_REG_JWT_KIND
    ) {
      throw new Error('wrong-kind');
    }
    const sub = (decoded as { sub?: unknown }).sub;
    const challenge = (decoded as { challenge?: unknown }).challenge;
    if (typeof sub !== 'string' || typeof challenge !== 'string') {
      throw new Error('malformed');
    }
    return { sub, kind: MFA_WEBAUTHN_REG_JWT_KIND, challenge };
  } catch {
    throw new UnauthorizedError('Invalid or expired enrolment token');
  }
}

function signAuthenticationToken(userId: string, challenge: string): string {
  return jwt.sign(
    { sub: userId, kind: MFA_WEBAUTHN_AUTH_JWT_KIND, challenge },
    env.JWT_ACCESS_SECRET,
    {
      expiresIn: CHALLENGE_JWT_TTL as SignOptions['expiresIn'],
      audience: JWT_AUDIENCE,
      jwtid: challenge,
    },
  );
}

function verifyAuthenticationToken(token: string): AuthenticationJwtPayload {
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, {
      audience: JWT_AUDIENCE,
    });
    if (
      !decoded ||
      typeof decoded !== 'object' ||
      (decoded as { kind?: unknown }).kind !== MFA_WEBAUTHN_AUTH_JWT_KIND
    ) {
      throw new Error('wrong-kind');
    }
    const sub = (decoded as { sub?: unknown }).sub;
    const challenge = (decoded as { challenge?: unknown }).challenge;
    if (typeof sub !== 'string' || typeof challenge !== 'string') {
      throw new Error('malformed');
    }
    return { sub, kind: MFA_WEBAUTHN_AUTH_JWT_KIND, challenge };
  } catch {
    // Same generic 401 shape as the TOTP verify path — callers must
    // not distinguish "bogus token" from "bad assertion" on the login
    // surface or an attacker can enumerate `availableMethods`.
    throw new UnauthorizedError('Invalid MFA assertion');
  }
}

/**
 * Base64URL-encode any byte sequence. Prisma 7 hands BYTEA columns back
 * as `Uint8Array`, not Node `Buffer`, so we accept the wider type and
 * normalise inside.
 *
 * The WebAuthn spec uses base64url (no padding) for credential IDs
 * and challenges; Node's built-in `.toString('base64url')` already
 * omits padding.
 */
function toB64Url(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString('base64url');
}

/**
 * Base64URL-decode to a `Uint8Array<ArrayBuffer>`. Prisma 7's generated
 * types pin `Bytes` columns to that narrower shape (it refuses a
 * `Uint8Array<SharedArrayBuffer>`), so we build one manually from a
 * freshly-allocated ArrayBuffer.
 */
function fromB64Url(s: string): Uint8Array<ArrayBuffer> {
  const buf = Buffer.from(s, 'base64url');
  const ab = new ArrayBuffer(buf.byteLength);
  new Uint8Array(ab).set(buf);
  return new Uint8Array(ab);
}

export function createMfaWebauthnService(
  prisma: PrismaClient = defaultPrisma,
): MfaWebauthnService {
  return {
    async startRegistration(userId) {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          email: true,
          displayName: true,
          mfaCredentials: {
            where: { kind: 'WEBAUTHN' },
            select: { credentialId: true, transports: true },
          },
        },
      });
      if (!user || !user.id) throw new NotFoundError('User not found');

      // Exclude already-registered credentials so the browser / Credential
      // Manager prompts for a NEW key instead of silently clobbering. This
      // is the spec-approved way to prevent accidental re-registration.
      const excludeCredentials = user.mfaCredentials.flatMap((c) =>
        c.credentialId != null
          ? [
              {
                id: toB64Url(c.credentialId),
                transports: c.transports as AuthenticatorTransportFuture[],
              },
            ]
          : [],
      );

      const options = await generateRegistrationOptions({
        rpName: env.WEBAUTHN_RP_NAME,
        rpID: env.WEBAUTHN_RP_ID,
        userName: user.email,
        userDisplayName: user.displayName,
        // Stable per-user identifier. WebAuthn §5 lets the RP decide;
        // binding to the DB primary key keeps the authenticator-side
        // entry name stable across credential rotations.
        userID: new TextEncoder().encode(user.id),
        attestationType: 'none',
        authenticatorSelection: {
          residentKey: 'preferred',
          userVerification: USER_VERIFICATION,
        },
        excludeCredentials,
      });

      const pendingToken = signRegistrationToken(user.id, options.challenge);
      return { options, pendingToken };
    },

    async verifyRegistration(userId, { pendingToken, attestationResponse, label }) {
      const decoded = verifyRegistrationToken(pendingToken);
      if (decoded.sub !== userId) {
        // User mismatch: someone is trying to confirm an enrolment for
        // a different account. Same generic shape as the TOTP path.
        throw new UnauthorizedError('Invalid or expired enrolment token');
      }

      let verification;
      try {
        verification = await verifyRegistrationResponse({
          response: attestationResponse,
          expectedChallenge: decoded.challenge,
          expectedOrigin: env.WEBAUTHN_ORIGIN,
          expectedRPID: env.WEBAUTHN_RP_ID,
          requireUserVerification: false, // matches USER_VERIFICATION above; 'preferred' ≈ optional UV
        });
      } catch (e) {
        logger.warn(
          { userId, err: e instanceof Error ? e.message : String(e) },
          'webauthn-registration-verify-failed',
        );
        throw new UnauthorizedError('Invalid attestation');
      }

      if (!verification.verified || !verification.registrationInfo) {
        throw new UnauthorizedError('Invalid attestation');
      }

      const { credential, aaguid } = verification.registrationInfo;
      const credentialId = credential.id; // base64url string
      const credentialIdBytes = fromB64Url(credentialId);
      // Copy into a fresh Uint8Array with an owned ArrayBuffer — the
      // verifier hands us a view into a larger buffer and Prisma 7's
      // `Bytes` column rejects anything with a SharedArrayBuffer-
      // flavoured backing store.
      const publicKeyAb = new ArrayBuffer(credential.publicKey.byteLength);
      new Uint8Array(publicKeyAb).set(credential.publicKey);
      const publicKeyBytes: Uint8Array<ArrayBuffer> = new Uint8Array(publicKeyAb);
      const transports = attestationResponse.response.transports ?? [];

      // Check for duplicate credential ID *across the whole table*.
      // The DB has a UNIQUE index on `credentialId` so the atomic
      // source of truth is the INSERT; the pre-check gives us a clean
      // 409 instead of waiting for Prisma to throw P2002.
      const existing = await prisma.mfaCredential.findUnique({
        where: { credentialId: credentialIdBytes },
        select: { id: true },
      });
      if (existing) {
        throw new ConflictError('This passkey is already registered');
      }

      // Account-level MFA state: if the user wasn't previously MFA-enabled,
      // this registration turns it on AND mints a fresh batch of backup
      // codes (same as P7a's confirmEnrol). If MFA is already on (e.g.
      // TOTP enrolled earlier), skip the code mint — the user already
      // has their single batch.
      const userRow = await prisma.user.findUnique({
        where: { id: userId },
        select: { mfaEnabled: true, mfaBackupCodes: true },
      });
      if (!userRow) throw new NotFoundError('User not found');

      const willInitialiseMfa =
        !userRow.mfaEnabled || userRow.mfaBackupCodes.length === 0;

      let backupCodesPlain: string[] | undefined;
      let backupCodeHashes: string[] | undefined;
      if (willInitialiseMfa) {
        const gen = await generateBackupCodes();
        backupCodesPlain = gen.codes;
        backupCodeHashes = gen.hashes;
      }

      try {
        await prisma.$transaction(async (tx) => {
          await tx.mfaCredential.create({
            data: {
              userId,
              kind: 'WEBAUTHN',
              label: label ?? null,
              credentialId: credentialIdBytes,
              publicKey: publicKeyBytes,
              signCount: credential.counter,
              transports,
              aaguid: aaguid ?? null,
            },
          });
          if (willInitialiseMfa) {
            await tx.user.update({
              where: { id: userId },
              data: {
                mfaEnabled: true,
                mfaBackupCodes: backupCodeHashes ?? [],
              },
            });
          }
        });
      } catch (err) {
        if (
          err instanceof Prisma.PrismaClientKnownRequestError &&
          err.code === 'P2002'
        ) {
          // Race-condition: someone registered the same credential
          // between our pre-check and the INSERT. Fall through to the
          // same 409 we'd have returned on the fast path.
          throw new ConflictError('This passkey is already registered');
        }
        throw err;
      }

      return {
        credentialId,
        ...(backupCodesPlain ? { backupCodes: backupCodesPlain } : {}),
      };
    },

    async listCredentials(userId) {
      const rows = await prisma.mfaCredential.findMany({
        where: { userId, kind: 'WEBAUTHN' },
        orderBy: { createdAt: 'asc' },
      });
      return rows.flatMap((r) =>
        r.credentialId != null
          ? [
              {
                id: r.id,
                credentialId: toB64Url(r.credentialId),
                label: r.label,
                createdAt: r.createdAt,
                lastUsedAt: r.lastUsedAt,
                transports: r.transports,
                aaguid: r.aaguid,
              },
            ]
          : [],
      );
    },

    async deleteCredential(userId, credentialId, { currentPassword }) {
      // Constant-shape re-auth — see `requireCurrentPassword`'s doc for why.
      await requireCurrentPassword(prisma, userId, currentPassword);

      const row = await prisma.mfaCredential.findFirst({
        where: { userId, kind: 'WEBAUTHN', id: credentialId },
        select: { id: true },
      });
      if (!row) {
        // Controller maps this to 404 — the credential either doesn't
        // exist or belongs to a different user. We don't distinguish.
        throw new NotFoundError('Passkey not found');
      }

      await prisma.mfaCredential.delete({ where: { id: row.id } });

      // If this was the last MFA factor, flip `mfaEnabled` off and
      // clear backup codes. Mirrors the parity behaviour in
      // `MfaTotpService.disable` so both code paths converge.
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

    async startAuthentication(userId) {
      const rows = await prisma.mfaCredential.findMany({
        where: { userId, kind: 'WEBAUTHN' },
        select: { credentialId: true, transports: true },
      });
      const allowCredentials = rows.flatMap((r) =>
        r.credentialId != null
          ? [
              {
                id: toB64Url(r.credentialId),
                transports: r.transports as AuthenticatorTransportFuture[],
              },
            ]
          : [],
      );

      const options = await generateAuthenticationOptions({
        rpID: env.WEBAUTHN_RP_ID,
        allowCredentials,
        userVerification: USER_VERIFICATION,
      });

      const challengeToken = signAuthenticationToken(userId, options.challenge);
      return { options, challengeToken };
    },

    async verifyAuthentication(userId, { challengeToken, assertionResponse }) {
      const decoded = verifyAuthenticationToken(challengeToken);
      if (decoded.sub !== userId) {
        // User mismatch on the challenge-token binding. Generic 401.
        throw new UnauthorizedError('Invalid MFA assertion');
      }

      // Look up the stored credential by the base64url id the
      // authenticator returned. Two shapes in play:
      //   - `assertionResponse.id` is base64url.
      //   - `MfaCredential.credentialId` is stored as raw BYTEA.
      const credentialIdBytes = fromB64Url(assertionResponse.id);
      const cred = await prisma.mfaCredential.findUnique({
        where: { credentialId: credentialIdBytes },
        select: {
          id: true,
          userId: true,
          publicKey: true,
          signCount: true,
          transports: true,
        },
      });
      if (!cred || cred.userId !== userId || !cred.publicKey) return false;

      const storedSignCount = cred.signCount ?? 0;

      let verification;
      try {
        verification = await verifyAuthenticationResponse({
          response: assertionResponse,
          expectedChallenge: decoded.challenge,
          expectedOrigin: env.WEBAUTHN_ORIGIN,
          expectedRPID: env.WEBAUTHN_RP_ID,
          credential: {
            id: assertionResponse.id,
            // Copy into a fresh ArrayBuffer so the library's narrow
            // `Uint8Array<ArrayBuffer>` parameter type accepts it.
            publicKey: new Uint8Array(Buffer.from(cred.publicKey)),
            counter: storedSignCount,
            transports: cred.transports as AuthenticatorTransportFuture[],
          },
          requireUserVerification: false,
        });
      } catch (e) {
        logger.warn(
          { userId, err: e instanceof Error ? e.message : String(e) },
          'webauthn-authentication-verify-failed',
        );
        return false;
      }

      if (!verification.verified) return false;

      const newCounter = verification.authenticationInfo.newCounter;

      // Sign-count regression guard. The WebAuthn spec (§6.1.1) says a
      // counter that does NOT strictly increase is a strong signal the
      // authenticator has been cloned. We reject AND leave the stored
      // counter unchanged so a legitimate replacement authenticator
      // (same credentialId re-enrolled — edge case, but possible) can
      // still use the key. Operators should monitor for this log line.
      //
      // Exemption: when BOTH sides are 0, the authenticator is declaring
      // it doesn't maintain a counter (some platform authenticators opt
      // out). Treat that as acceptable — the spec permits it.
      const bothZero = storedSignCount === 0 && newCounter === 0;
      if (!bothZero && newCounter <= storedSignCount) {
        logger.warn(
          {
            userId,
            credentialId: assertionResponse.id,
            storedSignCount,
            newCounter,
          },
          'webauthn-signcount-regression',
        );
        throw new UnauthorizedError(
          'Possible cloned authenticator — security team notified',
        );
      }

      await prisma.mfaCredential.update({
        where: { id: cred.id },
        data: {
          signCount: newCounter,
          lastUsedAt: new Date(),
        },
      });
      return true;
    },
  };
}

export const mfaWebauthnService = createMfaWebauthnService();
