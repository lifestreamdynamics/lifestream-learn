import '@tests/unit/setup';
import { bcp47LanguageSchema, videoCaptionParamsSchema, videoIdOnlyParamsSchema, videoCaptionQuerySchema } from '@/validators/caption.validators';

const VALID_UUID = '11111111-1111-4111-8111-111111111111';
const SHORT_UUID = 'not-a-uuid';

describe('caption.validators', () => {
  describe('bcp47LanguageSchema', () => {
    const accepts = ['en', 'zh-CN', 'zh-Hant', 'pt-BR', 'fr', 'ar', 'de-AT', 'es-419'];
    const rejects = ['EN', 'english', 'en-us', 'en_US', '', 'en--US'];

    test.each(accepts)('accepts %s', (lang) => {
      expect(bcp47LanguageSchema.safeParse(lang).success).toBe(true);
    });

    test.each(rejects)('rejects %s', (lang) => {
      expect(bcp47LanguageSchema.safeParse(lang).success).toBe(false);
    });
  });

  describe('videoCaptionParamsSchema', () => {
    it('accepts a valid videoId + language', () => {
      const result = videoCaptionParamsSchema.safeParse({ videoId: VALID_UUID, language: 'en' });
      expect(result.success).toBe(true);
    });

    it('rejects an invalid UUID', () => {
      const result = videoCaptionParamsSchema.safeParse({ videoId: SHORT_UUID, language: 'en' });
      expect(result.success).toBe(false);
    });

    it('rejects an invalid language', () => {
      const result = videoCaptionParamsSchema.safeParse({ videoId: VALID_UUID, language: 'EN' });
      expect(result.success).toBe(false);
    });
  });

  describe('videoIdOnlyParamsSchema', () => {
    it('accepts a valid videoId', () => {
      expect(videoIdOnlyParamsSchema.safeParse({ videoId: VALID_UUID }).success).toBe(true);
    });

    it('rejects an invalid videoId', () => {
      expect(videoIdOnlyParamsSchema.safeParse({ videoId: SHORT_UUID }).success).toBe(false);
    });
  });

  describe('videoCaptionQuerySchema', () => {
    it('accepts language with setDefault "1" → true', () => {
      const result = videoCaptionQuerySchema.parse({ language: 'en', setDefault: '1' });
      expect(result).toEqual({ language: 'en', setDefault: true });
    });

    it('accepts language with setDefault "true" → true', () => {
      const result = videoCaptionQuerySchema.parse({ language: 'pt-BR', setDefault: 'true' });
      expect(result).toEqual({ language: 'pt-BR', setDefault: true });
    });

    it('leaves setDefault undefined when omitted', () => {
      const result = videoCaptionQuerySchema.parse({ language: 'fr' });
      expect(result.setDefault).toBeUndefined();
    });

    it('coerces falsy string to false', () => {
      const result = videoCaptionQuerySchema.parse({ language: 'de-AT', setDefault: '0' });
      expect(result.setDefault).toBe(false);
    });

    it('rejects an invalid language', () => {
      const result = videoCaptionQuerySchema.safeParse({ language: 'en_US' });
      expect(result.success).toBe(false);
    });
  });
});
