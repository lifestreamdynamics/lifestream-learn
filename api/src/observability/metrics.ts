import type { RequestHandler } from 'express';
import {
  Counter,
  Gauge,
  Histogram,
  Registry,
  collectDefaultMetrics,
} from 'prom-client';

/**
 * Metrics registry for learn-api. Slice G1 ships four first-class series;
 * Phase 8 (ADR 0007) adds one for JWT dual-secret rotation:
 *
 *   learn_http_request_duration_seconds   histogram (route, method, status)
 *   learn_http_requests_total             counter   (route, method, status)
 *   learn_transcode_queue_depth           gauge     (state)
 *   learn_playback_signed_urls_total      counter
 *   learn_jwt_verify_with_previous_total  counter   (tokenType)
 *
 * Every exported symbol is safe to import even when METRICS_ENABLED is
 * false — increments against the counters/gauges just accumulate in memory
 * and are never scraped. That lets call sites (hls-signer, queue-depth
 * sampler, JWT verify) stay free of env-var checks.
 *
 * High-cardinality guard: the HTTP middleware labels by `req.route.path`
 * (the Express pattern, e.g. `/api/videos/:id/playback`), NOT the raw URL.
 * Unmatched routes collapse to the string `unmatched` to prevent a
 * crawler-spammed 404 wave from exploding the series count.
 *
 * `learn_jwt_verify_with_previous_total` is the operator's signal that a
 * dual-secret rotation is still being relied on — increments while the
 * rotation window is open, and should drop to zero before *_PREVIOUS is
 * unset (ADR 0007 step 3). Labelled by `tokenType` (`access` | `refresh`)
 * so the operator can confirm BOTH secrets have stopped catching live
 * traffic before retiring them.
 */

export interface LearnMetrics {
  registry: Registry;
  httpRequestDuration: Histogram<'route' | 'method' | 'status'>;
  httpRequestsTotal: Counter<'route' | 'method' | 'status'>;
  transcodeQueueDepth: Gauge<'state'>;
  playbackSignedUrlsTotal: Counter<string>;
  jwtVerifyWithPreviousTotal: Counter<'tokenType'>;
}

let cached: LearnMetrics | null = null;

export function buildMetrics(): LearnMetrics {
  const registry = new Registry();
  registry.setDefaultLabels({ service: 'learn-api' });
  collectDefaultMetrics({ register: registry, prefix: 'learn_' });

  const httpRequestDuration = new Histogram({
    name: 'learn_http_request_duration_seconds',
    help: 'HTTP request latency in seconds, labelled by route pattern, method, and status.',
    labelNames: ['route', 'method', 'status'] as const,
    // Buckets chosen to span our SLOs: 5ms..5s with enough resolution around
    // the p95<500ms target from IMPLEMENTATION_PLAN.md Phase 7.
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
    registers: [registry],
  });

  const httpRequestsTotal = new Counter({
    name: 'learn_http_requests_total',
    help: 'Total HTTP requests handled, labelled by route pattern, method, and status.',
    labelNames: ['route', 'method', 'status'] as const,
    registers: [registry],
  });

  const transcodeQueueDepth = new Gauge({
    name: 'learn_transcode_queue_depth',
    help: 'Number of BullMQ jobs in the transcode queue by state (waiting, active, failed, delayed).',
    labelNames: ['state'] as const,
    registers: [registry],
  });

  const playbackSignedUrlsTotal = new Counter({
    name: 'learn_playback_signed_urls_total',
    help: 'Playback URLs signed by hls-signer. Incremented once per successful signing call.',
    registers: [registry],
  });

  // Phase 8 / ADR 0007 — incremented every time a JWT is accepted only
  // after falling back to JWT_*_SECRET_PREVIOUS. A non-zero value means
  // the rotation window is still load-bearing; the operator should not
  // unset *_PREVIOUS until this counter has been flat at zero for one
  // JWT_REFRESH_TTL.
  const jwtVerifyWithPreviousTotal = new Counter({
    name: 'learn_jwt_verify_with_previous_total',
    help: 'JWT verifications that succeeded only via the *_PREVIOUS secret. Indicates the dual-secret rotation window is still being used.',
    labelNames: ['tokenType'] as const,
    registers: [registry],
  });

  return {
    registry,
    httpRequestDuration,
    httpRequestsTotal,
    transcodeQueueDepth,
    playbackSignedUrlsTotal,
    jwtVerifyWithPreviousTotal,
  };
}

export function getMetrics(): LearnMetrics {
  if (!cached) cached = buildMetrics();
  return cached;
}

/**
 * Reset the singleton — test-only. In production the registry lives for the
 * lifetime of the process.
 */
export function resetMetricsForTests(): void {
  cached = null;
}

// Canonical UUID pattern. When nested routers `mergeParams`, `req.baseUrl`
// carries the CONCRETE param value (the outer router's matched segment),
// not a pattern. Without this substitution, a UUID-keyed nested route
// like `/api/videos/<uuid>/cues/` fans out the `route` label once per
// video — catastrophic at 200 VUs × M videos.
const UUID_RE = /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi;

function canonicaliseRoute(baseUrl: string, routePath: string | undefined): string {
  if (!routePath) return 'unmatched';
  const combined = `${baseUrl}${routePath}`;
  if (!combined) return 'unmatched';
  return combined.replace(UUID_RE, ':id');
}

/**
 * Express middleware that records duration + count for every response.
 * Registered unconditionally when `METRICS_ENABLED=true`; when the flag is
 * off we never mount it (see app.ts / index.ts).
 */
export function httpMetricsMiddleware(metrics: LearnMetrics): RequestHandler {
  return (req, res, next) => {
    const endTimer = metrics.httpRequestDuration.startTimer();
    res.on('finish', () => {
      // req.route is only populated after the route handler runs. For routes
      // that didn't match (and for the 404 middleware) it's undefined — we
      // collapse those to a constant label so 404-spamming crawlers can't
      // explode cardinality.
      const route = canonicaliseRoute(req.baseUrl, req.route?.path);
      const labels = {
        route,
        method: req.method,
        status: String(res.statusCode),
      };
      endTimer(labels);
      metrics.httpRequestsTotal.inc(labels);
    });
    next();
  };
}
