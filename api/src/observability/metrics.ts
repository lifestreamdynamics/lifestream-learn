import type { RequestHandler } from 'express';
import {
  Counter,
  Gauge,
  Histogram,
  Registry,
  collectDefaultMetrics,
} from 'prom-client';

/**
 * Metrics registry for learn-api. Slice G1 ships four first-class series:
 *
 *   learn_http_request_duration_seconds   histogram (route, method, status)
 *   learn_http_requests_total             counter   (route, method, status)
 *   learn_transcode_queue_depth           gauge     (state)
 *   learn_playback_signed_urls_total      counter
 *
 * Every exported symbol is safe to import even when METRICS_ENABLED is
 * false — increments against the counters/gauges just accumulate in memory
 * and are never scraped. That lets call sites (hls-signer, queue-depth
 * sampler) stay free of env-var checks.
 *
 * High-cardinality guard: the HTTP middleware labels by `req.route.path`
 * (the Express pattern, e.g. `/api/videos/:id/playback`), NOT the raw URL.
 * Unmatched routes collapse to the string `unmatched` to prevent a
 * crawler-spammed 404 wave from exploding the series count.
 */

export interface LearnMetrics {
  registry: Registry;
  httpRequestDuration: Histogram<'route' | 'method' | 'status'>;
  httpRequestsTotal: Counter<'route' | 'method' | 'status'>;
  transcodeQueueDepth: Gauge<'state'>;
  playbackSignedUrlsTotal: Counter<string>;
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

  return {
    registry,
    httpRequestDuration,
    httpRequestsTotal,
    transcodeQueueDepth,
    playbackSignedUrlsTotal,
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
      const routePattern = req.route?.path ?? 'unmatched';
      // The baseUrl (e.g. "/api") prefixes the sub-router's local pattern
      // to give us the useful `/api/videos/:id/playback` view.
      const route = `${req.baseUrl}${routePattern}` || 'unmatched';
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
