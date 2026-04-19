import '@tests/unit/setup';
import {
  analyticsEventSchema,
  analyticsEventsBodySchema,
} from '@/validators/analytics.validators';

describe('analytics.validators', () => {
  describe('analyticsEventSchema', () => {
    it('accepts a minimal event', () => {
      expect(() =>
        analyticsEventSchema.parse({
          eventType: 'video_view',
          occurredAt: '2026-04-19T00:00:00.000Z',
        }),
      ).not.toThrow();
    });

    it('rejects oversized eventType', () => {
      expect(() =>
        analyticsEventSchema.parse({
          eventType: 'x'.repeat(100),
          occurredAt: '2026-04-19T00:00:00.000Z',
        }),
      ).toThrow();
    });

    it('rejects malformed occurredAt', () => {
      expect(() =>
        analyticsEventSchema.parse({
          eventType: 'x',
          occurredAt: 'not-a-date',
        }),
      ).toThrow();
    });
  });

  describe('analyticsEventsBodySchema', () => {
    it('rejects empty batch', () => {
      expect(() => analyticsEventsBodySchema.parse([])).toThrow();
    });

    it('rejects batch > 100', () => {
      const big = Array.from({ length: 101 }, () => ({
        eventType: 'x',
        occurredAt: '2026-04-19T00:00:00.000Z',
      }));
      expect(() => analyticsEventsBodySchema.parse(big)).toThrow();
    });
  });
});
