import '@tests/unit/setup';

jest.mock('@/config/redis', () => ({
  redis: {
    // SCRIPT LOAD returns a sha string; other commands return integers.
    call: jest.fn().mockImplementation((cmd: string) =>
      cmd === 'SCRIPT' ? Promise.resolve('deadbeef') : Promise.resolve(1),
    ),
  },
}));

import { signupLimiter, loginLimiter, refreshLimiter } from '@/middleware/rate-limit';

describe('rate-limit middleware factories', () => {
  it('exports all three limiters as callable middleware', () => {
    for (const mw of [signupLimiter, loginLimiter, refreshLimiter]) {
      expect(typeof mw).toBe('function');
      expect(mw.length).toBe(3); // (req, res, next)
    }
  });
});
