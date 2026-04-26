import { randomBytes } from 'node:crypto';
import { hashPassword, verifyPassword } from '@/utils/password';

/**
 * Slice P7a — one-time MFA backup codes.
 *
 * Format: 10 hex characters split as `XXXXX-XXXXX`. 5 bytes of entropy
 * per code (≈1.1e12 guesses) is plenty for a one-time value that's
 * burned on first use and bucketed behind a tight rate limit.
 *
 * We reuse the existing `bcrypt` primitive (see `utils/password.ts`)
 * rather than adding `argon2` as a second KDF. The plan text flagged
 * argon2 as the "preferred" option; we're deliberately trading
 * slightly-slower-per-verify for no new native dependency. Bcrypt at
 * cost 12 is well above the brute-force ceiling for a code that is
 * itself 40 bits of entropy, and the verify path runs at most a few
 * times per user per year.
 *
 * `verifyBackupCode` is linear in the number of stored hashes: bcrypt
 * is keyed by its internal salt, so there's no dictionary-style lookup.
 * The caller is expected to hold <=10 hashes, so 10 × bcrypt.compare
 * at cost 12 is ~300ms worst-case — acceptable for a login-adjacent
 * flow and already rate-limited on the route.
 */

/**
 * Total number of backup codes generated at enrolment. Kept as an
 * exported constant so tests can assert the set size without re-reading
 * the call-site.
 */
export const DEFAULT_BACKUP_CODE_COUNT = 10;

/**
 * Raw bytes of entropy per code. 5 bytes = 10 hex chars = the `XXXXX-XXXXX`
 * format shown to the user.
 */
const CODE_BYTES = 5;

/**
 * Format a 5-byte random value as `XXXXX-XXXXX` (upper-cased hex with
 * a dash mid-string). A dash is easier to read off a printed card than
 * a run of 10 hex chars.
 */
function formatCode(raw: Buffer): string {
  const hex = raw.toString('hex').toUpperCase();
  return `${hex.slice(0, 5)}-${hex.slice(5, 10)}`;
}

export interface GeneratedBackupCodes {
  /** Plaintext codes — shown to the user ONCE at enrolment. Must be hashed before storage. */
  codes: string[];
  /** bcrypt hashes — the value persisted on `User.mfaBackupCodes`. */
  hashes: string[];
}

/**
 * Generate a fresh batch of backup codes and their bcrypt hashes.
 * Plaintext and hash arrays are positionally aligned; callers that
 * don't need both can destructure.
 */
export async function generateBackupCodes(
  count: number = DEFAULT_BACKUP_CODE_COUNT,
): Promise<GeneratedBackupCodes> {
  const codes: string[] = [];
  const seen = new Set<string>();
  // Reject duplicates up-front — collisions are astronomically
  // unlikely at 40 bits of entropy and 10 draws, but a dedup loop
  // makes the invariant explicit and keeps the test assertion easy.
  while (codes.length < count) {
    const code = formatCode(randomBytes(CODE_BYTES));
    if (seen.has(code)) continue;
    seen.add(code);
    codes.push(code);
  }
  const hashes = await Promise.all(codes.map((c) => hashPassword(c)));
  return { codes, hashes };
}

export interface VerifyBackupCodeResult {
  /** Whether the submitted code matched one of the stored hashes. */
  matched: boolean;
  /**
   * New list of stored hashes with the matched hash removed (burned).
   * If `matched` is false this equals the input list unchanged so the
   * caller can blindly write it back without branching.
   */
  remainingHashes: string[];
}

/**
 * Attempt to match `plainCode` against one of `storedHashes` and burn
 * the matched hash on success.
 *
 * The function iterates every hash even after a match so the total
 * time spent is a function of the stored count, not the position of
 * the match — a small but principled mitigation against a timing
 * attacker who can observe server response time across many probes.
 * (Bcrypt at cost 12 dominates the overall latency so the real
 * distinguisher is already in the hundreds-of-milliseconds range.)
 */
export async function verifyBackupCode(
  plainCode: string,
  storedHashes: string[],
): Promise<VerifyBackupCodeResult> {
  // Input shape guard: an empty or not-formatted string never matches,
  // but we still iterate so timing stays flat.
  //
  // Normalise to the canonical `XXXXX-XXXXX` form that was hashed at
  // generation time: strip whitespace + dashes, uppercase, then re-
  // insert the dash at position 5. This lets us accept both the
  // displayed form and a no-dash / lowercase transcription without
  // storing variant hashes.
  const stripped = plainCode.trim().replace(/[\s-]/g, '').toUpperCase();
  const normalized =
    stripped.length === 10 ? `${stripped.slice(0, 5)}-${stripped.slice(5, 10)}` : stripped;
  let matchedIndex = -1;
  for (let i = 0; i < storedHashes.length; i++) {
    // bcrypt is CPU-bound; parallel map would race on the same cost factor
    const hash = storedHashes[i];
    if (!hash) continue;
    const ok = await verifyPassword(normalized, hash);
    if (ok && matchedIndex < 0) matchedIndex = i;
  }
  if (matchedIndex < 0) {
    return { matched: false, remainingHashes: storedHashes.slice() };
  }
  const remaining = storedHashes.filter((_, i) => i !== matchedIndex);
  return { matched: true, remainingHashes: remaining };
}
