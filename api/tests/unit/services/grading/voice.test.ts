import '@tests/unit/setup';
import { gradeVoice } from '@/services/grading/voice';
import { NotImplementedError } from '@/utils/errors';

describe('gradeVoice', () => {
  it('throws NotImplementedError', () => {
    expect(() => gradeVoice()).toThrow(NotImplementedError);
  });

  it('message identifies VOICE', () => {
    expect(() => gradeVoice()).toThrow(/VOICE/);
  });
});
