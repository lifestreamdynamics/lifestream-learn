import '@tests/unit/setup';
import { hashPassword, verifyPassword } from '@/utils/password';

describe('password utils', () => {
  it('hashes and verifies a correct password', async () => {
    const hash = await hashPassword('correct-horse-battery-staple');
    expect(hash).not.toBe('correct-horse-battery-staple');
    expect(hash.length).toBeGreaterThan(20);
    await expect(verifyPassword('correct-horse-battery-staple', hash)).resolves.toBe(true);
  });

  it('rejects a wrong password', async () => {
    const hash = await hashPassword('right-password-1234');
    await expect(verifyPassword('wrong-password-1234', hash)).resolves.toBe(false);
  });

  it('produces distinct hashes for the same input (salted)', async () => {
    const h1 = await hashPassword('same-input-here-xx');
    const h2 = await hashPassword('same-input-here-xx');
    expect(h1).not.toBe(h2);
  });
});
