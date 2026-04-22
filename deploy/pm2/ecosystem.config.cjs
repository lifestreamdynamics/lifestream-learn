/*
 * PM2 ecosystem for Lifestream Learn (production on mittonvillage.com).
 *
 * Four apps:
 *   - learn-api               — HTTP server on 127.0.0.1:3101
 *   - learn-transcode-worker  — BullMQ consumer for learn:transcode
 *   - learn-seaweedfs         — SeaweedFS server (filer + S3 + master) on 127.0.0.1:8333
 *   - learn-tusd              — tusd v2 upload server on 127.0.0.1:1080
 *
 * Paths assume the deploy script has rsynced a release into:
 *   /var/www/learn-api/releases/<id>/api/
 * and flipped `/var/www/learn-api/current` → that release.
 *
 * Runtime env lives OUTSIDE the release tree at /etc/learn-api/.env
 * (chmod 600, root-owned). PM2 loads it via `env_file`; values in the
 * inline `env` block are baked-in defaults that the dotenv file CAN
 * override (per pm2 precedence).
 *
 * The worker runs at a higher `nice` value and single-concurrency
 * because the VPS has 2 CPU cores + 3.8 GB RAM and FFmpeg is hungry.
 * Both of those live in the env file (TRANSCODE_CONCURRENCY=1) plus
 * the `nice` wrapper below on `script`.
 */

'use strict';

const RELEASE_DIR = '/var/www/learn-api/current/api';
const ENV_FILE = '/etc/learn-api/.env';
const SHARED_LOGS = '/var/www/learn-api/shared/logs';
const INFRA_CONFIG_DIR = '/etc/learn-api';
const SEAWEEDFS_DATA_DIR = '/var/lib/learn-seaweedfs';

module.exports = {
  apps: [
    {
      name: 'learn-api',
      script: 'dist/index.js',
      cwd: RELEASE_DIR,
      instances: 1,            // box is RAM-tight; revisit when we hit 8 GB
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'production',
        PORT: '3101',
      },
      env_file: ENV_FILE,
      max_restarts: 10,
      restart_delay: 2000,
      kill_timeout: 5000,
      out_file: `${SHARED_LOGS}/learn-api.out.log`,
      error_file: `${SHARED_LOGS}/learn-api.err.log`,
      merge_logs: true,
      time: true,
    },
    {
      name: 'learn-transcode-worker',
      // Wrap via `nice` so the transcode process runs at nice=10
      // without needing a separate systemd unit. `exec_interpreter: 'none'`
      // tells PM2 to exec the script directly; combined with the shell
      // form, the worker inherits the lowered priority.
      script: '/usr/bin/nice',
      args: ['-n', '10', 'node', 'dist/workers/transcode.js'],
      exec_interpreter: 'none',
      cwd: RELEASE_DIR,
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'production',
      },
      env_file: ENV_FILE,
      max_restarts: 10,
      restart_delay: 5000,
      kill_timeout: 15000,      // let in-flight FFmpeg drain gracefully
      out_file: `${SHARED_LOGS}/learn-transcode-worker.out.log`,
      error_file: `${SHARED_LOGS}/learn-transcode-worker.err.log`,
      merge_logs: true,
      time: true,
    },
    {
      name: 'learn-seaweedfs',
      script: '/usr/local/bin/weed',
      args: [
        'server',
        `-dir=${SEAWEEDFS_DATA_DIR}`,
        '-s3',
        `-s3.config=${INFRA_CONFIG_DIR}/s3.json`,
        '-filer',
        '-master.volumeSizeLimitMB=1024',
        '-ip=127.0.0.1',
        '-ip.bind=127.0.0.1',
      ],
      exec_interpreter: 'none',
      instances: 1,
      exec_mode: 'fork',
      env: {
        // NODE_ENV is not used by weed but keeps PM2's env block happy
        NODE_ENV: 'production',
      },
      max_restarts: 5,
      restart_delay: 3000,
      kill_timeout: 10000,
      autorestart: true,
      out_file: `${SHARED_LOGS}/learn-seaweedfs.out.log`,
      error_file: `${SHARED_LOGS}/learn-seaweedfs.err.log`,
      merge_logs: true,
      time: true,
    },
    {
      // The actual tusd invocation is wrapped in a shell script so the
      // TUSD hook URL can include the secret token without it being
      // committed to git. The deploy script's provision_infra step writes
      // this wrapper to INFRA_CONFIG_DIR/tusd-start.sh (chmod 700, root-owned).
      name: 'learn-tusd',
      script: `${INFRA_CONFIG_DIR}/tusd-start.sh`,
      exec_interpreter: 'none',
      instances: 1,
      exec_mode: 'fork',
      env: {
        AWS_ACCESS_KEY_ID: process.env.SEAWEEDFS_ACCESS_KEY_ID ?? '',
        AWS_SECRET_ACCESS_KEY: process.env.SEAWEEDFS_SECRET_ACCESS_KEY ?? '',
        AWS_REGION: 'us-east-1',
      },
      max_restarts: 10,
      restart_delay: 3000,
      kill_timeout: 5000,
      autorestart: true,
      out_file: `${SHARED_LOGS}/learn-tusd.out.log`,
      error_file: `${SHARED_LOGS}/learn-tusd.err.log`,
      merge_logs: true,
      time: true,
    },
  ],
};
