import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { env } from '@/config/env';
import {
  getTranscodeQueue,
  closeTranscodeQueue,
  TRANSCODE_QUEUE_NAME,
} from '@/queues/transcode.queue';

describe('tusd hook (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeTranscodeQueue();
    await closeConnections();
  });

  const goodToken = env.TUSD_HOOK_SECRET;
  const badToken = 'X'.repeat(goodToken.length);

  function body(type: string, videoId?: string) {
    return {
      Type: type,
      Event: {
        Upload: {
          ID: 'tus-upload-id',
          MetaData: videoId ? { videoId } : {},
        },
      },
    };
  }

  it('401 when token header is missing', async () => {
    const app = await getTestApp();
    const res = await request(app).post('/internal/hooks/tusd').send(body('pre-finish', 'x'));
    expect(res.status).toBe(401);
  });

  it('401 when token is wrong', async () => {
    const app = await getTestApp();
    const res = await request(app)
      .post('/internal/hooks/tusd')
      .set('x-tusd-hook-token', badToken)
      .send(body('pre-finish', 'x'));
    expect(res.status).toBe(401);
  });

  it('pre-finish with correct token enqueues a transcode job', async () => {
    const app = await getTestApp();
    const videoId = randomUUID();

    const res = await request(app)
      .post('/internal/hooks/tusd')
      .set('x-tusd-hook-token', goodToken)
      .send(body('pre-finish', videoId));

    expect(res.status).toBe(200);
    expect(res.body.enqueued).toBe(videoId);

    const queue = getTranscodeQueue();
    const job = await queue.getJob(videoId);
    expect(job).not.toBeNull();
    // With no Storage.Key in the mock body, controller falls back to Upload.ID.
    expect(job!.data).toEqual({ videoId, sourceKey: 'tus-upload-id' });
    expect(job!.name).toBe(TRANSCODE_QUEUE_NAME);
  });

  it('pre-finish accepts the token via ?token= query fallback', async () => {
    const app = await getTestApp();
    const videoId = randomUUID();

    const res = await request(app)
      .post(`/internal/hooks/tusd?token=${encodeURIComponent(goodToken)}`)
      .send(body('pre-finish', videoId));

    expect(res.status).toBe(200);
    expect(res.body.enqueued).toBe(videoId);
  });

  it('post-finish is a 200 no-op that does not enqueue', async () => {
    const app = await getTestApp();
    const videoId = randomUUID();

    const res = await request(app)
      .post('/internal/hooks/tusd')
      .set('x-tusd-hook-token', goodToken)
      .send(body('post-finish', videoId));

    expect(res.status).toBe(200);
    expect(res.body.noop).toBe(true);

    const queue = getTranscodeQueue();
    const job = await queue.getJob(videoId);
    expect(job).toBeFalsy();
  });

  it('pre-finish without videoId metadata returns 400', async () => {
    const app = await getTestApp();
    const res = await request(app)
      .post('/internal/hooks/tusd')
      .set('x-tusd-hook-token', goodToken)
      .send(body('pre-finish'));
    expect(res.status).toBe(400);
  });

  it('malformed body returns 400', async () => {
    const app = await getTestApp();
    const res = await request(app)
      .post('/internal/hooks/tusd')
      .set('x-tusd-hook-token', goodToken)
      .send({ not: 'right' });
    expect(res.status).toBe(400);
  });
});
