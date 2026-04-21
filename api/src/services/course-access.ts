import type { Role } from '@prisma/client';

// Shared authorization predicates for course-scoped resources (videos, cues,
// attempts). Previously each service inlined the same "admin? owner?
// collaborator? enrolled?" check, which drifted (enrollments only matter for
// read-access; writes never consult them). Centralising here keeps the IDOR
// gate in one place so new endpoints can't forget a branch.

/**
 * Minimal shape of the course-relation that the Prisma selectors in
 * video/cue/attempt services produce. Uses `where: { userId }` to narrow
 * collaborators/enrollments to "does the caller appear?" so any non-empty
 * array means membership.
 */
export interface CourseAuthContext {
  ownerId: string;
  collaborators: { userId: string }[];
  enrollments?: { userId: string }[];
}

export type CourseAccessLevel = 'READ' | 'WRITE';

/**
 * Decides whether the caller may access a resource scoped to `course`.
 *
 * - `READ`: admin, course owner, collaborator, or enrolled learner.
 * - `WRITE`: admin, course owner, or collaborator (enrollment alone is not
 *   enough — a learner can't mutate cues just because they signed up).
 *
 * Pass `ctx.enrollments = []` when the selector didn't fetch enrollments;
 * the function treats a missing array as "no enrollment evidence", which is
 * safe because READ still requires one of the other three branches to pass.
 */
export function hasCourseAccess(
  role: Role,
  userId: string,
  course: CourseAuthContext,
  level: CourseAccessLevel,
): boolean {
  if (role === 'ADMIN') return true;
  if (course.ownerId === userId) return true;
  if (course.collaborators.length > 0) return true;
  if (level === 'READ' && (course.enrollments?.length ?? 0) > 0) return true;
  return false;
}
