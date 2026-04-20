import { Router } from 'express';
import { getMetrics } from '@/observability/metrics';

export const metricsRouter = Router();

/**
 * Prometheus text-exposition endpoint. Mounted only when METRICS_ENABLED is
 * true — see app.ts. The route stays on the API's port (:3011) so we don't
 * claim a second port inside the shared-resource allocation.
 */
metricsRouter.get('/', async (_req, res, next) => {
  try {
    const { registry } = getMetrics();
    res.setHeader('Content-Type', registry.contentType);
    res.status(200).send(await registry.metrics());
  } catch (err) {
    next(err);
  }
});
