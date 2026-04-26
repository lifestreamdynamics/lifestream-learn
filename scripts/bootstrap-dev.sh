#!/usr/bin/env bash
# =============================================================================
# bootstrap-dev.sh — one-shot env-file bootstrapper for local development
# =============================================================================
# Run once after `git clone`. Creates:
#   - infra/.env         (copy of infra/.env.example, unmutated)
#   - api/.env.local     (copy of api/.env.example, with real random secrets
#                         filled in and CHANGE_ME placeholders replaced)
#
# Both files are co-dependent: TUSD_HOOK_SECRET must match between them, and
# HLS_SIGNING_SECRET (api) must match SECURE_LINK_SECRET (infra) because nginx
# and the API both compute the same secure_link HMAC.
#
# This script is idempotent: if either target file already exists, it's left
# untouched (operators may have customized values). There is no --force flag;
# rm the file yourself if you want to regenerate.
#
# Verification / side-effects:
#   - Does NOT run docker, npm install, or any DB provisioning — that's the
#     Makefile's job. This script only fills in env files.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INFRA_EXAMPLE="$REPO_ROOT/infra/.env.example"
INFRA_ENV="$REPO_ROOT/infra/.env"
API_EXAMPLE="$REPO_ROOT/api/.env.example"
API_ENV="$REPO_ROOT/api/.env.local"

# ---------- prerequisite checks ---------------------------------------------

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is required but was not found on PATH." >&2
  echo "Install it (e.g. apt install openssl) and re-run." >&2
  exit 1
fi

for f in "$INFRA_EXAMPLE" "$API_EXAMPLE"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: expected template file missing: $f" >&2
    exit 1
  fi
done

# ---------- shared secrets (generated ONCE, written to both files) ----------

# tusd → learn-api webhook auth. 32 hex chars (> 16-char min enforced by the
# API's env validation). Same value must appear in infra/.env and
# api/.env.local so the API's constant-time compare succeeds.
TUSD_HOOK_SECRET_VALUE="$(openssl rand -hex 24)"

# ---------- infra/.env ------------------------------------------------------

if [[ -f "$INFRA_ENV" ]]; then
  echo "infra/.env exists, skipping (remove it first if you want to regenerate)"
else
  cp "$INFRA_EXAMPLE" "$INFRA_ENV"

  # Only mutate TUSD_HOOK_SECRET — everything else in the example ships
  # working dev defaults (S3 keys match infra/seaweedfs/s3.json, and
  # SECURE_LINK_SECRET matches the `set $secure_link_secret` directive baked
  # into infra/nginx/local.conf — do NOT randomize it).
  sed -i.bak \
    -e "s|^TUSD_HOOK_SECRET=.*$|TUSD_HOOK_SECRET=${TUSD_HOOK_SECRET_VALUE}|" \
    "$INFRA_ENV"
  rm -f "$INFRA_ENV.bak"

  echo "created infra/.env"
fi

# ---------- api/.env.local --------------------------------------------------

if [[ -f "$API_ENV" ]]; then
  echo "api/.env.local exists, skipping (remove it first if you want to regenerate)"
else
  cp "$API_EXAMPLE" "$API_ENV"

  # JWT secrets: two different high-entropy values. base64(48 bytes) = 64 chars.
  JWT_ACCESS_SECRET_VALUE="$(openssl rand -base64 48)"
  JWT_REFRESH_SECRET_VALUE="$(openssl rand -base64 48)"
  # Slice P6 — per-install salt for hashing remote IPs on Session rows.
  # Must be >=32 chars (env schema enforces this); using hex keeps the
  # value sed-delimiter-safe.
  IP_HASH_SALT_VALUE="$(openssl rand -hex 32)"
  # Slice P7a — AES-256-GCM key for encrypting MFA TOTP secrets at
  # rest. `openssl rand -base64 32` yields a 44-char value that
  # decodes to exactly 32 bytes, matching the env schema.
  MFA_ENCRYPTION_KEY_VALUE="$(openssl rand -base64 32)"

  # Resolve NGINX_HOST_PORT from infra/.env so HLS_BASE_URL points at the
  # same host port docker-compose actually publishes nginx on. Mirrors the
  # canonical pattern in Makefile (`NGINX_HOST_PORT := $(shell ...)` near
  # the top of the file). Falls back to 80 — the docker-compose default
  # — when infra/.env is absent or doesn't override the port.
  NGINX_HOST_PORT_VALUE="80"
  if [[ -f "$INFRA_ENV" ]]; then
    port_line="$(grep -E '^NGINX_HOST_PORT=' "$INFRA_ENV" | tail -1 | cut -d= -f2- || true)"
    if [[ -n "${port_line:-}" ]]; then
      NGINX_HOST_PORT_VALUE="$port_line"
    fi
  fi

  # Use '|' delimiter for any value that may contain '/', '+', '=', or ':'.
  # openssl base64 output contains '/' and '+'; URLs contain '/' and ':'.
  sed -i.bak \
    -e "s|^JWT_ACCESS_SECRET=.*$|JWT_ACCESS_SECRET=${JWT_ACCESS_SECRET_VALUE}|" \
    -e "s|^JWT_REFRESH_SECRET=.*$|JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET_VALUE}|" \
    -e "s|^IP_HASH_SALT=.*$|IP_HASH_SALT=${IP_HASH_SALT_VALUE}|" \
    -e "s|^MFA_ENCRYPTION_KEY=.*$|MFA_ENCRYPTION_KEY=${MFA_ENCRYPTION_KEY_VALUE}|" \
    -e "s|^WEBAUTHN_RP_ID=.*$|WEBAUTHN_RP_ID=localhost|" \
    -e "s|^WEBAUTHN_ORIGIN=.*$|WEBAUTHN_ORIGIN=http://localhost:3011|" \
    -e "s|^S3_ACCESS_KEY=.*$|S3_ACCESS_KEY=learn_access_key|" \
    -e "s|^S3_SECRET_KEY=.*$|S3_SECRET_KEY=learn_secret_key|" \
    -e "s|^HLS_SIGNING_SECRET=.*$|HLS_SIGNING_SECRET=local_dev_secret_do_not_use_in_prod|" \
    -e "s|^HLS_BASE_URL=.*$|HLS_BASE_URL=http://10.0.2.2:${NGINX_HOST_PORT_VALUE}/hls|" \
    -e "s|^TUSD_HOOK_SECRET=.*$|TUSD_HOOK_SECRET=${TUSD_HOOK_SECRET_VALUE}|" \
    -e "s|^SEED_ADMIN_PASSWORD=.*$|SEED_ADMIN_PASSWORD=Dev12345!Pass|" \
    -e "s|^SEED_DEV_USER_PASSWORD=.*$|SEED_DEV_USER_PASSWORD=Dev12345!Pass|" \
    -e "s|^DATABASE_URL=postgresql://learn_api_user:CHANGE_ME@|DATABASE_URL=postgresql://learn_api_user:learn_dev@|" \
    "$API_ENV"
  rm -f "$API_ENV.bak"

  echo "created api/.env.local"
fi

# ---------- final credentials report ----------------------------------------

cat <<'EOF'

Bootstrap complete

Dev users (created by `make seed` / `npm run prisma:seed`):
  admin@example.local       Dev12345!Pass
  designer@example.local    Dev12345!Pass
  learner@example.local     Dev12345!Pass

Next: run `make up` from the repo root.
EOF
