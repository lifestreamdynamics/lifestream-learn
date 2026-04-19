import '@tests/unit/setup';
import { buildCourseSlug, randomSlugSuffix, slugifyBase } from '@/utils/slugify';

describe('slugify', () => {
  describe('slugifyBase', () => {
    it('lowercases and hyphenates', () => {
      expect(slugifyBase('Hello World')).toBe('hello-world');
    });

    it('strips diacritics', () => {
      expect(slugifyBase('Café au Lait')).toBe('cafe-au-lait');
    });

    it('collapses runs of punctuation', () => {
      expect(slugifyBase('Hello!!  --  World')).toBe('hello-world');
    });

    it('trims leading/trailing hyphens', () => {
      expect(slugifyBase('---hi---')).toBe('hi');
    });

    it('caps at 60 chars', () => {
      const long = 'a'.repeat(120);
      const out = slugifyBase(long);
      expect(out.length).toBeLessThanOrEqual(60);
    });

    it('returns empty string for all-non-alnum input', () => {
      expect(slugifyBase('!!!')).toBe('');
      expect(slugifyBase('   ')).toBe('');
    });

    it('handles unicode by reducing to ASCII or dropping', () => {
      // Non-latin glyphs that have no ASCII decomposition get dropped.
      expect(slugifyBase('日本')).toBe('');
    });

    it('keeps numerics', () => {
      expect(slugifyBase('Lesson 101')).toBe('lesson-101');
    });
  });

  describe('randomSlugSuffix', () => {
    it('produces a 6-char hex string', () => {
      const s = randomSlugSuffix();
      expect(s).toMatch(/^[0-9a-f]{6}$/);
    });

    it('is not deterministic', () => {
      const a = randomSlugSuffix();
      const b = randomSlugSuffix();
      // Astronomically unlikely to collide twice in a row.
      expect(a === b && randomSlugSuffix() === a).toBe(false);
    });
  });

  describe('buildCourseSlug', () => {
    it('produces slugifiedTitle-<6hex> shape', () => {
      const slug = buildCourseSlug('My First Course');
      expect(slug).toMatch(/^my-first-course-[0-9a-f]{6}$/);
    });

    it('falls back to "course-<hex>" when title has no alnum', () => {
      const slug = buildCourseSlug('!!!');
      expect(slug).toMatch(/^course-[0-9a-f]{6}$/);
    });
  });
});
