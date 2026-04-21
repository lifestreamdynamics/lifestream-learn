/**
 * @openapi
 * tags:
 *   name: MFA
 *   description: Multi-factor authentication (TOTP) endpoints.
 */
import type { Request, Response } from 'express';
import type { RegistrationResponseJSON } from '@simplewebauthn/server';
import { mfaTotpService } from '@/services/mfa-totp.service';
import { mfaWebauthnService } from '@/services/mfa-webauthn.service';
import { UnauthorizedError } from '@/utils/errors';
import {
  totpEnrolStartBodySchema,
  totpEnrolConfirmBodySchema,
  totpDisableBodySchema,
  webauthnRegistrationStartBodySchema,
  webauthnRegistrationVerifyBodySchema,
  webauthnDeleteBodySchema,
} from '@/validators/mfa.validators';

/**
 * @openapi
 * /api/me/mfa:
 *   get:
 *     tags: [MFA]
 *     summary: Report the caller's currently-enrolled MFA methods.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Method summary (totp, webauthnCount, backupCodesRemaining). }
 *       401: { description: Unauthenticated. }
 */
export async function listMethods(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const methods = await mfaTotpService.listMethods(req.user.id);
  res.status(200).json(methods);
}

/**
 * @openapi
 * /api/me/mfa/totp/enrol:
 *   post:
 *     tags: [MFA]
 *     summary: Begin TOTP enrolment — returns the QR code + pending token.
 *     description: |
 *       Generates a fresh base32 secret, an otpauth:// URL, a QR data URL,
 *       and a short-lived (10 min) pending token. The secret is NOT
 *       persisted until the user confirms via `POST /api/me/mfa/totp/verify`
 *       with a valid 6-digit code.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Enrolment payload. }
 *       401: { description: Unauthenticated. }
 *       409: { description: TOTP already enrolled. }
 */
export async function startEnrol(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  totpEnrolStartBodySchema.parse(req.body ?? {});
  const result = await mfaTotpService.startEnrol(req.user.id);
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/me/mfa/totp/verify:
 *   post:
 *     tags: [MFA]
 *     summary: Confirm TOTP enrolment with a 6-digit code.
 *     description: |
 *       Succeeds only with a valid pending-enrolment token (from
 *       `/enrol`) AND a matching 6-digit code. Flips
 *       `mfaEnabled = true`, persists the AES-GCM-encrypted secret, and
 *       returns 10 plaintext backup codes ONCE — the user must save
 *       them now. Subsequent GET /api/me/mfa reports counts only; the
 *       plaintext cannot be retrieved again.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Enrolment confirmed; returns backup codes once. }
 *       401: { description: Wrong code or expired pending token. }
 *       409: { description: TOTP already enrolled. }
 */
export async function confirmEnrol(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = totpEnrolConfirmBodySchema.parse(req.body);
  const result = await mfaTotpService.confirmEnrol(req.user.id, body);
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/me/mfa/totp:
 *   delete:
 *     tags: [MFA]
 *     summary: Disable the caller's TOTP factor.
 *     description: |
 *       Requires both the current password (re-auth parity with P5
 *       destructive ops) AND a current TOTP code. Clears backup codes
 *       as a side-effect when no other factor remains.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       204: { description: TOTP disabled. }
 *       401: { description: Wrong password or wrong code. }
 */
export async function disable(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = totpDisableBodySchema.parse(req.body);
  await mfaTotpService.disable(req.user.id, body);
  res.status(204).send();
}

/**
 * @openapi
 * /api/me/mfa/webauthn/register/options:
 *   post:
 *     tags: [MFA]
 *     summary: Begin WebAuthn passkey registration — returns creation options + pending token.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: "PublicKeyCredentialCreationOptionsJSON plus pendingToken." }
 *       401: { description: Unauthenticated. }
 */
export async function startWebauthnRegistration(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  webauthnRegistrationStartBodySchema.parse(req.body ?? {});
  const result = await mfaWebauthnService.startRegistration(req.user.id);
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/me/mfa/webauthn/register/verify:
 *   post:
 *     tags: [MFA]
 *     summary: Verify and persist a WebAuthn passkey registration.
 *     description: |
 *       Requires the `pendingToken` from `/register/options` + the full
 *       attestation response the platform credential manager returned.
 *       On first MFA enrolment (no TOTP, no prior passkey), the server
 *       also mints 10 plaintext backup codes — these are returned ONCE.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: "Returns credentialId and backupCodes (only on first MFA enrolment)." }
 *       401: { description: "Invalid attestation or token." }
 *       409: { description: "Passkey already registered." }
 */
export async function verifyWebauthnRegistration(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = webauthnRegistrationVerifyBodySchema.parse(req.body);
  const result = await mfaWebauthnService.verifyRegistration(req.user.id, {
    pendingToken: body.pendingToken,
    // The validator intentionally keeps the shape loose — we hand the
    // object to @simplewebauthn/server which has its own strict parser.
    attestationResponse: body.attestationResponse as unknown as RegistrationResponseJSON,
    label: body.label,
  });
  res.status(200).json(result);
}

/**
 * @openapi
 * /api/me/mfa/webauthn:
 *   get:
 *     tags: [MFA]
 *     summary: List the caller's registered passkeys.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: "Array of registered passkeys (id, credentialId, label, createdAt, lastUsedAt, transports, aaguid)." }
 *       401: { description: Unauthenticated. }
 */
export async function listWebauthnCredentials(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const rows = await mfaWebauthnService.listCredentials(req.user.id);
  res.status(200).json(rows);
}

/**
 * @openapi
 * /api/me/mfa/webauthn/{credentialId}:
 *   delete:
 *     tags: [MFA]
 *     summary: Delete one of the caller's passkeys.
 *     description: |
 *       Requires current password (re-auth parity with other destructive
 *       account operations). If this was the last MFA factor, flips
 *       `mfaEnabled` off and clears backup codes.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       204: { description: Deleted. }
 *       401: { description: "Wrong password." }
 *       404: { description: "Passkey not found or not owned by caller." }
 */
export async function deleteWebauthnCredential(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');
  const body = webauthnDeleteBodySchema.parse(req.body);
  const credentialId = req.params.credentialId;
  if (!credentialId) throw new UnauthorizedError('Missing credential id');
  await mfaWebauthnService.deleteCredential(req.user.id, credentialId, body);
  res.status(204).send();
}
