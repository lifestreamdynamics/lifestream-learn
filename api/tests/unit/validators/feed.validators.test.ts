import '@tests/unit/setup';
import {
  decodeFeedCursor,
  encodeFeedCursor,
  feedQuerySchema,
} from '@/validators/feed.validators';

describe('feed.validators', () => {
  it('cursor round-trip', () => {
    const c = {
      startedAt: new Date('2026-04-19T00:00:00Z'),
      orderIndex: 7,
      videoId: 'abcd',
    };
    const enc = encodeFeedCursor(c);
    const dec = decodeFeedCursor(enc);
    expect(dec?.orderIndex).toBe(7);
    expect(dec?.videoId).toBe('abcd');
  });

  it('cursor rejects garbage', () => {
    expect(decodeFeedCursor(Buffer.from('no-pipes').toString('base64'))).toBeNull();
    expect(decodeFeedCursor(Buffer.from('a|b|c').toString('base64'))).toBeNull();
    // Non-integer orderIndex
    expect(
      decodeFeedCursor(Buffer.from('2026-04-19T00:00:00Z|xx|vid').toString('base64')),
    ).toBeNull();
  });

  it('feedQuerySchema coerces limit', () => {
    expect(feedQuerySchema.parse({ limit: '25' }).limit).toBe(25);
  });

  it('feedQuerySchema caps limit at 50', () => {
    expect(() => feedQuerySchema.parse({ limit: 51 })).toThrow();
  });
});
