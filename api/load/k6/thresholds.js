// SLO thresholds for the learner-session k6 scenario, derived from
// IMPLEMENTATION_PLAN.md §5 Phase 7 exit criteria:
//
//   API p95  < 500ms
//   HLS master TTFB p95  < 1000ms
//   Error rate           < 1%
//
// The scenario script tags each request group with `endpoint=api` or
// `endpoint=hls-master` / `endpoint=hls-segment` so these thresholds can
// target the right buckets without a cardinality explosion.
//
// k6 aborts the run on threshold breach (abortOnFail) only where the SLO
// is hard — error rate. Latency breaches still surface in the summary and
// fail the exit code but let the session complete so we can see the full
// p50/p95/p99 distribution.

export const thresholds = {
  // All API (non-HLS) calls.
  'http_req_duration{endpoint:api}': [
    { threshold: 'p(95)<500', abortOnFail: false },
  ],
  // Signed master playlist fetch behind nginx secure_link.
  'http_req_duration{endpoint:hls-master}': [
    { threshold: 'p(95)<1000', abortOnFail: false },
  ],
  // Segment fetches — same nginx path, lower latency expected since the
  // segments are single-byte placeholders during baseline runs.
  'http_req_duration{endpoint:hls-segment}': [
    { threshold: 'p(95)<1000', abortOnFail: false },
  ],
  // Overall error rate across all requests.
  http_req_failed: [{ threshold: 'rate<0.01', abortOnFail: true }],
};
