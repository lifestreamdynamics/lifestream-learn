import '@tests/unit/setup';
import {
  generateBackupCodes,
  verifyBackupCode,
  DEFAULT_BACKUP_CODE_COUNT,
} from '@/services/mfa/backup-codes';

describe('mfa/backup-codes', () => {
  describe('generateBackupCodes', () => {
    it('generates DEFAULT_BACKUP_CODE_COUNT unique codes in the XXXXX-XXXXX format', async () => {
      const { codes, hashes } = await generateBackupCodes();
      expect(codes).toHaveLength(DEFAULT_BACKUP_CODE_COUNT);
      expect(hashes).toHaveLength(DEFAULT_BACKUP_CODE_COUNT);
      // Uniqueness.
      expect(new Set(codes).size).toBe(codes.length);
      // Shape: 5 hex uppercase, dash, 5 hex uppercase.
      for (const code of codes) {
        expect(code).toMatch(/^[0-9A-F]{5}-[0-9A-F]{5}$/);
      }
      // Hashes are bcrypt strings, not the plaintext.
      for (const h of hashes) {
        expect(h).toMatch(/^\$2[aby]\$/);
        expect(codes).not.toContain(h);
      }
    });

    it('respects a custom count', async () => {
      const { codes } = await generateBackupCodes(3);
      expect(codes).toHaveLength(3);
    });
  });

  describe('verifyBackupCode', () => {
    it('returns matched + burns the matched hash', async () => {
      const { codes, hashes } = await generateBackupCodes(3);
      const [code0] = codes;
      const result = await verifyBackupCode(code0!, hashes);
      expect(result.matched).toBe(true);
      expect(result.remainingHashes).toHaveLength(2);
      expect(result.remainingHashes).not.toContain(hashes[0]);
      // The remaining set preserves the other two in order.
      expect(result.remainingHashes[0]).toBe(hashes[1]);
      expect(result.remainingHashes[1]).toBe(hashes[2]);
    });

    it('returns matched=false and leaves the hash set untouched on a bad code', async () => {
      const { hashes } = await generateBackupCodes(3);
      const result = await verifyBackupCode('DEADB-EEFFF', hashes);
      expect(result.matched).toBe(false);
      expect(result.remainingHashes).toEqual(hashes);
    });

    it('accepts a code entered without the dash or in lowercase', async () => {
      const { codes, hashes } = await generateBackupCodes(2);
      const raw = codes[0]!.replace('-', '').toLowerCase();
      const result = await verifyBackupCode(raw, hashes);
      expect(result.matched).toBe(true);
    });

    it('second use of the same code fails (single-use guarantee)', async () => {
      const { codes, hashes } = await generateBackupCodes(3);
      const first = await verifyBackupCode(codes[0]!, hashes);
      expect(first.matched).toBe(true);
      const replay = await verifyBackupCode(codes[0]!, first.remainingHashes);
      expect(replay.matched).toBe(false);
      expect(replay.remainingHashes).toEqual(first.remainingHashes);
    });

    it('returns matched=false on an empty hash list without throwing', async () => {
      const result = await verifyBackupCode('A0B1C-D2E3F', []);
      expect(result.matched).toBe(false);
      expect(result.remainingHashes).toEqual([]);
    });
  });
});
