import '@tests/unit/setup';
import {
  encryptTotpSecret,
  decryptTotpSecret,
} from '@/services/mfa/crypto';

describe('mfa/crypto', () => {
  it('round-trips a secret back to the original plaintext', () => {
    const plain = 'JBSWY3DPEHPK3PXP'; // sample base32 TOTP secret
    const ct = encryptTotpSecret(plain);
    expect(typeof ct).toBe('string');
    expect(ct.length).toBeGreaterThan(plain.length);
    expect(decryptTotpSecret(ct)).toBe(plain);
  });

  it('produces a fresh IV per encryption (no two ciphertexts match for the same plaintext)', () => {
    const plain = 'JBSWY3DPEHPK3PXP';
    const ct1 = encryptTotpSecret(plain);
    const ct2 = encryptTotpSecret(plain);
    expect(ct1).not.toBe(ct2);
  });

  it('detects tamper in the ciphertext body', () => {
    const plain = 'JBSWY3DPEHPK3PXP';
    const ct = encryptTotpSecret(plain);
    const buf = Buffer.from(ct, 'base64');
    // Flip a single bit in the ciphertext (after iv+tag = bytes 28+)
    buf[buf.length - 1] = buf[buf.length - 1]! ^ 0x01;
    const tampered = buf.toString('base64');
    expect(() => decryptTotpSecret(tampered)).toThrow();
  });

  it('detects tamper in the auth tag', () => {
    const plain = 'JBSWY3DPEHPK3PXP';
    const ct = encryptTotpSecret(plain);
    const buf = Buffer.from(ct, 'base64');
    // Flip a bit inside the 16-byte GCM tag (bytes 12..27).
    buf[15] = buf[15]! ^ 0x80;
    const tampered = buf.toString('base64');
    expect(() => decryptTotpSecret(tampered)).toThrow();
  });

  it('rejects an envelope that is too short to contain iv + tag + ciphertext', () => {
    // 20 bytes of zeros — smaller than iv(12) + tag(16) + at-least-1
    const tooShort = Buffer.alloc(20, 0).toString('base64');
    expect(() => decryptTotpSecret(tooShort)).toThrow(/malformed/i);
  });

  it('encrypts non-ASCII plaintext correctly', () => {
    const plain = 'sécrète-日本語-🎉';
    const ct = encryptTotpSecret(plain);
    expect(decryptTotpSecret(ct)).toBe(plain);
  });
});
