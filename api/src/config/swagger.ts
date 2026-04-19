import type { Express } from 'express';
import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';
import { env } from '@/config/env';

const spec = swaggerJsdoc({
  definition: {
    openapi: '3.0.3',
    info: {
      title: 'Lifestream Learn API',
      version: '0.0.1',
      description: 'REST API for Lifestream Learn. Phase 2 scaffold.',
      license: {
        name: 'AGPL-3.0-or-later',
        url: 'https://www.gnu.org/licenses/agpl-3.0.en.html',
      },
    },
    servers: [{ url: `http://localhost:${env.PORT}`, description: 'Local dev' }],
    components: {
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
    },
  },
  apis: ['src/routes/**/*.ts', 'src/controllers/**/*.ts'],
});

export function mountSwagger(app: Express): void {
  if (env.NODE_ENV === 'production') return;
  app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(spec, { explorer: true }));
  app.get('/api/docs.json', (_req, res) => {
    res.json(spec);
  });
}
