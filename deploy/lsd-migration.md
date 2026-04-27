# Migration to `lsd` deploy

The legacy `deploy/deploy-production.sh` workflow is being replaced by
`lsd`, the Lifestream ecosystem deploy CLI (one binary across all 11
projects on `mittonvillage.com`). This doc covers what changed, the
one-time prerequisites, and the day-to-day deploy commands.

`lsd` lives at `~/Projects/lifestream-deploy/`; install with
`make install` from that repo. See `~/Projects/lifestream-deploy/docs/getting-started.md`
for the laptop-side quickstart.

## What's covered by lsd

| Component | Pre-lsd | lsd |
|---|---|---|
| `learn-api` (Node API on :3101) | `deploy-production.sh` + `ecosystem.config.cjs` | `api/deploy.yaml` (node-pm2 plugin) |
| `learn-transcode-worker` (BullMQ worker) | same script + ecosystem entry | second `services:` entry in `api/deploy.yaml` |
| `learn-landing` (static HTML) | rsync from same script | `infra/landing/deploy.yaml` (vite-spa plugin) |
| nginx vhost rendering | hand-rolled `.conf` rsync | rendered from `api-hls.conf.tpl` (vars-driven) |
| TLS cert provisioning | webroot certbot in script | lsd Phase 4 auto-provisions if missing |
| Secrets | `/etc/learn-api/.env` (chmod 600, root-owned) | lsd-vault, rendered into `releases/<v>/.env.production` |
| Atomic cutover | `ln -sfn` + reverse-swap rollback | lsd Phase 5 + Phase 7 health-gated rollback |
| Append-only deploy log | none | `lsd-ledger/deploys.jsonl` (committed git history) |

## What's still hand-managed (out of scope for lsd today)

- **`learn-tusd`** and **`learn-seaweedfs`** — long-running daemons that
  don't ship per-deploy artifacts. They were managed by the legacy
  `ecosystem.config.cjs` and continue to be. Operator runs once:
  `pm2 start /var/www/learn-api/current/deploy/pm2/ecosystem.config.cjs --only learn-tusd,learn-seaweedfs`
  then `pm2 save`. (Or migrate them to systemd units — a TODO for after
  MVP launch.)
- **The HMAC HLS secret include**: lsd renders
  `/etc/nginx/snippets/learn-api-hls-secret.inc` per-deploy via a
  pre_cutover hook (sources `HLS_SIGNING_SECRET` from the rendered
  `.env.production`).

## One-time setup (operator)

These are required before the very first `lsd deploy learn-api` will
succeed. Each step is idempotent.

### 1. lsd installed and wired

From `~/Projects/lifestream-deploy/`:

```bash
make install
export LSD_VAULT_HOST=mittonvillage.com   # if not already in your shell rc
lsd doctor
```

`lsd doctor` should report `✓ lsd-vault agent ...`. If it doesn't, run
`lsd vault init --host=mittonvillage.com` once.

### 2. Provision the `learn-api` system user on the VPS

Done as of 2026-04-26:

```bash
ssh root@mittonvillage.com '
  useradd --system --create-home --home-dir /home/learn-api --shell /bin/bash learn-api
  mkdir -p /var/www/learn-api/releases /var/www/learn-api/shared
  chown learn-api:learn-api /var/www/learn-api /var/www/learn-api/releases /var/www/learn-api/shared
'
```

### 3. Ship the `secure_link.conf.inc` snippet to nginx

The HMAC validator snippet is content-addressed (no per-deploy values).
Ship once; updates only when the snippet itself changes.

```bash
scp infra/nginx/secure_link.conf.inc \
    root@mittonvillage.com:/etc/nginx/snippets/learn-api-secure_link.conf.inc
ssh root@mittonvillage.com 'chmod 0644 /etc/nginx/snippets/learn-api-secure_link.conf.inc'
```

### 4. Load secrets into lsd-vault

If migrating from an existing `/etc/learn-api/.env` on the VPS:

```bash
# Pull the live env to a tmpfs path (no plaintext on local disk)
mkdir -p /run/user/$UID/lsd-import && chmod 0700 /run/user/$UID/lsd-import
scp root@mittonvillage.com:/etc/learn-api/.env /run/user/$UID/lsd-import/learn-api.env
chmod 0600 /run/user/$UID/lsd-import/learn-api.env

# Import (PORT is auto-filtered; SEED_* are dev-only and should be excluded)
cd ~/Projects/lifestream-learn/api
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
cd ~/Projects/lifestream-learn/api
cp .env.production.example /run/user/$UID/learn-api.env
chmod 0600 /run/user/$UID/learn-api.env
$EDITOR /run/user/$UID/learn-api.env   # fill in REPLACE_ME slots
lsd secrets import learn-api /run/user/$UID/learn-api.env
shred -uvz /run/user/$UID/learn-api.env
```

## Day-to-day deploys

### API + worker

```bash
cd ~/Projects/lifestream-learn
git tag -a v0.1.0 -m "release v0.1.0"
git push origin main --follow-tags
cd api
lsd deploy learn-api v0.1.0
```

(Tags live at the repo root, but `lsd deploy` runs from `api/` so it
picks up `api/deploy.yaml`. lsd's git-ops walk upward to find `.git`.)

### Landing page

```bash
cd ~/Projects/lifestream-learn/infra/landing
lsd deploy learn-landing v0.1.0
```

### Verifying success

```bash
lsd status                                    # one row per app
lsd history learn-api --limit 5                # recent deploys
curl -sI https://learn-api.lifestreamdynamics.com/health
ssh root@mittonvillage.com 'sudo -u learn-api pm2 list'
```

### Rolling back

Symlink-based, fast:

```bash
lsd rollback learn-api                         # previous release
lsd rollback learn-api v0.0.9                  # specific kept release
```

## Caveats

- **The PM2 `nice -n 10` wrapper for the transcode worker is gone in the
  lsd version.** lsd's rendered ecosystem.config.js doesn't yet support
  process-priority wrappers. If FFmpeg starves the API at peak, add a
  shim script under `api/scripts/transcode-nice.sh` that exec's the
  worker via `nice -n 10` and update `api/deploy.yaml` to point
  `services[].script` at the shim.
- **`learn-tusd` and `learn-seaweedfs` are NOT touched by `lsd deploy
  learn-api`.** They keep running across deploys (their state lives in
  `/var/lib/learn-seaweedfs/`). If you need to restart them, do it
  manually: `ssh root@mittonvillage.com sudo -u learn-api pm2 reload learn-tusd`.
- **The bundled `deploy-production.sh` and `deploy/pm2/ecosystem.config.cjs`
  remain in the repo** for now — tusd + seaweedfs first-boot still uses
  the cjs file. Don't delete them until those two services are migrated
  to systemd or absorbed into lsd's services list.

## Reference: deploy.yaml fields

See `~/Projects/lifestream-deploy/docs/deploy-yaml-reference.md` for the
full schema. The two most lsd-specific blocks for learn-api are:

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
