# Production deploy via `lsd`

Production deploys are driven by `lsd`, the Lifestream ecosystem deploy
CLI (one binary across all sister projects on the shared VPS). This doc
covers what's deployed, the one-time prerequisites, and the day-to-day
deploy commands.

`lsd` lives at `~/Projects/lifestream-deploy/`; install with
`make install` from that repo. See its `docs/getting-started.md` for the
laptop-side quickstart.

> **Operator-private values.** This repo deliberately contains no production
> hostnames, no VPS hostnames, and no maintainer email addresses (with the
> single exception of the public `learn@lifestreamdynamics.com` forwarder).
> The lsd manifests, nginx vhost templates, and landing-page artifacts all
> live under the operator-private `ops/` directory (gitignored at the repo
> root). The shell variables shown below — `$VPS_HOST`, `$API_DOMAIN`,
> `$LANDING_DOMAIN`, `$LE_EMAIL` — are operator-set; export them in your
> shell rc or `ops/env/local.env` before running any of the commands here.

## What's deployed via lsd

| Component | lsd manifest |
|---|---|
| `learn-api` (Node API) | `ops/lsd/learn-api/deploy.yaml` (`node-pm2` plugin) |
| `learn-transcode-worker` (BullMQ worker) | second `services:` entry in `ops/lsd/learn-api/deploy.yaml` |
| `learn-landing` (static HTML) | `ops/lsd/learn-landing/deploy.yaml` (`vite-spa` plugin) |
| nginx vhost rendering | rendered by lsd from operator-private templates in `ops/nginx/` |
| TLS cert provisioning | lsd Phase 4 auto-provisions if missing |
| Secrets | lsd-vault, rendered into `releases/<v>/.env.production` at deploy time |
| Atomic cutover | lsd Phase 5 + Phase 7 health-gated rollback |
| Append-only deploy log | `lsd-ledger/deploys.jsonl` (operator-private) |

## What's still hand-managed (out of scope for lsd today)

- **`learn-tusd`** and **`learn-seaweedfs`** — long-running daemons that
  don't ship per-deploy artifacts. Operator runs once:
  `pm2 start /var/www/learn-api/current/deploy/pm2/ecosystem.config.cjs --only learn-tusd,learn-seaweedfs`
  then `pm2 save`. (Or migrate them to systemd units — a TODO for after
  MVP launch.)
- **The HMAC HLS secret include**: lsd renders
  `/etc/nginx/snippets/learn-api-hls-secret.inc` per-deploy via a
  `pre_cutover` hook (sources `HLS_SIGNING_SECRET` from the rendered
  `.env.production`).

## One-time setup (operator)

These are required before the very first `lsd deploy learn-api` will
succeed. Each step is idempotent. Set the operator-private variables
once at the top of your shell session:

```bash
export VPS_HOST=<your-vps-hostname>
export API_DOMAIN=<api.example.com>
export LANDING_DOMAIN=<landing.example.com>
export LE_EMAIL=<contact-for-letsencrypt>
```

### 1. lsd installed and wired

From `~/Projects/lifestream-deploy/`:

```bash
make install
export LSD_VAULT_HOST="$VPS_HOST"   # add to your shell rc
lsd doctor
```

`lsd doctor` should report `✓ lsd-vault agent ...`. If it doesn't, run
`lsd vault init --host="$VPS_HOST"` once.

### 2. Provision the `learn-api` system user on the VPS

```bash
ssh "root@$VPS_HOST" '
  useradd --system --create-home --home-dir /home/learn-api --shell /bin/bash learn-api
  mkdir -p /var/www/learn-api/releases /var/www/learn-api/shared
  chown learn-api:learn-api /var/www/learn-api /var/www/learn-api/releases /var/www/learn-api/shared
'
```

### 3. Ship the `secure_link.conf.inc` snippet to nginx

The HMAC validator snippet is content-addressed (no per-deploy values).
Ship once; updates only when the snippet itself changes.

```bash
scp deploy/nginx/snippets/secure_link.conf.inc \
    "root@$VPS_HOST:/etc/nginx/snippets/learn-api-secure_link.conf.inc"
ssh "root@$VPS_HOST" 'chmod 0644 /etc/nginx/snippets/learn-api-secure_link.conf.inc'
```

### 4. Load secrets into lsd-vault

If migrating from an existing `/etc/learn-api/.env` on the VPS:

```bash
# Pull the live env to a tmpfs path (no plaintext on local disk)
mkdir -p /run/user/$UID/lsd-import && chmod 0700 /run/user/$UID/lsd-import
scp "root@$VPS_HOST:/etc/learn-api/.env" /run/user/$UID/lsd-import/learn-api.env
chmod 0600 /run/user/$UID/lsd-import/learn-api.env

# Import (PORT is auto-filtered; SEED_* are dev-only and should be excluded)
cd ops/lsd/learn-api
lsd secrets import learn-api /run/user/$UID/lsd-import/learn-api.env

# Drop dev-only SEED_* keys that get imported alongside (one-time cleanup)
for k in SEED_ADMIN_EMAIL SEED_ADMIN_PASSWORD SEED_DESIGNER_EMAIL \
         SEED_DEV_USER_PASSWORD SEED_LEARNER_EMAIL SEED_SAMPLE_VIDEO; do
  lsd secrets delete learn-api "$k"
done

# Verify alignment
lsd secrets diff learn-api   # should print "OK: 47 keys aligned"

# Securely wipe the local plaintext copy
shred -uvz /run/user/$UID/lsd-import/learn-api.env
rmdir /run/user/$UID/lsd-import
```

If starting fresh:

```bash
cp api/.env.production.example /run/user/$UID/learn-api.env
chmod 0600 /run/user/$UID/learn-api.env
$EDITOR /run/user/$UID/learn-api.env   # fill in REPLACE_ME slots
cd ops/lsd/learn-api
lsd secrets import learn-api /run/user/$UID/learn-api.env
shred -uvz /run/user/$UID/learn-api.env
```

## Day-to-day deploys

### API + worker

```bash
cd ~/Projects/lifestream-learn
git tag -a v0.1.0 -m "release v0.1.0"
git push origin main --follow-tags
cd ops/lsd/learn-api
lsd deploy learn-api v0.1.0
```

(Tags live at the repo root, but `lsd deploy` runs from the manifest
directory. lsd's git-ops walk upward to find `.git`.)

### Landing page

```bash
cd ~/Projects/lifestream-learn/ops/lsd/learn-landing
lsd deploy learn-landing v0.1.0
```

### Verifying success

```bash
lsd status                                    # one row per app
lsd history learn-api --limit 5               # recent deploys
curl -sI "https://$API_DOMAIN/health"
ssh "root@$VPS_HOST" 'sudo -u learn-api pm2 list'
```

### Rolling back

Symlink-based, fast:

```bash
lsd rollback learn-api                         # previous release
lsd rollback learn-api v0.0.9                  # specific kept release
```

## Caveats

- **The PM2 `nice -n 10` wrapper for the transcode worker is gone in the
  lsd version.** lsd's rendered `ecosystem.config.js` doesn't yet support
  process-priority wrappers. If FFmpeg starves the API at peak, add a
  shim script under `api/scripts/transcode-nice.sh` that exec's the
  worker via `nice -n 10` and update the lsd manifest to point
  `services[].script` at the shim.
- **`learn-tusd` and `learn-seaweedfs` are NOT touched by `lsd deploy
  learn-api`.** They keep running across deploys (their state lives in
  `/var/lib/learn-seaweedfs/`). If you need to restart them, do it
  manually: `ssh "root@$VPS_HOST" sudo -u learn-api pm2 reload learn-tusd`.

## Reference: deploy.yaml fields

See `~/Projects/lifestream-deploy/docs/deploy-yaml-reference.md` for the
full schema. The two most lsd-specific blocks for `learn-api` are:

```yaml
runtime:
  port: 3101                    # single source of truth; lsd renders
                                # PORT=3101 into .env.production AND
                                # auto-fills nginx.vars.upstream

db_sanity_check:
  min_tables: 12                # learn_api_production has 15 tables
                                # (Phase 3 schema); 12 ≈ 80% headroom.
                                # Bumps the ledger entry status to
                                # "failed" if the runtime DSN connects
                                # to an empty/dev DB by mistake.
```
