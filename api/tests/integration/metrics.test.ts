import request from 'supertest';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { resetMetricsForTests } from '@/observability/metrics';

/**
 * These tests deliberately bypass the cached `getTestApp()` helper because
 * `createApp()` reads `env.METRICS_ENABLED` at construction time, and we
 * need to exercise both the "flag on" and "flag off" branches in the same
 * test run.
 *
 * We manipulate `env.METRICS_ENABLED` before re-importing `@/app` to force
 * a fresh module graph, then reset the metrics singleton so the two apps
 * don't share a registry.
 */
describe('GET /metrics', () => {
  afterAll(async () => {
    await closeConnections();
  });

  it('returns 404 when METRICS_ENABLED is false (default)', async () => {
    jest.resetModules();
    resetMetricsForTests();
    // Re-import after resetModules so env snapshot is re-evaluated.
    const envMod = await import('@/config/env');
    (envMod.env as unknown as { METRICS_ENABLED: boolean }).METRICS_ENABLED = false;
    const appMod = await import('@/app');
    const res = await request(appMod.createApp()).get('/metrics');
    expect(res.status).toBe(404);
  });

  it('serves prom-text when METRICS_ENABLED is true and records an observation', async () => {
    jest.resetModules();
    resetMetricsForTests();
    const envMod = await import('@/config/env');
    (envMod.env as unknown as { METRICS_ENABLED: boolean }).METRICS_ENABLED = true;
    const appMod = await import('@/app');
    const app = appMod.createApp();

    // Trigger a handled request so the middleware records something.
    await request(app).get('/health/liveness');

    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/^text\/plain/);
    expect(res.text).toContain('learn_http_requests_total');
    expect(res.text).toContain('learn_http_request_duration_seconds');
    expect(res.text).toContain('learn_playback_signed_urls_total');
    expect(res.text).toContain('learn_transcode_queue_depth');
    // Flip the flag back so the rest of the suite (if this file is
    // re-ordered) sees the default.
    (envMod.env as unknown as { METRICS_ENABLED: boolean }).METRICS_ENABLED = false;
  });
});
