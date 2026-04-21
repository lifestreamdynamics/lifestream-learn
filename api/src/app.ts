import express, { type Express } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import pinoHttp from 'pino-http';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { mountSwagger } from '@/config/swagger';
import { healthRouter } from '@/routes/health.routes';
import { metricsRouter } from '@/routes/metrics.routes';
import { apiRouter } from '@/routes/index';
import { internalHooksRouter } from '@/routes/internal-hooks.routes';
import { errorHandler } from '@/middleware/error-handler';
import { getMetrics, httpMetricsMiddleware } from '@/observability/metrics';
import { NotFoundError } from '@/utils/errors';

export function createApp(): Express {
  const app = express();
  app.disable('x-powered-by');
  // Trust the first proxy so express-rate-limit sees the real client IP
  // when the local nginx fronts the API.
  app.set('trust proxy', 1);

  // Helmet defaults are sensible, but we make the security-relevant ones
  // explicit so a future refactor doesn't silently regress them. CSP is
  // strict because the API serves JSON only — no inline scripts, no frames,
  // no cross-origin assets. Swagger-UI is mounted at /api/docs in dev
  // only (see config/swagger.ts) and its bundled assets are compatible
  // with the script-src/style-src 'self' directives below; if a future
  // swagger-ui version requires inline styles, gate it with a per-path
  // relaxation rather than loosening the global CSP.
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'"],
          imgSrc: ["'self'", 'data:'],
          connectSrc: ["'self'"],
          frameAncestors: ["'none'"],
          baseUri: ["'self'"],
          formAction: ["'self'"],
          objectSrc: ["'none'"],
        },
      },
      frameguard: { action: 'deny' },
      referrerPolicy: { policy: 'no-referrer' },
      crossOriginResourcePolicy: { policy: 'same-origin' },
    }),
  );
  app.use(
    cors({
      origin: env.CORS_ALLOWED_ORIGINS.length > 0 ? env.CORS_ALLOWED_ORIGINS : false,
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: false }));
  app.use(pinoHttp({ logger }));

  if (env.METRICS_ENABLED) {
    app.use(httpMetricsMiddleware(getMetrics()));
    app.use('/metrics', metricsRouter);
  }

  app.use('/health', healthRouter);

  mountSwagger(app);

  // tusd hooks live off `/api` so they're obviously service-to-service traffic
  // (the gateway's auth rules look at the `/api` prefix). Mounted before the
  // API router so the explicit `/internal/*` path wins, not the catch-all.
  app.use('/internal', internalHooksRouter);
  app.use('/api', apiRouter);

  app.use((_req, _res, next) => {
    next(new NotFoundError('Route not found'));
  });
  app.use(errorHandler);

  return app;
}
