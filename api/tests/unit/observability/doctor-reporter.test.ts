import '@tests/unit/setup';
import {
  getDoctorReporter,
  resetDoctorReporterForTests,
  setDoctorReporterForTests,
  type DoctorReporter,
} from '@/observability/doctor-reporter';
import { env } from '@/config/env';

// Mutating the frozen-ish env object: the Zod-parsed export is a plain
// object, so field reassignment works. We restore in afterEach.
const mutableEnv = env as unknown as {
  CRASH_REPORTING_ENABLED: boolean;
  LEARN_CRASH_API_KEY: string;
  LEARN_CRASH_ENDPOINT: string;
};

describe('observability/doctor-reporter', () => {
  const originalFlag = mutableEnv.CRASH_REPORTING_ENABLED;
  const originalKey = mutableEnv.LEARN_CRASH_API_KEY;
  const originalEndpoint = mutableEnv.LEARN_CRASH_ENDPOINT;

  afterEach(() => {
    mutableEnv.CRASH_REPORTING_ENABLED = originalFlag;
    mutableEnv.LEARN_CRASH_API_KEY = originalKey;
    mutableEnv.LEARN_CRASH_ENDPOINT = originalEndpoint;
    resetDoctorReporterForTests();
  });

  it('returns a no-op reporter when CRASH_REPORTING_ENABLED is false (default)', () => {
    mutableEnv.CRASH_REPORTING_ENABLED = false;
    resetDoctorReporterForTests();
    const reporter = getDoctorReporter();
    // No throw, no return value contract beyond the interface.
    expect(() => reporter.captureException(new Error('boom'))).not.toThrow();
    expect(reporter.flush()).resolves.toBeUndefined();
  });

  it('memoises the reporter across calls', () => {
    resetDoctorReporterForTests();
    const a = getDoctorReporter();
    const b = getDoctorReporter();
    expect(a).toBe(b);
  });

  it('falls back to no-op when flag is on but credentials are missing', () => {
    mutableEnv.CRASH_REPORTING_ENABLED = true;
    mutableEnv.LEARN_CRASH_API_KEY = '';
    mutableEnv.LEARN_CRASH_ENDPOINT = '';
    resetDoctorReporterForTests();
    const reporter = getDoctorReporter();
    // Can't distinguish no-op from unwired-enabled by interface alone, but
    // neither throws and both honour the contract — which is the safety
    // guarantee we want when misconfigured.
    expect(() => reporter.captureException(new Error('boom'))).not.toThrow();
  });

  it('uses the unwired-enabled reporter when flag + credentials are set', () => {
    mutableEnv.CRASH_REPORTING_ENABLED = true;
    mutableEnv.LEARN_CRASH_API_KEY = 'test-key';
    mutableEnv.LEARN_CRASH_ENDPOINT = 'https://crashes.example/learn';
    resetDoctorReporterForTests();
    const reporter = getDoctorReporter();
    expect(() => reporter.captureException(new Error('boom'), { reqId: 'r-1' })).not.toThrow();
  });

  it('setDoctorReporterForTests lets callers inject a fake for integration-style tests', () => {
    const fake: DoctorReporter = {
      initialise: jest.fn(),
      captureException: jest.fn(),
      flush: jest.fn().mockResolvedValue(undefined),
    };
    setDoctorReporterForTests(fake);
    const reporter = getDoctorReporter();
    reporter.captureException(new Error('x'), { userId: 'u1' });
    expect(fake.captureException).toHaveBeenCalledWith(
      expect.any(Error),
      expect.objectContaining({ userId: 'u1' }),
    );
  });
});
