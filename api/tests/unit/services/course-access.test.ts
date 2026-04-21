import '@tests/unit/setup';
import { hasCourseAccess, type CourseAuthContext } from '@/services/course-access';

describe('hasCourseAccess', () => {
  const base: CourseAuthContext = {
    ownerId: 'owner-1',
    collaborators: [],
    enrollments: [],
  };

  describe('ADMIN', () => {
    it('allows ADMIN unconditionally for READ', () => {
      expect(hasCourseAccess('ADMIN', 'random-admin', base, 'READ')).toBe(true);
    });
    it('allows ADMIN unconditionally for WRITE', () => {
      expect(hasCourseAccess('ADMIN', 'random-admin', base, 'WRITE')).toBe(true);
    });
  });

  describe('owner', () => {
    it('allows course owner for READ', () => {
      expect(hasCourseAccess('LEARNER', 'owner-1', base, 'READ')).toBe(true);
    });
    it('allows course owner for WRITE (role-agnostic)', () => {
      expect(hasCourseAccess('LEARNER', 'owner-1', base, 'WRITE')).toBe(true);
    });
  });

  describe('collaborator', () => {
    const withCollab: CourseAuthContext = {
      ...base,
      collaborators: [{ userId: 'alice' }],
    };
    it('allows collaborator for READ', () => {
      expect(hasCourseAccess('LEARNER', 'alice', withCollab, 'READ')).toBe(true);
    });
    it('allows collaborator for WRITE', () => {
      expect(hasCourseAccess('LEARNER', 'alice', withCollab, 'WRITE')).toBe(true);
    });
  });

  describe('enrolled learner', () => {
    const enrolled: CourseAuthContext = {
      ...base,
      enrollments: [{ userId: 'bob' }],
    };
    it('allows enrolled learner for READ', () => {
      expect(hasCourseAccess('LEARNER', 'bob', enrolled, 'READ')).toBe(true);
    });
    it('REJECTS enrolled learner for WRITE (IDOR guard)', () => {
      // A learner who is merely enrolled must NOT be able to mutate cues,
      // even on a course they're watching. This is the key divergence
      // between READ and WRITE that the helper enforces.
      expect(hasCourseAccess('LEARNER', 'bob', enrolled, 'WRITE')).toBe(false);
    });
  });

  describe('stranger', () => {
    it('denies READ', () => {
      expect(hasCourseAccess('LEARNER', 'stranger', base, 'READ')).toBe(false);
    });
    it('denies WRITE', () => {
      expect(hasCourseAccess('LEARNER', 'stranger', base, 'WRITE')).toBe(false);
    });
  });

  describe('context without enrollments', () => {
    // Writers don't select enrollments from Prisma — ensure the helper
    // doesn't crash when enrollments is undefined.
    const noEnrollmentsField: CourseAuthContext = {
      ownerId: 'owner-1',
      collaborators: [],
      // `enrollments` intentionally omitted
    };
    it('handles missing enrollments field gracefully for WRITE', () => {
      expect(hasCourseAccess('LEARNER', 'stranger', noEnrollmentsField, 'WRITE')).toBe(false);
      expect(hasCourseAccess('LEARNER', 'owner-1', noEnrollmentsField, 'WRITE')).toBe(true);
    });
    it('handles missing enrollments field gracefully for READ', () => {
      expect(hasCourseAccess('LEARNER', 'stranger', noEnrollmentsField, 'READ')).toBe(false);
    });
  });
});
