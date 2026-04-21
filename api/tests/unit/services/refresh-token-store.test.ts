import '@tests/unit/setup';

// Mock the shared redis client before importing the module under test.
// The store calls `redis.set(key, val, 'EX', ttl, 'NX')` and
// `redis.get(key)`; we stub both.
const mockSet = jest.fn();
const mockGet = jest.fn();

jest.mock('@/config/redis', () => ({
  redis: {
    set: (...args: unknown[]) => mockSet(...args),
    get: (...args: unknown[]) => mockGet(...args),
  },
}));

import {
  tryRevokeRefreshJti,
  isRefreshJtiRevoked,
  _testing,
} from '@/services/refresh-token-store';

describe('refresh-token-store', () => {
  beforeEach(() => {
    mockSet.mockReset();
    mockGet.mockReset();
  });

  describe('tryRevokeRefreshJti', () => {
    it('returns true when SET NX succeeds (first writer wins)', async () => {
      mockSet.mockResolvedValueOnce('OK');
      const result = await tryRevokeRefreshJti('jti-1');
      expect(result).toBe(true);
      expect(mockSet).toHaveBeenCalledWith(
        'refresh-revoked:jti-1',
        '1',
        'EX',
        expect.any(Number),
        'NX',
      );
    });

    it('returns false when the jti was already revoked (NX miss)', async () => {
      // Redis returns `null` for SET NX when the key already exists.
      mockSet.mockResolvedValueOnce(null);
      const result = await tryRevokeRefreshJti('jti-already-used');
      expect(result).toBe(false);
    });

    it('uses a non-zero TTL (so revocations actually expire instead of growing unbounded)', async () => {
      mockSet.mockResolvedValueOnce('OK');
      await tryRevokeRefreshJti('jti-x');
      const ttl = mockSet.mock.calls[0][3] as number;
      expect(ttl).toBeGreaterThan(0);
    });
  });

  describe('isRefreshJtiRevoked', () => {
    it('returns true when the key exists', async () => {
      mockGet.mockResolvedValueOnce('1');
      expect(await isRefreshJtiRevoked('jti-a')).toBe(true);
      expect(mockGet).toHaveBeenCalledWith('refresh-revoked:jti-a');
    });

    it('returns false when the key is absent', async () => {
      mockGet.mockResolvedValueOnce(null);
      expect(await isRefreshJtiRevoked('jti-b')).toBe(false);
    });
  });

  describe('parseRefreshTtlSeconds', () => {
    const parse = _testing.parseRefreshTtlSeconds;

    it('parses day suffix', () => {
      expect(parse('30d')).toBe(30 * 86400);
    });

    it('parses hour suffix', () => {
      expect(parse('12h')).toBe(12 * 3600);
    });

    it('parses minute suffix', () => {
      expect(parse('15m')).toBe(15 * 60);
    });

    it('parses second suffix', () => {
      expect(parse('3600s')).toBe(3600);
    });

    it('treats bare integers as seconds', () => {
      expect(parse('3600')).toBe(3600);
    });

    it('falls back to 30 days on malformed input', () => {
      // Guard against an operator setting JWT_REFRESH_TTL to a value
      // that jsonwebtoken accepts but our simple parser doesn't — we
      // prefer "too-long revocation" over "no revocation at all".
      expect(parse('not-a-duration')).toBe(30 * 86400);
    });

    it('tolerates surrounding whitespace', () => {
      expect(parse('  7d  ')).toBe(7 * 86400);
    });
  });
});
