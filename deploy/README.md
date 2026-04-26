# `deploy/` — Lifestream Learn production deploy runbook

This directory holds everything needed to ship the Learn API + transcode
worker + landing page to production. It's the **public-safe, committed**
half of the split layout; real secrets live at `ops/env/api.production.env`
(git-ignored) and on the VPS at `/etc/learn-api/.env`.

The deploy script is modelled on the user's Lifestream Vault deploy
template (`~/Projects/lifestream-dynamics-vault/scripts/deploy-production.sh`)
— same SSH ControlMaster, local-build-then-rsync pattern, idempotent
nginx with hash-based reloads, Let's Encrypt via webroot, and atomic
cutover with a reverse-swap emergency rollback.

Target VPS: `REDACTED-VPS-HOST` (Ubuntu 24.04, shared with `accounting-api`
on port 3100 and `galaxy-miner`). Learn-API claims port **3101** per
`IMPLEMENTATION_PLAN.md §3`. Verify you're not stepping on `api.REDACTED-BRAND-DOMAIN`
(accounting) or `vault.REDACTED-BRAND-DOMAIN` (vault) server blocks.

---

## Layout

```
deploy/
├── deploy-production.sh                  # the script (shellcheck-clean)
├── pm2/
│   └── ecosystem.config.cjs              # learn-api + learn-transcode-worker
├── nginx/
│   ├── learn-api.REDACTED-BRAND-DOMAIN.conf   # API + tusd + HLS vhost
│   ├── learn.REDACTED-BRAND-DOMAIN.conf       # static landing vhost
│   └── snippets/
│       └── secure_link.conf.inc          # HMAC validation (MD5-keyed; see ADR)
└── README.md                             # this file

ops/                                     # git-ignored; operator-managed
└── env/
    ├── api.production.env                # real secrets (chmod 600)
    └── infra.production.env              # compose-side values (chmod 600)
```

At deploy time, files land on the VPS at:

```
/var/www/learn-api/
├── current                  → releases/<id>     (symlink, atomic swap target)
├── releases/
│   ├── 20260421-143500-ab12cd34/                (built api/ tree)
│   ├── 20260421-162200-ef56gh78/
│   └── ...                                     (retention: KEEP_RELEASES, default 5)
└── shared/
    └── logs/                                    (pm2 out/err logs survive swaps)

/var/www/learn-landing/                          (static, rsynced from infra/landing/)
/etc/learn-api/.env                              (runtime config; only copied with --sync-env)
/etc/nginx/sites-available/learn-api.REDACTED-BRAND-DOMAIN
/etc/nginx/sites-available/learn.REDACTED-BRAND-DOMAIN
/etc/nginx/snippets/learn-secure_link.conf.inc
/etc/letsencrypt/live/learn-api.REDACTED-BRAND-DOMAIN/
/etc/letsencrypt/live/learn.REDACTED-BRAND-DOMAIN/
/var/backups/learn-api/                          (pg_dump snapshots, retention 10)
```

---

## First-time VPS prep (one-shot, manual)

Before the first run of `deploy-production.sh`:

1. **DNS** — confirm `learn-api.REDACTED-BRAND-DOMAIN` and
   `learn.REDACTED-BRAND-DOMAIN` both resolve to the VPS IP
   (`dig +short learn-api.REDACTED-BRAND-DOMAIN` should match
   `dig +short REDACTED-VPS-HOST`).

2. **FFmpeg** — the transcode worker will crash on first job without it.
   `ssh root@REDACTED-VPS-HOST 'apt update && apt install -y ffmpeg'`
   The deploy script checks for `ffmpeg` during `check_remote_prerequisites`
   and refuses to proceed unless you pass `--force`.

3. **PostgreSQL database + role** — the deploy script provisions this
   automatically via `provision_database()`. Nothing to do manually; the step
   is idempotent so it safely re-runs on every deploy. Requires Postgres to be
   running and `sudo -u postgres psql` to work from the root shell (standard on
   Ubuntu). The role (`learn_api_user`) and DB (`learn_api_production`) are
   isolated from accounting-api's resources per `CLAUDE.md §Shared-resource
   discipline`.

4. **Docker + SeaweedFS + tusd** — the API and transcode worker depend on
   object storage (SeaweedFS) and resumable uploads (tusd) provided by the
   `infra/` docker-compose stack. Until this stack is running:
   - Auth, course management, and all non-video features work normally.
   - Video upload and HLS playback will fail.
   - `/health` will return `s3: error` and HTTP 503; `/health/liveness` will
     return 200 (the process itself is healthy).

   Install Docker and start the stack:
   ```bash
   # On the VPS:
   apt install -y docker.io docker-compose-plugin
   systemctl enable --now docker

   # On your laptop (rsyncs infra/docker-compose.prod.yml + env):
   rsync -az infra/ root@REDACTED-VPS-HOST:/opt/learn-infra/
   rsync -az ops/env/infra.production.env root@REDACTED-VPS-HOST:/opt/learn-infra/.env

   ssh root@REDACTED-VPS-HOST 'cd /opt/learn-infra && docker compose -f docker-compose.prod.yml up -d'
   ```
   Bind tusd to `127.0.0.1:1080` and SeaweedFS S3 to `127.0.0.1:8333`
   (enforced by `docker-compose.prod.yml`; never bind `0.0.0.0`).
   See `infra/README.md` for bucket provisioning after first start.

5. **Create the runtime env file** —
   ```bash
   # On your laptop:
   mkdir -p ops/env
   cp api/.env.production.example ops/env/api.production.env
   chmod 600 ops/env/api.production.env
   # Fill in the REPLACE_ME values using `openssl rand -base64 48` etc.
   ```

6. **First deploy** — copy the env file up and do the full rollout in one
   go:
   ```bash
   ./deploy/deploy-production.sh --dry-run          # preview
   ./deploy/deploy-production.sh --sync-env         # real run
   ```
   The `--sync-env` flag rsyncs `ops/env/api.production.env` to
   `/etc/learn-api/.env` (root-owned, chmod 600). Subsequent deploys
   leave the env file alone — use `--sync-env` again only to rotate.

7. **HLS signing secret in nginx** — the public copy of
   `deploy/nginx/learn-api.REDACTED-BRAND-DOMAIN.conf` ships a literal
   `set $secure_link_secret "REPLACE_ME_WITH_HLS_SIGNING_SECRET";`.
   Before your first real HLS playback, edit `/etc/nginx/sites-available/learn-api.REDACTED-BRAND-DOMAIN`
   on the VPS and replace that literal with the value of `HLS_SIGNING_SECRET`
   from `/etc/learn-api/.env`, then `nginx -t && systemctl reload nginx`.
   *Future improvement:* move the secret into an `include` of a
   `/etc/nginx/private/learn-hls-secret.conf` file so the deploy script
   can manage it without touching the public vhost (tracked as follow-up).

8. **Certbot** — the deploy script's `setup_ssl` step issues certs via
   `certbot --webroot -w /var/www/certbot`. The webroot directory is
   created on-demand. Auto-renew is already wired via the system-level
   certbot timer (same one accounting-api uses).

9. **Block-storage volume for SeaweedFS** — not required for a first smoke
   test, but attach `>= 100 GB` at `/mnt/seaweedfs-data` before closed beta.
   Flagged in `ops/vps-prereq-check-2026-04-18.md`.

---

## Common recipes

```bash
# Preview (safe — no SSH, no remote changes, doesn't require ops/env)
./deploy/deploy-production.sh --dry-run

# Full production deploy
./deploy/deploy-production.sh

# First-time / env-rotate
./deploy/deploy-production.sh --sync-env

# Code-only (skip nginx + SSL steps)
./deploy/deploy-production.sh --skip-nginx --skip-ssl

# Rollback to previous release
./deploy/deploy-production.sh --rollback

# Rollback to a specific release id
./deploy/deploy-production.sh --rollback 20260421-094500-ab12cd34
```

Env overrides are documented in `--help`. All defaults are safe to
commit publicly (`REDACTED-VPS-HOST`, brand-public subdomains,
`/var/www/learn-api`). Real secrets never live in the script.

---

## What the deploy does

```
[local]   0. acquire /tmp/learn-deploy.lock
[local]   1. check_local_prerequisites (node, npm, rsync, ssh key, repo layout)
[local]   2. resolve release id = <utc-ts>-<git-sha>
[remote]  3. open SSH ControlMaster
[remote]  4. check_remote_prerequisites (node, pm2, nginx, certbot, psql, ffmpeg, redis)
[local]   5. npm run validate   (lint + typecheck + unit; --skip-tests to bypass)
[local]   6. npm ci && prisma:generate && npm run build in api/
[local]   7. stage release at deploy/.deploy-stage/<id>/api/{dist,prisma,pkg,lock,node_modules(prod)}
[remote]  8. mkdir releases/<id> + shared/logs + rsync stage → remote
[remote]  9. (--sync-env only) rsync ops/env/api.production.env → /etc/learn-api/.env
[remote] 10. pg_dump learn_api_production → /var/backups/learn-api/db-<ts>.sql.gz
[remote] 11. cd releases/<id>/api && prisma migrate deploy
[remote] 12. CUTOVER: ln -sfn releases/<id> current  (atomic)
[remote] 13. pm2 startOrReload deploy/pm2/ecosystem.config.cjs
[remote] 14. rsync infra/landing/ → /var/www/learn-landing/   (--skip-landing to bypass)
[remote] 15. deploy nginx vhosts (hash-based; only reload on change)
[remote] 16. certbot webroot for API + landing (skip if cert present)
[remote] 17. verify: pm2 describe both apps online + curl http://127.0.0.1:3101/health
[remote] 18. prune releases/ to newest KEEP_RELEASES entries (default 5)
[local]  19. close SSH ControlMaster, release lock
```

If step 17 fails, the cleanup trap flips `current` back to the previous
release and attempts `pm2 reload` on both apps before exiting 1. If the
cutover itself (step 12 or 13) dies mid-flight, the same reverse-symlink
emergency rollback fires via `trap cleanup EXIT`.

---

## Log locations

```
/var/log/nginx/learn-api.access.log
/var/log/nginx/learn-api.error.log
/var/log/nginx/learn-landing.access.log
/var/log/nginx/learn-landing.error.log
/var/www/learn-api/shared/logs/learn-api.{out,err}.log
/var/www/learn-api/shared/logs/learn-transcode-worker.{out,err}.log
```

Local deploy logs land in `logs/deploy-<ts>.log` (relative to the
repo root); that directory is `.gitignore`d.

---

## Health checks

```bash
# Process liveness (200 = Node process is up; no infra dependency)
curl -sf https://learn-api.REDACTED-BRAND-DOMAIN/health/liveness

# Deep dependency check (200 = DB + Redis + S3 + queue all healthy)
# Returns 503 with JSON body when S3/SeaweedFS is not running — expected
# until the infra docker-compose stack is started (see §First-time prep step 4).
curl -s https://learn-api.REDACTED-BRAND-DOMAIN/health | python3 -m json.tool

# Landing page
curl -sfI https://learn.REDACTED-BRAND-DOMAIN/

# On-host (requires SSH)
ssh root@REDACTED-VPS-HOST 'pm2 status'
ssh root@REDACTED-VPS-HOST 'pm2 logs learn-api --lines 50 --nostream'
ssh root@REDACTED-VPS-HOST 'curl -sf http://127.0.0.1:3101/health/liveness'
```

**Expected deep-health state before Docker infra is running:**
```json
{"status":"degraded","dependencies":{"database":"ok","redis":"ok","s3":"error","queue":"ok"}}
```
This is normal. Auth, courses, and all non-video features are operational.

### Internal endpoints (`/metrics`, `/internal/`)

These are gated at the nginx layer in `deploy/nginx/learn-api.REDACTED-BRAND-DOMAIN.conf`:

```nginx
location = /metrics {
    allow 127.0.0.1;
    allow 172.16.0.0/12;   # docker bridge / private VPC
    deny all;
}
location ^~ /internal/ {
    allow 127.0.0.1;
    allow 172.16.0.0/12;
    deny all;
}
```

That covers the two valid clients:

- **Same-VPS Prometheus** scrape → `127.0.0.1:80/metrics` (or directly `127.0.0.1:3101/metrics`, bypassing nginx).
- **tusd → learn-api `/internal/hooks/tusd`** → tusd runs in the docker network, so its source IP is `172.16.0.0/12`.

If a future Prometheus scraper runs from outside the VPS, add its specific IP to both locations. Do NOT widen the CIDR range or remove `deny all`. The threat model (`docs/security/threat-model.md` §6 row 7) documents this.

---

## Rollback procedure

```bash
# Symlink-based fast rollback (seconds)
./deploy/deploy-production.sh --rollback

# Named rollback (pick a release id from `ls /var/www/learn-api/releases`)
./deploy/deploy-production.sh --rollback 20260421-094500-ab12cd34
```

Both paths flip `current` → target release, then `pm2 reload` both apps.
Downtime is PM2's reload window (~1 second of dropped connections, because
we use `pm2 reload` not `pm2 restart`).

If rollback fails (release directory gone, PM2 daemon itself borked):

1. `ssh root@REDACTED-VPS-HOST 'pm2 kill && pm2 resurrect'`
2. Restore the latest DB backup:
   `ssh root@REDACTED-VPS-HOST 'gunzip -c /var/backups/learn-api/db-<ts>.sql.gz | psql $DATABASE_URL'`
3. Re-run `./deploy/deploy-production.sh` from a known-good git SHA.

---

## AGPL hygiene check

Every file in this directory is safe for the public monorepo:

- `deploy-production.sh` — only production hostnames are brand-public
  subdomains of `REDACTED-BRAND-DOMAIN`; the VPS hostname
  (`REDACTED-VPS-HOST`) is an overridable DEFAULT, matching the vault
  script's convention.
- `pm2/ecosystem.config.cjs` — no secrets. `env_file` path is
  `/etc/learn-api/.env`, filled in at runtime.
- `nginx/*.conf` — no secrets. The HLS secret is a `REPLACE_ME` literal
  the operator fills in on the VPS post-deploy (see §First-time prep).
- `nginx/snippets/secure_link.conf.inc` — identical to
  `infra/nginx/secure_link.conf.inc`; both must stay in sync.

If you extend any of these files, re-verify with `gitleaks detect`
before committing. The pre-push hook (`.githooks/pre-push`) catches
most leaks but not every pattern.
