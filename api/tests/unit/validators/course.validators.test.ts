import '@tests/unit/setup';
import {
  addCollaboratorBodySchema,
  createCourseBodySchema,
  decodeCourseCursor,
  encodeCourseCursor,
  listCoursesQuerySchema,
  updateCourseBodySchema,
} from '@/validators/course.validators';

describe('course.validators', () => {
  describe('createCourseBodySchema', () => {
    it('accepts minimal valid input', () => {
      expect(() =>
        createCourseBodySchema.parse({ title: 'Hello', description: 'd' }),
      ).not.toThrow();
    });

    it('rejects empty description', () => {
      expect(() =>
        createCourseBodySchema.parse({ title: 'h', description: '' }),
      ).toThrow();
    });

    it('rejects malformed coverImageUrl', () => {
      expect(() =>
        createCourseBodySchema.parse({
          title: 'h',
          description: 'd',
          coverImageUrl: 'not-a-url',
        }),
      ).toThrow();
    });

    it('rejects slug with uppercase', () => {
      expect(() =>
        createCourseBodySchema.parse({
          title: 'h',
          description: 'd',
          slug: 'Bad',
        }),
      ).toThrow();
    });

    it('accepts valid slug', () => {
      expect(() =>
        createCourseBodySchema.parse({
          title: 'h',
          description: 'd',
          slug: 'my-course-12',
        }),
      ).not.toThrow();
    });
  });

  describe('updateCourseBodySchema', () => {
    it('allows coverImageUrl null', () => {
      expect(() =>
        updateCourseBodySchema.parse({ coverImageUrl: null }),
      ).not.toThrow();
    });

    it('allows empty body', () => {
      expect(() => updateCourseBodySchema.parse({})).not.toThrow();
    });
  });

  describe('listCoursesQuerySchema', () => {
    it('coerces boolean strings', () => {
      const p = listCoursesQuerySchema.parse({ owned: 'true', published: 'false' });
      expect(p.owned).toBe(true);
      expect(p.published).toBe(false);
    });

    it('coerces numeric limit', () => {
      const p = listCoursesQuerySchema.parse({ limit: '10' });
      expect(p.limit).toBe(10);
    });

    it('rejects limit above 50', () => {
      expect(() => listCoursesQuerySchema.parse({ limit: 100 })).toThrow();
    });
  });

  describe('cursor encode/decode', () => {
    it('round-trips', () => {
      const c = {
        createdAt: new Date('2026-04-19T12:34:56.789Z'),
        id: '11111111-1111-4111-8111-111111111111',
      };
      const decoded = decodeCourseCursor(encodeCourseCursor(c));
      expect(decoded?.id).toBe(c.id);
      expect(decoded?.createdAt.getTime()).toBe(c.createdAt.getTime());
    });

    it('returns null on garbage', () => {
      expect(decodeCourseCursor('!!')).toBeNull();
      expect(decodeCourseCursor(Buffer.from('no-pipe').toString('base64'))).toBeNull();
    });
  });

  describe('addCollaboratorBodySchema', () => {
    it('requires uuid', () => {
      expect(() => addCollaboratorBodySchema.parse({ userId: 'nope' })).toThrow();
    });
  });
});
