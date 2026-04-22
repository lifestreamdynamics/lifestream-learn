/*
 * PM2 ecosystem for Lifestream Learn (production on mittonvillage.com).
 *
 * Two apps:
 *   - learn-api               — HTTP server on 127.0.0.1:3101
 *   - learn-transcode-worker  — BullMQ consumer for learn:transcode
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
  ],
};
