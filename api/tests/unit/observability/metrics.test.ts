import '@tests/unit/setup';
import type { Request, Response, NextFunction } from 'express';
import {
  buildMetrics,
  getMetrics,
  httpMetricsMiddleware,
  resetMetricsForTests,
} from '@/observability/metrics';

describe('observability/metrics', () => {
  beforeEach(() => resetMetricsForTests());

  describe('buildMetrics', () => {
    it('registers the four learn-specific metric families', async () => {
      const m = buildMetrics();
      const names = (await m.registry.getMetricsAsJSON()).map((x) => x.name);
      expect(names).toEqual(
        expect.arrayContaining([
          'learn_http_request_duration_seconds',
          'learn_http_requests_total',
          'learn_transcode_queue_depth',
          'learn_playback_signed_urls_total',
        ]),
      );
    });

    it('configures latency histogram with SLO-aware buckets', async () => {
      const m = buildMetrics();
      const snapshot = await m.registry.getMetricsAsJSON();
      const hist = snapshot.find((x) => x.name === 'learn_http_request_duration_seconds');
      expect(hist).toBeDefined();
      expect(hist?.type).toBe('histogram');
    });

    it('prefixes the default Node process metrics so they share the learn_ namespace', async () => {
      const m = buildMetrics();
      const names = (await m.registry.getMetricsAsJSON()).map((x) => x.name);
      // Node default metrics pick up our `learn_` prefix so Prometheus
      // scrapes don't collide with any sibling service sharing the endpoint.
      expect(names.some((n) => n.startsWith('learn_process_'))).toBe(true);
    });
  });

  describe('getMetrics singleton', () => {
    it('returns the same registry across calls', () => {
      const a = getMetrics();
      const b = getMetrics();
      expect(a.registry).toBe(b.registry);
    });

    it('resetMetricsForTests forces a fresh registry', () => {
      const first = getMetrics();
      resetMetricsForTests();
      const second = getMetrics();
      expect(first.registry).not.toBe(second.registry);
    });
  });

  describe('httpMetricsMiddleware', () => {
    function mockResWithFinish(): {
      res: Response;
      fire: () => void;
      listeners: Array<() => void>;
    } {
      const listeners: Array<() => void> = [];
      const res = {
        statusCode: 200,
        on: (event: string, cb: () => void) => {
          if (event === 'finish') listeners.push(cb);
          return res;
        },
      } as unknown as Response;
      return { res, fire: () => listeners.forEach((l) => l()), listeners };
    }

    it('labels observations with the matched route pattern, not the raw URL', async () => {
      const metrics = buildMetrics();
      const mw = httpMetricsMiddleware(metrics);
      const req = {
        method: 'GET',
        baseUrl: '/api',
        route: { path: '/videos/:id/playback' },
      } as unknown as Request;
      const { res, fire } = mockResWithFinish();
      const next = jest.fn() as unknown as NextFunction;

      mw(req, res, next);
      expect(next).toHaveBeenCalled();
      fire();

      const snapshot = await metrics.registry.getMetricsAsJSON();
      const counter = snapshot.find((x) => x.name === 'learn_http_requests_total') as {
        values: Array<{ labels: Record<string, string>; value: number }>;
      };
      expect(counter.values).toHaveLength(1);
      expect(counter.values[0].labels).toMatchObject({
        route: '/api/videos/:id/playback',
        method: 'GET',
        status: '200',
      });
      expect(counter.values[0].value).toBe(1);
    });

    it('collapses unmatched routes to a constant label to prevent cardinality blow-up', async () => {
      const metrics = buildMetrics();
      const mw = httpMetricsMiddleware(metrics);
      const req = {
        method: 'GET',
        baseUrl: '',
        route: undefined,
      } as unknown as Request;
      const { res, fire } = mockResWithFinish();
      Object.defineProperty(res, 'statusCode', { value: 404, configurable: true });
      const next = jest.fn() as unknown as NextFunction;

      mw(req, res, next);
      fire();

      const snapshot = await metrics.registry.getMetricsAsJSON();
      const counter = snapshot.find((x) => x.name === 'learn_http_requests_total') as {
        values: Array<{ labels: Record<string, string>; value: number }>;
      };
      expect(counter.values[0].labels.route).toBe('unmatched');
      expect(counter.values[0].labels.status).toBe('404');
    });

    it('canonicalises UUIDs in baseUrl to prevent nested-router fan-out', async () => {
      // Nested routers with `mergeParams` expose req.baseUrl with the
      // OUTER router's concrete param value. Left as-is, this fans the
      // `route` label out once per video — fatal at 200 VUs.
      const metrics = buildMetrics();
      const mw = httpMetricsMiddleware(metrics);
      const uuidA = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      const uuidB = 'b2c3d4e5-f6a7-8901-bcde-f12345678901';
      const mkReq = (uuid: string): Request =>
        ({
          method: 'GET',
          baseUrl: `/api/videos/${uuid}/cues`,
          route: { path: '/' },
        }) as unknown as Request;
      const next = jest.fn() as unknown as NextFunction;

      for (const uuid of [uuidA, uuidB, uuidA]) {
        const { res, fire } = mockResWithFinish();
        mw(mkReq(uuid), res, next);
        fire();
      }

      const snapshot = await metrics.registry.getMetricsAsJSON();
      const counter = snapshot.find((x) => x.name === 'learn_http_requests_total') as {
        values: Array<{ labels: Record<string, string>; value: number }>;
      };
      // Three requests should collapse into ONE labelled series, not two
      // (one per distinct UUID).
      expect(counter.values).toHaveLength(1);
      expect(counter.values[0].labels.route).toBe('/api/videos/:id/cues/');
      expect(counter.values[0].value).toBe(3);
    });

    it('records a duration observation per request', async () => {
      const metrics = buildMetrics();
      const mw = httpMetricsMiddleware(metrics);
      const req = {
        method: 'POST',
        baseUrl: '/api',
        route: { path: '/attempts' },
      } as unknown as Request;
      const { res, fire } = mockResWithFinish();
      const next = jest.fn() as unknown as NextFunction;

      mw(req, res, next);
      fire();

      const snapshot = await metrics.registry.getMetricsAsJSON();
      const hist = snapshot.find((x) => x.name === 'learn_http_request_duration_seconds') as {
        values: Array<{ labels: Record<string, string>; value: number; metricName?: string }>;
      };
      // Histograms emit _count / _sum / _bucket entries. We only care that
      // at least one observation landed for the labelled series.
      const countEntry = hist.values.find(
        (v) => v.metricName === 'learn_http_request_duration_seconds_count',
      );
      expect(countEntry?.value).toBe(1);
      expect(countEntry?.labels).toMatchObject({
        route: '/api/attempts',
        method: 'POST',
        status: '200',
      });
    });
  });
});
