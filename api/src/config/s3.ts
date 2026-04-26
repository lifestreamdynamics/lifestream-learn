import { Agent as HttpAgent } from 'node:http';
import { Agent as HttpsAgent } from 'node:https';
import { S3Client } from '@aws-sdk/client-s3';
import { NodeHttpHandler } from '@smithy/node-http-handler';
import { env } from '@/config/env';

export const s3Client = new S3Client({
  endpoint: env.S3_ENDPOINT,
  region: env.S3_REGION,
  forcePathStyle: env.S3_FORCE_PATH_STYLE,
  credentials: {
    accessKeyId: env.S3_ACCESS_KEY,
    secretAccessKey: env.S3_SECRET_KEY,
  },
  // Force "standard" defaults mode so the SDK doesn't lazily
  // `await import('@smithy/credential-provider-imds')` to probe EC2
  // IMDS for a physical region. We're never on EC2 — local hits
  // SeaweedFS, prod hits SeaweedFS-on-VPS.
  defaultsMode: 'standard',
  // Provide an explicit `NodeHttpHandler` with pre-constructed agents
  // so the SDK doesn't lazily import `node:http` / `node:https` to
  // build its agent provider. (Lazy imports are also incompatible
  // with Jest's classic VM runtime; tracked in IMPLEMENTATION_PLAN.md
  // §5 Phase 8 backlog as the AWS SDK ESM issue. The eager
  // construction is also a small first-request perf win in prod.)
  requestHandler: new NodeHttpHandler({
    httpAgent: new HttpAgent({ keepAlive: true }),
    httpsAgent: new HttpsAgent({ keepAlive: true }),
  }),
});
