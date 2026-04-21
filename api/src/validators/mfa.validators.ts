import { z } from 'zod';

/**
 * Slice P7a — validators for the MFA endpoints.
 *
 * TOTP codes are canonicalised to 6 digits (no spaces / dashes / unicode
 * digits) and backup codes are canonicalised to uppercase with the
 * `XXXXX-XXXXX` separator stripped. The service layer uppercases again
 * before comparing against stored hashes — duplication here is for the
 * HTTP boundary's per-request defence.
 *
 * Every schema uses `.strict()` so unknown keys are rejected rather
 * than silently dropped; any input slop gets surfaced as a 400 at the
 * router seam.
 */

const TOTP_CODE = z
  .string()
  .trim()
  .transform((s) => s.replace(/\s+/g, ''))
  .pipe(z.string().regex(/^\d{6}$/, 'TOTP code must be 6 digits'));

// Backup code format: `XXXXX-XXXXX` (hex, dash-separated). We accept
// case-insensitive input + any whitespace/dash layout and normalise
// down to the canonical `XXXXX-XXXXX` uppercase form before matching.
const BACKUP_CODE = z
  .string()
  .trim()
  .transform((s) => s.replace(/[\s-]/g, '').toUpperCase())
  .pipe(
    z
      .string()
      .regex(
        /^[0-9A-F]{10}$/,
        'Backup code must be 10 hex characters (optionally hyphenated)',
      )
      .transform((s) => `${s.slice(0, 5)}-${s.slice(5, 10)}`),
  );

export const totpEnrolStartBodySchema = z.object({}).strict();

export const totpEnrolConfirmBodySchema = z
  .object({
    pendingToken: z.string().min(1).max(4096),
    code: TOTP_CODE,
    label: z.string().trim().min(1).max(80).optional(),
  })
  .strict();
export type TotpEnrolConfirmBody = z.infer<typeof totpEnrolConfirmBodySchema>;

export const totpDisableBodySchema = z
  .object({
    currentPassword: z.string().min(1).max(128),
    code: TOTP_CODE,
  })
  .strict();
export type TotpDisableBody = z.infer<typeof totpDisableBodySchema>;

export const loginMfaTotpBodySchema = z
  .object({
    mfaToken: z.string().min(1).max(4096),
    code: TOTP_CODE,
  })
  .strict();
export type LoginMfaTotpBody = z.infer<typeof loginMfaTotpBodySchema>;

export const loginMfaBackupBodySchema = z
  .object({
    mfaToken: z.string().min(1).max(4096),
    code: BACKUP_CODE,
  })
  .strict();
export type LoginMfaBackupBody = z.infer<typeof loginMfaBackupBodySchema>;

// ---------- Slice P7b — WebAuthn / passkeys ----------
//
// The attestation and assertion responses are passed through as-is to
// `@simplewebauthn/server`'s verifiers. We do NOT attempt to re-validate
// their shape here beyond "it's a reasonable object with the fields the
// library needs" — the library itself rejects malformed payloads. Our
// job at this boundary is size-capping (so a 50 MB POST can't exhaust
// Express's JSON parser before we even read it) and making sure the
// pendingToken / challengeToken are plausible JWT strings.

// A WebAuthn attestation or assertion response is a nested JSON object
// whose `.response` sub-object carries large base64url blobs. 64 KiB is
// comfortably above the largest real-world payload we've seen (~8 KiB
// for a full direct attestation) and still sized so a single malicious
// client can't pin Node parsing a 100 MB JSON.
const webauthnResponseMaxBytes = 64 * 1024;

const webauthnResponseShape = z
  .object({
    id: z.string().min(1).max(2048),
    rawId: z.string().min(1).max(2048),
    type: z.literal('public-key'),
    clientExtensionResults: z.record(z.unknown()).optional(),
    authenticatorAttachment: z.string().optional(),
    response: z.record(z.unknown()),
  })
  .passthrough()
  .refine(
    (obj) => {
      try {
        return JSON.stringify(obj).length <= webauthnResponseMaxBytes;
      } catch {
        return false;
      }
    },
    { message: 'WebAuthn response exceeds maximum payload size' },
  );

export const webauthnRegistrationStartBodySchema = z.object({}).strict();

export const webauthnRegistrationVerifyBodySchema = z
  .object({
    pendingToken: z.string().min(1).max(4096),
    attestationResponse: webauthnResponseShape,
    label: z.string().trim().min(1).max(80).optional(),
  })
  .strict();
export type WebauthnRegistrationVerifyBody = z.infer<
  typeof webauthnRegistrationVerifyBodySchema
>;

export const webauthnDeleteBodySchema = z
  .object({
    currentPassword: z.string().min(1).max(128),
  })
  .strict();
export type WebauthnDeleteBody = z.infer<typeof webauthnDeleteBodySchema>;

export const loginMfaWebauthnOptionsBodySchema = z
  .object({
    mfaToken: z.string().min(1).max(4096),
  })
  .strict();
export type LoginMfaWebauthnOptionsBody = z.infer<
  typeof loginMfaWebauthnOptionsBodySchema
>;

export const loginMfaWebauthnVerifyBodySchema = z
  .object({
    mfaToken: z.string().min(1).max(4096),
    challengeToken: z.string().min(1).max(4096),
    assertionResponse: webauthnResponseShape,
  })
  .strict();
export type LoginMfaWebauthnVerifyBody = z.infer<
  typeof loginMfaWebauthnVerifyBodySchema
>;
