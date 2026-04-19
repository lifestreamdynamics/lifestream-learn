#!/usr/bin/env bash
# =============================================================================
# create-databases.sh
# Idempotent provisioning of the PostgreSQL role and databases that Lifestream
# Learn expects on an already-running Postgres instance. Locally we piggyback
# on accounting-api's `accounting-postgres` container (port 5432); the same
# script works against any shared Postgres we eventually deploy onto.
#
#   role      : learn_api_user
#   databases : learn_api_production, learn_api_development, learn_api_test
#
# Safe to re-run; every CREATE is guarded by a SELECT against pg_roles /
# pg_database so re-invocation is a no-op.
#
# Env (all except LEARN_API_DB_PASSWORD are optional):
#   Project-style vars (read from infra/.env):
#     POSTGRES_HOST                default localhost
#     POSTGRES_PORT                default 5432
#     POSTGRES_SUPERUSER           default postgres (superuser used to bootstrap)
#     POSTGRES_SUPERUSER_PASSWORD  superuser password (optional if peer auth)
#   OR the libpq-standard equivalents (PGHOST / PGPORT / PGUSER / PGPASSWORD)
#   if already exported. Project vars take precedence when both are set.
#
#   LEARN_API_DB_PASSWORD        REQUIRED — password assigned to learn_api_user
#   LEARN_API_DB_USER            default learn_api_user
#   LEARN_API_DBS                space-separated DB list; default
#                                "learn_api_production learn_api_development
#                                 learn_api_test"
#   PSQL                         override the psql binary (used by BATS tests)
# =============================================================================

set -euo pipefail

# Project-style vars take precedence over libpq-standard vars when both exist,
# so a developer's `infra/.env` drives behaviour even in a shell that already
# has PG* exported for another project.
export PGHOST="${POSTGRES_HOST:-${PGHOST:-localhost}}"
export PGPORT="${POSTGRES_PORT:-${PGPORT:-5432}}"
export PGUSER="${POSTGRES_SUPERUSER:-${PGUSER:-postgres}}"
if [[ -n "${POSTGRES_SUPERUSER_PASSWORD:-}" ]]; then
    export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}"
fi
# If neither POSTGRES_SUPERUSER_PASSWORD nor PGPASSWORD is set, leave empty —
# peer/trust auth handles that.

PSQL="${PSQL:-psql}"

LEARN_API_DB_USER="${LEARN_API_DB_USER:-learn_api_user}"
LEARN_API_DBS="${LEARN_API_DBS:-learn_api_production learn_api_development learn_api_test}"

log()  { printf '[create-databases] %s\n' "$*"; }
die()  { printf '[create-databases] ERROR: %s\n' "$*" >&2; exit 1; }

if [[ -z "${LEARN_API_DB_PASSWORD:-}" ]]; then
    die "LEARN_API_DB_PASSWORD is not set. Refusing to create a role with no password."
fi

if ! command -v "${PSQL}" >/dev/null 2>&1; then
    die "psql binary (${PSQL}) not found on PATH."
fi

# Basic validation: role/db names must match postgres identifier rules so we
# can safely interpolate them into SQL without parameterisation.
validate_identifier() {
    local kind="$1"
    local name="$2"
    if [[ ! "${name}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        die "invalid ${kind} name '${name}' — must match [a-zA-Z_][a-zA-Z0-9_]*"
    fi
}

validate_identifier "user" "${LEARN_API_DB_USER}"
for db in ${LEARN_API_DBS}; do
    validate_identifier "database" "${db}"
done

# Escape single quotes inside the password for SQL literal embedding.
escape_sql_literal() {
    printf '%s' "$1" | sed "s/'/''/g"
}

psql_exec() {
    "${PSQL}" -v ON_ERROR_STOP=1 -X -A -t -w "$@"
}

role_exists() {
    local role="$1"
    local out
    out="$(psql_exec -c "SELECT 1 FROM pg_roles WHERE rolname = '$(escape_sql_literal "${role}")';" 2>/dev/null || true)"
    [[ "${out}" == "1" ]]
}

database_exists() {
    local db="$1"
    local out
    out="$(psql_exec -c "SELECT 1 FROM pg_database WHERE datname = '$(escape_sql_literal "${db}")';" 2>/dev/null || true)"
    [[ "${out}" == "1" ]]
}

create_role() {
    local role="$1"
    local password="$2"
    local escaped_password
    escaped_password="$(escape_sql_literal "${password}")"
    if role_exists "${role}"; then
        log "role '${role}' already exists — updating password to match env"
        psql_exec -c "ALTER ROLE \"${role}\" WITH LOGIN PASSWORD '${escaped_password}';"
    else
        log "creating role '${role}'"
        psql_exec -c "CREATE ROLE \"${role}\" WITH LOGIN PASSWORD '${escaped_password}';"
    fi
    # CREATEDB is required so Prisma Migrate can provision its shadow database
    # during `prisma migrate dev`. Scope is limited: the role can only create
    # databases it then owns, and only on this shared Postgres instance.
    log "ensuring '${role}' has CREATEDB for prisma migrate shadow DB"
    psql_exec -c "ALTER ROLE \"${role}\" CREATEDB;"
}

create_database() {
    local db="$1"
    local owner="$2"
    if database_exists "${db}"; then
        log "database '${db}' already exists — skipping create"
    else
        log "creating database '${db}' owned by '${owner}'"
        # CREATE DATABASE cannot run inside a transaction block.
        psql_exec -c "CREATE DATABASE \"${db}\" OWNER \"${owner}\";"
    fi
    # Grants are cheap and idempotent; re-apply every run so that permissions
    # stay correct even if someone tweaked them manually.
    log "granting CONNECT + ALL PRIVILEGES on '${db}' to '${owner}'"
    psql_exec -c "GRANT CONNECT ON DATABASE \"${db}\" TO \"${owner}\";"
    psql_exec -c "GRANT ALL PRIVILEGES ON DATABASE \"${db}\" TO \"${owner}\";"
}

log "host=${PGHOST}:${PGPORT} user=${PGUSER} target_role=${LEARN_API_DB_USER}"
log "databases='${LEARN_API_DBS}'"

create_role "${LEARN_API_DB_USER}" "${LEARN_API_DB_PASSWORD}"

for db in ${LEARN_API_DBS}; do
    create_database "${db}" "${LEARN_API_DB_USER}"
done

log "done."
