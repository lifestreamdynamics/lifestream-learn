import { randomBytes } from 'node:crypto';

/**
 * ASCII slugifier for course titles.
 *
 * - NFKD-normalises then strips combining marks (handles diacritics: é → e).
 * - Lowercases.
 * - Collapses non-alphanumeric runs into `-`.
 * - Trims leading/trailing `-`.
 * - Caps the base at 60 chars so the `${slug}-${suffix}` we return below
 *   stays comfortably under the 255-char text column ceiling.
 *
 * Exported for unit testing — the factory below is what callers use.
 */
export function slugifyBase(title: string): string {
  const normalised = title.normalize('NFKD').replace(/[\u0300-\u036f]/g, '');
  const ascii = normalised
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  // Collapse any accidental internal double-dashes left by the pattern above.
  const cleaned = ascii.replace(/-{2,}/g, '-');
  return cleaned.slice(0, 60).replace(/-+$/g, '');
}

/**
 * Short random suffix to avoid slug collisions on similar titles.
 * 4 bytes → 8 hex chars; we slice to 6 per the plan.
 */
export function randomSlugSuffix(): string {
  return randomBytes(4).toString('hex').slice(0, 6);
}

/**
 * Compose a full course slug. If the base slugifies to an empty string
 * (e.g. title is all punctuation or non-ASCII glyphs that strip away),
 * fall back to `course` so the slug is never bare-suffix-only.
 */
export function buildCourseSlug(title: string): string {
  const base = slugifyBase(title);
  const prefix = base.length > 0 ? base : 'course';
  return `${prefix}-${randomSlugSuffix()}`;
}
