# `deploy/` — production deploy artifacts

Production deploys are driven by `lsd` (the Lifestream ecosystem deploy
CLI). The day-to-day workflow, one-time VPS prerequisites, secrets
import, and rollback procedures all live in
[`lsd-migration.md`](./lsd-migration.md).

## What's still in this directory

| Path | Purpose |
|---|---|
| [`lsd-migration.md`](./lsd-migration.md) | The runbook — read this first. |
| `nginx/snippets/secure_link.conf.inc` | HMAC validator snippet shipped to `/etc/nginx/snippets/learn-api-secure_link.conf.inc` once during VPS prep. Content-addressed; no per-deploy values. |

## What's NOT in this directory (operator-private, in `ops/`)

- The lsd manifests for the API + landing services (`ops/lsd/learn-api/deploy.yaml`, `ops/lsd/learn-landing/deploy.yaml`).
- The nginx vhost templates rendered by lsd at deploy time (`ops/nginx/learn-api.conf`, `ops/nginx/learn.conf`).
- The pre-built static landing-page artifacts (`ops/landing/`).
- The runtime `.env` (lsd-vault is the source of truth; rendered into `releases/<v>/.env.production`).
- The maintainer/operator contact addresses (`ops/CONTACTS.md`).

`ops/` is gitignored at the repo root; it never lands in the public repo.

## What's been retired

The previous workflow used a hand-rolled `deploy-production.sh` plus a
PM2 `ecosystem.config.cjs` checked into this directory. Both have been
removed in favour of `lsd`. If you need the historical script, check
the git history before the redact-identifiers cleanup.
