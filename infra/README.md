# lifestream-learn-infra

Local development infrastructure for Lifestream Learn. Spins up the object store, upload gateway, and reverse proxy; **Postgres and Redis are not here** — they're borrowed from accounting-api's compose stack (see below).

Deployment is deliberately out of scope. The goal is a fully functional, locally tested app; we'll pick a deploy strategy once the app is ready. Shared-resource discipline (ports, key prefixes, DB naming) is honoured from the start so a later deploy onto a shared host will be conflict-free.

## Shared datastore model

This project does **not** run its own Postgres or Redis. Locally it piggybacks on `accounting-postgres` and `accounting-redis` from accounting-api's compose stack. Isolation is by:

- **Postgres** — a dedicated `learn_api_user` role and three `learn_api_*` databases provisioned via `scripts/create-databases.sh`.
- **Redis** — the `learn:` key prefix (convention matches `accounting:` and `chatbot:`).

When we eventually deploy, the same isolation pattern applies against whichever shared instances live there.

## Contents

| Path | Purpose |
|---|---|
| `docker-compose.yml` | Local stack: seaweedfs, tusd, nginx |
| `.env.example` | Copy to `.env`; host ports + credentials |
| `nginx/` | `secure_link.conf.inc` (reusable HMAC-keyed HLS-URL validation), `local.conf` (plain-HTTP reverse proxy) |
| `seaweedfs/s3.json` | Two-identity S3 IAM: `learn-api-rw` (full) + `tusd-upload` (write-only to `learn-uploads/`) |
| `landing/` | Static HTML: `index.html`, `terms.html`, `privacy.html` |
| `scripts/` | `create-buckets.sh`, `create-databases.sh`, `disk-alert.sh`, `sign-hls-url.sh` (+ BATS tests in `scripts/tests/`) |

## Quick start

**Prerequisite:** accounting-api's local compose stack is up (`accounting-postgres` on `:5432`, `accounting-redis` on `:6379`). Our stack plugs into those.

```bash
cp .env.example .env
# Only edit .env if the default host ports conflict with other projects
# already running on your machine. In-container ports are fixed.

docker compose up -d
# SeaweedFS takes ~10s to pass its healthcheck; tusd and nginx wait on it.

# Provision learn-api's DBs + role on the shared accounting-postgres
# (idempotent — safe to re-run).
set -a; source .env; set +a
./scripts/create-databases.sh

# Bootstrap the two SeaweedFS S3 buckets (idempotent).
# If you don't have the AWS CLI installed locally, wrap it via docker:
cat > /tmp/aws-wrapper <<'EOF'
#!/bin/bash
exec docker run --rm --network host \
  -e AWS_ACCESS_KEY_ID=learn_access_key \
  -e AWS_SECRET_ACCESS_KEY=learn_secret_key \
  amazon/aws-cli "$@"
EOF
chmod +x /tmp/aws-wrapper
S3_ENDPOINT=http://localhost:${SEAWEEDFS_S3_HOST_PORT:-8333} \
  AWS_CLI=/tmp/aws-wrapper \
  ./scripts/create-buckets.sh
```

Smoke tests (after the above):

```bash
set -a; source .env; set +a

# Landing page served by nginx.
curl -sf "http://localhost:${NGINX_HOST_PORT:-80}/"

# HMAC secure_link rejects unsigned /hls/ requests.
curl -s -o /dev/null -w '%{http_code}\n' \
  "http://localhost:${NGINX_HOST_PORT:-80}/hls/anything.m3u8"  # -> 403

# Valid signed URL proxies through to SeaweedFS.
SIGNED=$(./scripts/sign-hls-url.sh /hls/some/path.m3u8)
curl -s -o /dev/null -w '%{http_code}\n' \
  "http://localhost:${NGINX_HOST_PORT:-80}${SIGNED}"
# -> 403 AccessDenied from S3 (no content yet), but nginx validation PASSED.

# Shared datastores.
PGPASSWORD="$LEARN_API_DB_PASSWORD" \
  psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U learn_api_user \
       -d learn_api_development -c 'SELECT 1;'
redis-cli -a "$REDIS_PASSWORD" --no-auth-warning SET learn:ping 1 EX 10
```

The API (Phase 2) will read `POSTGRES_HOST` / `REDIS_HOST` / `S3_ENDPOINT` from the same `.env` and mount alongside this stack.

## Tests

Shell scripts are covered by BATS:

```bash
# Install BATS if you don't have it:
#   sudo apt install bats             # Debian/Ubuntu
#   brew install bats-core            # macOS
# ...or clone bats-core locally and run ./bin/bats.
bats scripts/tests/*.bats
```

Coverage: `create-buckets.bats`, `create-databases.bats`, `disk-alert.bats`, `sign-hls-url.bats` — 34 cases, mock-driven (no live SeaweedFS/Postgres required).

## Known caveats

- **secure_link uses MD5**, not HMAC-SHA256, because stock `nginx-full` only exposes MD5. With a ≥32-byte secret + 2 h TTL this is acceptable for VOD; documented in `nginx/secure_link.conf.inc`. Upgrade path if needed: njs/Lua for HMAC-SHA256.
- **tusd behind reverse proxy** currently emits `Location` headers using the internal tusd URL (`http://localhost/files/...`) rather than the public `/uploads/files/...`. The tus client will follow the Location header as given — fix by passing `-behind-proxy` + `-base-path=/uploads/files/` to tusd, or by rewriting the Location header in nginx. Tracked as a Phase-2-adjacent task since the upload client isn't wired yet.
- **Raw uploads are kept** in `learn-uploads/` by tusd/SeaweedFS until the API (Phase 2) explicitly deletes them after a successful transcode. ADR 0006 requires the delete; wire it in the transcode worker before opening the beta.
- **The `disk-alert.sh` script** is written and tested, but the systemd timer that would schedule it isn't set up — deployment concern, out of scope for now.

## Status

**Phase 1 — complete for MVP scope.** Local compose + BATS suite all green against shared accounting-postgres and accounting-redis. Next: Phase 2 (learn-api scaffold) runs against this local stack.

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
