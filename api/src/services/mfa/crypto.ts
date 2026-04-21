import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { env } from '@/config/env';

/**
 * Slice P7a — AES-256-GCM envelope for TOTP secrets at rest.
 *
 * Why a hand-rolled envelope instead of using an AWS KMS / libsodium
 * abstraction: the secret itself is short (Base32, 20–32 chars), the
 * encryption key lives in a single environment variable that the env
 * schema validates is exactly 32 bytes, and the round-trip is fully
 * local. Pulling in libsodium/Tink here would be more surface area than
 * this slice justifies.
 *
 * Layout:
 *   iv (12 bytes) || tag (16 bytes) || ciphertext (variable)
 * The whole buffer is then base64-encoded for storage in a TEXT column.
 *
 * Hardening:
 *  - Fresh 12-byte IV per encryption (GCM requires IV uniqueness per
 *    key; collisions would leak plaintext XORs).
 *  - AAD intentionally unset — nothing outside the ciphertext is
 *    authenticated. If a future slice adds a per-user binding, thread
 *    `userId` through as AAD.
 *  - `decryptTotpSecret` throws on any tampering (wrong tag, truncated
 *    IV, mangled payload). Callers should map the throw to 401 without
 *    exposing the underlying reason.
 */

const ALGO = 'aes-256-gcm';
const IV_LEN = 12; // 96 bits — GCM standard.
const TAG_LEN = 16; // 128 bits.

let cachedKey: Buffer | undefined;
function getKey(): Buffer {
  if (cachedKey) return cachedKey;
  const decoded = Buffer.from(env.MFA_ENCRYPTION_KEY, 'base64');
  if (decoded.byteLength !== 32) {
    // Should be impossible — the env validator rejects on boot — but
    // this keeps the invariant local to the module that cares.
    throw new Error('MFA_ENCRYPTION_KEY must decode to 32 bytes');
  }
  cachedKey = decoded;
  return cachedKey;
}

/**
 * Encrypt a TOTP secret with a fresh IV. Output is
 * base64(iv || tag || ciphertext) so the whole thing can be stored
 * unmodified in `MfaCredential.totpSecretEncrypted`.
 */
export function encryptTotpSecret(secret: string): string {
  const key = getKey();
  const iv = randomBytes(IV_LEN);
  const cipher = createCipheriv(ALGO, key, iv);
  const ct = Buffer.concat([cipher.update(secret, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, ct]).toString('base64');
}

/**
 * Reverse of {@link encryptTotpSecret}. Throws on any detected tamper
 * (wrong key, mangled ciphertext, truncated envelope). The error
 * message is deliberately generic — callers should not forward it to
 * clients.
 */
export function decryptTotpSecret(payload: string): string {
  const key = getKey();
  const buf = Buffer.from(payload, 'base64');
  if (buf.byteLength < IV_LEN + TAG_LEN + 1) {
    // Too short to contain iv + tag + at least one byte of ciphertext.
    throw new Error('MFA ciphertext is malformed');
  }
  const iv = buf.subarray(0, IV_LEN);
  const tag = buf.subarray(IV_LEN, IV_LEN + TAG_LEN);
  const ct = buf.subarray(IV_LEN + TAG_LEN);
  const decipher = createDecipheriv(ALGO, key, iv);
  decipher.setAuthTag(tag);
  const plain = Buffer.concat([decipher.update(ct), decipher.final()]);
  return plain.toString('utf8');
}
