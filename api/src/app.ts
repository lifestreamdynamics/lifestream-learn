import express, { type Express } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import pinoHttp from 'pino-http';
import { env } from '@/config/env';
import { logger } from '@/config/logger';
import { mountSwagger } from '@/config/swagger';
import { healthRouter } from '@/routes/health.routes';
import { apiRouter } from '@/routes/index';
import { errorHandler } from '@/middleware/error-handler';
import { NotFoundError } from '@/utils/errors';

export function createApp(): Express {
  const app = express();
  app.disable('x-powered-by');
  // Trust the first proxy so express-rate-limit sees the real client IP
  // when the local nginx fronts the API.
  app.set('trust proxy', 1);

  app.use(helmet());
  app.use(
    cors({
      origin: env.CORS_ALLOWED_ORIGINS.length > 0 ? env.CORS_ALLOWED_ORIGINS : false,
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: false }));
  app.use(pinoHttp({ logger }));

  app.use('/health', healthRouter);

  mountSwagger(app);

  app.use('/api', apiRouter);

  app.use((_req, _res, next) => {
    next(new NotFoundError('Route not found'));
  });
  app.use(errorHandler);

  return app;
}
