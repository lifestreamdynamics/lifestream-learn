import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { closeConnections } from '@tests/integration/helpers/teardown';

describe('GET /health', () => {
  afterAll(async () => {
    await closeConnections();
  });

  it('reports all dependencies ok against local infra', async () => {
    const app = await getTestApp();
    const res = await request(app).get('/health');
    expect(res.body.dependencies).toEqual({
      database: 'ok',
      redis: 'ok',
      s3: 'ok',
      queue: 'ok',
    });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('liveness endpoint returns bare ok', async () => {
    const app = await getTestApp();
    const res = await request(app).get('/health/liveness');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});
