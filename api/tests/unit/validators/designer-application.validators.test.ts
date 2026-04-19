import '@tests/unit/setup';
import {
  createDesignerApplicationBodySchema,
  decodeDesignerApplicationCursor,
  encodeDesignerApplicationCursor,
  listDesignerApplicationsQuerySchema,
  reviewDesignerApplicationBodySchema,
} from '@/validators/designer-application.validators';

describe('designer-application.validators', () => {
  describe('createDesignerApplicationBodySchema', () => {
    it('accepts empty body', () => {
      expect(() => createDesignerApplicationBodySchema.parse({})).not.toThrow();
    });
    it('accepts valid note', () => {
      expect(() =>
        createDesignerApplicationBodySchema.parse({ note: 'pls' }),
      ).not.toThrow();
    });
    it('rejects oversized note', () => {
      expect(() =>
        createDesignerApplicationBodySchema.parse({ note: 'x'.repeat(3000) }),
      ).toThrow();
    });
  });

  describe('reviewDesignerApplicationBodySchema', () => {
    it('accepts APPROVED', () => {
      expect(() =>
        reviewDesignerApplicationBodySchema.parse({ status: 'APPROVED' }),
      ).not.toThrow();
    });
    it('rejects PENDING', () => {
      // Only APPROVED/REJECTED allowed on review
      expect(() =>
        reviewDesignerApplicationBodySchema.parse({ status: 'PENDING' }),
      ).toThrow();
    });
  });

  describe('listDesignerApplicationsQuerySchema', () => {
    it('coerces limit', () => {
      const p = listDesignerApplicationsQuerySchema.parse({ limit: '5' });
      expect(p.limit).toBe(5);
    });
    it('accepts status filter', () => {
      const p = listDesignerApplicationsQuerySchema.parse({ status: 'APPROVED' });
      expect(p.status).toBe('APPROVED');
    });
  });

  describe('cursor encode/decode', () => {
    it('round-trips', () => {
      const c = {
        submittedAt: new Date('2026-04-19T00:00:00Z'),
        id: '11111111-1111-4111-8111-111111111111',
      };
      const enc = encodeDesignerApplicationCursor(c);
      const dec = decodeDesignerApplicationCursor(enc);
      expect(dec?.id).toBe(c.id);
      expect(dec?.submittedAt.getTime()).toBe(c.submittedAt.getTime());
    });

    it('returns null on garbage', () => {
      expect(decodeDesignerApplicationCursor(Buffer.from('one').toString('base64')))
        .toBeNull();
      expect(
        decodeDesignerApplicationCursor(
          Buffer.from('not-a-date|id').toString('base64'),
        ),
      ).toBeNull();
    });
  });
});
