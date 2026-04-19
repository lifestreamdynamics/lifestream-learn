import '@tests/unit/setup';
import { ZodError } from 'zod';
import {
  createVideoSchema,
  videoIdParamsSchema,
  tusdHookBodySchema,
} from '@/validators/video.validators';

const VALID_UUID = '11111111-1111-4111-8111-111111111111';

describe('video.validators', () => {
  describe('createVideoSchema', () => {
    it('accepts a valid body', () => {
      const parsed = createVideoSchema.parse({
        courseId: VALID_UUID,
        title: 'Intro to Lifting',
        orderIndex: 0,
      });
      expect(parsed).toEqual({
        courseId: VALID_UUID,
        title: 'Intro to Lifting',
        orderIndex: 0,
      });
    });

    it('coerces a numeric string for orderIndex', () => {
      const parsed = createVideoSchema.parse({
        courseId: VALID_UUID,
        title: 'A',
        orderIndex: '7',
      });
      expect(parsed.orderIndex).toBe(7);
    });

    it('trims the title', () => {
      const parsed = createVideoSchema.parse({
        courseId: VALID_UUID,
        title: '  spacey  ',
        orderIndex: 1,
      });
      expect(parsed.title).toBe('spacey');
    });

    it('rejects when courseId is missing', () => {
      expect(() =>
        createVideoSchema.parse({ title: 'X', orderIndex: 0 } as unknown),
      ).toThrow(ZodError);
    });

    it('rejects when courseId is not a UUID', () => {
      expect(() =>
        createVideoSchema.parse({ courseId: 'not-a-uuid', title: 'X', orderIndex: 0 }),
      ).toThrow(ZodError);
    });

    it('rejects an empty title', () => {
      expect(() =>
        createVideoSchema.parse({ courseId: VALID_UUID, title: '', orderIndex: 0 }),
      ).toThrow(ZodError);
    });

    it('rejects a negative orderIndex', () => {
      expect(() =>
        createVideoSchema.parse({ courseId: VALID_UUID, title: 'X', orderIndex: -1 }),
      ).toThrow(ZodError);
    });

    it('rejects a non-integer orderIndex', () => {
      expect(() =>
        createVideoSchema.parse({ courseId: VALID_UUID, title: 'X', orderIndex: 1.5 }),
      ).toThrow(ZodError);
    });
  });

  describe('videoIdParamsSchema', () => {
    it('accepts a UUID', () => {
      expect(videoIdParamsSchema.parse({ id: VALID_UUID })).toEqual({ id: VALID_UUID });
    });

    it('rejects a non-UUID', () => {
      expect(() => videoIdParamsSchema.parse({ id: 'abc' })).toThrow(ZodError);
    });
  });

  describe('tusdHookBodySchema', () => {
    it('accepts a valid pre-finish body and defaults MetaData to {}', () => {
      const parsed = tusdHookBodySchema.parse({
        Type: 'pre-finish',
        Event: { Upload: { ID: 'tus-upload-id', MetaData: { videoId: VALID_UUID } } },
      });
      expect(parsed.Type).toBe('pre-finish');
      expect(parsed.Event.Upload.MetaData).toEqual({ videoId: VALID_UUID });
    });

    it('defaults MetaData to {} when omitted', () => {
      const parsed = tusdHookBodySchema.parse({
        Type: 'post-finish',
        Event: { Upload: { ID: 'tus-upload-id' } },
      });
      expect(parsed.Event.Upload.MetaData).toEqual({});
    });

    it('rejects a malformed body (missing Event)', () => {
      expect(() => tusdHookBodySchema.parse({ Type: 'pre-finish' })).toThrow(ZodError);
    });

    it('rejects a body where Type is not a string', () => {
      expect(() =>
        tusdHookBodySchema.parse({ Type: 42, Event: { Upload: { ID: 'x' } } }),
      ).toThrow(ZodError);
    });
  });
});
