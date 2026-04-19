import '@tests/unit/setup';
import {
  createEnrollmentBodySchema,
  enrollmentCourseIdParamsSchema,
  updateEnrollmentProgressBodySchema,
} from '@/validators/enrollment.validators';

describe('enrollment.validators', () => {
  it('create rejects non-uuid', () => {
    expect(() => createEnrollmentBodySchema.parse({ courseId: 'nope' })).toThrow();
  });

  it('create accepts uuid', () => {
    expect(() =>
      createEnrollmentBodySchema.parse({
        courseId: '11111111-1111-4111-8111-111111111111',
      }),
    ).not.toThrow();
  });

  it('progress requires lastPosMs >= 0', () => {
    expect(() =>
      updateEnrollmentProgressBodySchema.parse({
        lastVideoId: '11111111-1111-4111-8111-111111111111',
        lastPosMs: -1,
      }),
    ).toThrow();
  });

  it('progress coerces stringy lastPosMs', () => {
    const p = updateEnrollmentProgressBodySchema.parse({
      lastVideoId: '11111111-1111-4111-8111-111111111111',
      lastPosMs: '5000',
    });
    expect(p.lastPosMs).toBe(5000);
  });

  it('courseId param requires uuid', () => {
    expect(() => enrollmentCourseIdParamsSchema.parse({ courseId: 'x' })).toThrow();
  });
});
