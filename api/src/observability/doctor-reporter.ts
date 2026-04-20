import { env } from '@/config/env';
import { logger } from '@/config/logger';

/**
 * Crash-reporting seam. Mirrors the Flutter `CrashReporter` in
 * `app/lib/core/crash/crash_reporter.dart`: env-gated default-off, a single
 * capture entry-point, safe to import from anywhere (disabled path is a
 * no-op).
 *
 * Today this file is intentionally a no-op with a documented inner SDK
 * slot. `@lifestream/doctor-node` is the target — once the ecosystem
 * publishes it, swap `createDoctorReporter` for a constructor that forwards
 * captures to the SDK. Until then, the seam exists so call sites can be
 * wired without waiting on an upstream package (and so we avoid pulling in
 * Sentry, which would break the AGPL/open-source symmetry we chose in
 * ADR 0001).
 *
 * Flag semantics (see api/src/config/env.ts):
 *   CRASH_REPORTING_ENABLED=false (default)  → captureException is a no-op
 *     beyond a debug-level log line; no network call.
 *   CRASH_REPORTING_ENABLED=true             → LEARN_CRASH_API_KEY and
 *     LEARN_CRASH_ENDPOINT must be set; the inner SDK is invoked if wired.
 *     If the inner SDK hook is still unimplemented (today's state), we log
 *     a warn instead of silently swallowing so the operator notices.
 */

export interface CaptureContext {
  /** Pino-http request id, if the capture happened inside an HTTP handler. */
  reqId?: string | number;
  /** Authenticated user id, when available. */
  userId?: string;
  /** Free-form tags — keep the cardinality low. */
  tags?: Record<string, string>;
}

export interface DoctorReporter {
  initialise(): void;
  captureException(err: unknown, ctx?: CaptureContext): void;
  flush(): Promise<void>;
}

class NoopReporter implements DoctorReporter {
  initialise(): void {
    logger.debug({ reporter: 'noop' }, 'doctor-reporter initialise (disabled)');
  }
  captureException(err: unknown, ctx?: CaptureContext): void {
    logger.debug({ err, ctx, reporter: 'noop' }, 'doctor-reporter capture (disabled)');
  }
  async flush(): Promise<void> {
    // No-op: nothing queued.
  }
}

class UnwiredEnabledReporter implements DoctorReporter {
  initialise(): void {
    logger.warn(
      { endpoint: env.LEARN_CRASH_ENDPOINT },
      'doctor-reporter is ENABLED but no inner SDK is wired — captures will be logged only. Wire @lifestream/doctor-node in src/observability/doctor-reporter.ts once published.',
    );
  }
  captureException(err: unknown, ctx?: CaptureContext): void {
    logger.warn(
      { err, ctx, reporter: 'unwired' },
      'doctor-reporter capture — forwarding not yet implemented; see src/observability/doctor-reporter.ts',
    );
  }
  async flush(): Promise<void> {
    // No-op until an inner SDK with a drain() method is wired.
  }
}

let reporter: DoctorReporter | null = null;

export function getDoctorReporter(): DoctorReporter {
  if (reporter) return reporter;
  if (!env.CRASH_REPORTING_ENABLED) {
    reporter = new NoopReporter();
  } else if (!env.LEARN_CRASH_API_KEY || !env.LEARN_CRASH_ENDPOINT) {
    // Misconfiguration: flag flipped without the required secrets. Fall
    // back to the no-op rather than crashing the process, but log at warn
    // so the operator sees it on startup.
    logger.warn(
      {
        hasKey: Boolean(env.LEARN_CRASH_API_KEY),
        hasEndpoint: Boolean(env.LEARN_CRASH_ENDPOINT),
      },
      'CRASH_REPORTING_ENABLED=true but LEARN_CRASH_API_KEY / LEARN_CRASH_ENDPOINT missing — falling back to no-op',
    );
    reporter = new NoopReporter();
  } else {
    reporter = new UnwiredEnabledReporter();
  }
  reporter.initialise();
  return reporter;
}

/** Test-only: force a fresh reporter based on the current env snapshot. */
export function resetDoctorReporterForTests(): void {
  reporter = null;
}

/** Test-only: inject a fake reporter for the duration of a test. */
export function setDoctorReporterForTests(next: DoctorReporter | null): void {
  reporter = next;
}
