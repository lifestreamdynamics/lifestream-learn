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

  it('401 for short tokens (no length side-channel)', async () => {
    // Pre-fix: a shorter-than-expected token short-circuited on length, which
    // is observable by timing. The hash-first compare now treats any mismatch
    // identically.
    const app = await getTestApp();
    const res = await request(app)
      .post('/internal/hooks/tusd')
      .set('x-tusd-hook-token', 'short')
      .send(body('pre-finish', randomUUID()));
    expect(res.status).toBe(401);
  });

  it('401 for empty token', async () => {
    const app = await getTestApp();
    const res = await request(app)
      .post('/internal/hooks/tusd')
      .set('x-tusd-hook-token', '')
      .send(body('pre-finish', randomUUID()));
    expect(res.status).toBe(401);
  });

  it('pre-create with a Size within the byte cap returns 200', async () => {
    const app = await getTestApp();
    const res = await request(app)
      .post('/internal/hooks/tusd')
      .set('x-tusd-hook-token', goodToken)
      .send({
        Type: 'pre-create',
        Event: {
          Upload: {
            ID: 'tus-upload-id',
            Size: 10 * 1024 * 1024, // 10 MiB — well under the 2 GiB default
            MetaData: {},
          },
        },
      });
    expect(res.status).toBe(200);
    expect(res.body.accepted).toBe(true);
  });

  it('pre-create rejects an oversized Upload-Length with 413 INPUT_TOO_LARGE', async () => {
    const app = await getTestApp();
    // 1 byte over the env cap. We read env.VIDEO_MAX_BYTES at runtime so
    // raising the default in .env.test doesn't silently skip this check.
    const over = env.VIDEO_MAX_BYTES + 1;
    const res = await request(app)
      .post('/internal/hooks/tusd')
      .set('x-tusd-hook-token', goodToken)
      .send({
        Type: 'pre-create',
        Event: {
          Upload: {
            ID: 'tus-upload-id',
            Size: over,
            MetaData: {},
          },
        },
      });
    expect(res.status).toBe(413);
    expect(res.body.code).toBe('INPUT_TOO_LARGE');
  });

  it('flooding the hook eventually returns 429', async () => {
    const app = await getTestApp();
    // RATE_LIMIT_TUSD_HOOK_MAX default is 60/min in a 60s window. The test
    // env raises ceilings for other limiters but this one is new; if the
    // limit has been raised in .env.test we still assert that *some* request
    // past the ceiling is throttled. Using malformed bodies keeps the queue
    // clean; the limiter runs before the controller so 429 takes precedence.
    // Budget: at most 200 requests serially — well under the 30s timeout.
    let saw429 = false;
    for (let i = 0; i < 200; i += 1) {
      const res = await request(app)
        .post('/internal/hooks/tusd')
        .set('x-tusd-hook-token', goodToken)
        .send({ malformed: true });
      if (res.status === 429) {
        saw429 = true;
        break;
      }
    }
    expect(saw429).toBe(true);
  });
});
