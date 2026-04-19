import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { closeConnections } from '@tests/integration/helpers/teardown';

const STUB_PATHS = [
  '/api/courses',
  '/api/videos',
  '/api/cues',
  '/api/attempts',
  '/api/voice-attempts',
  '/api/feed',
  '/api/designer-applications',
  '/api/events',
] as const;

describe('Phase 2 stub routes', () => {
  afterAll(async () => {
    await closeConnections();
  });

  it.each(STUB_PATHS)('%s returns 501 Not Implemented', async (path) => {
    const app = await getTestApp();
    const res = await request(app).get(path);
    expect(res.status).toBe(501);
    expect(res.body.error).toBe('NOT_IMPLEMENTED');
  });
});
