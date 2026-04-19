#!/usr/bin/env bats
# Tests for infra/scripts/create-databases.sh.
#
# Mocks the psql CLI with a shell script that records invocations and
# maintains a tiny "registry" file tracking known roles and databases, so
# the system-under-test's SELECT ... FROM pg_roles / pg_database probes
# return the expected values.
#
# Run from repo root:  bats infra/scripts/tests/create-databases.bats

setup() {
    SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    SCRIPT="${SCRIPT_DIR}/create-databases.sh"
    [[ -x "${SCRIPT}" ]] || chmod +x "${SCRIPT}"

    BATS_TMP="$(mktemp -d)"
    export BATS_TMP
    export MOCK_ROLES="${BATS_TMP}/roles.state"
    export MOCK_DBS="${BATS_TMP}/dbs.state"
    export MOCK_LOG="${BATS_TMP}/psql.log"
    : > "${MOCK_ROLES}"
    : > "${MOCK_DBS}"
    : > "${MOCK_LOG}"

    MOCK_BIN="${BATS_TMP}/bin"
    mkdir -p "${MOCK_BIN}"
    cat > "${MOCK_BIN}/psql" <<'MOCK'
#!/usr/bin/env bash
# Mock psql for create-databases tests.
#
# Parses just enough of psql's CLI to answer the SELECTs and run the
# CREATE/ALTER/GRANT statements the script issues. State is kept in
# $MOCK_ROLES and $MOCK_DBS (one identifier per line).

set -u

echo "psql $*" >> "${MOCK_LOG:-/dev/null}"

sql=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c) sql="$2"; shift 2 ;;
        -v|--set) shift 2 ;;
        -X|-A|-t|-w|--no-psqlrc|--no-align|--tuples-only|--no-password) shift ;;
        *) shift ;;
    esac
done

roles="${MOCK_ROLES:?MOCK_ROLES not set}"
dbs="${MOCK_DBS:?MOCK_DBS not set}"
touch "${roles}" "${dbs}"

extract_name() {
    # crude but effective: match the first single-quoted literal in the SQL
    local s="$1"
    local rest="${s#*\'}"
    local name="${rest%%\'*}"
    printf '%s' "${name}"
}

extract_quoted_ident() {
    # match first double-quoted identifier
    local s="$1"
    local rest="${s#*\"}"
    local name="${rest%%\"*}"
    printf '%s' "${name}"
}

case "${sql}" in
    *"FROM pg_roles WHERE rolname"*)
        name="$(extract_name "${sql}")"
        if grep -qxF "${name}" "${roles}"; then
            echo "1"
        fi
        exit 0
        ;;
    *"FROM pg_database WHERE datname"*)
        name="$(extract_name "${sql}")"
        if grep -qxF "${name}" "${dbs}"; then
            echo "1"
        fi
        exit 0
        ;;
    "CREATE ROLE"*)
        name="$(extract_quoted_ident "${sql}")"
        if grep -qxF "${name}" "${roles}"; then
            echo "ERROR: role already exists" >&2
            exit 1
        fi
        printf '%s\n' "${name}" >> "${roles}"
        echo "CREATE ROLE"
        exit 0
        ;;
    "ALTER ROLE"*)
        name="$(extract_quoted_ident "${sql}")"
        if ! grep -qxF "${name}" "${roles}"; then
            echo "ERROR: role missing" >&2
            exit 1
        fi
        echo "ALTER ROLE"
        exit 0
        ;;
    "CREATE DATABASE"*)
        name="$(extract_quoted_ident "${sql}")"
        if grep -qxF "${name}" "${dbs}"; then
            echo "ERROR: db already exists" >&2
            exit 1
        fi
        printf '%s\n' "${name}" >> "${dbs}"
        echo "CREATE DATABASE"
        exit 0
        ;;
    "GRANT"*)
        echo "GRANT"
        exit 0
        ;;
    *)
        echo "mock-psql: unhandled SQL: ${sql}" >&2
        exit 2
        ;;
esac
MOCK
    chmod +x "${MOCK_BIN}/psql"

    export PATH="${MOCK_BIN}:${PATH}"
    export PSQL="psql"
    export PGHOST="localhost"
    export PGUSER="postgres"
    export LEARN_API_DB_PASSWORD="test_pw_with_'apostrophe"
}

teardown() {
    rm -rf "${BATS_TMP}"
}

roles_count() { grep -cve '^$' "${MOCK_ROLES}" || true; }
dbs_count()   { grep -cve '^$' "${MOCK_DBS}"   || true; }

@test "first run creates role and three databases" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qxF "learn_api_user" "${MOCK_ROLES}"
    [ "$(roles_count)" -eq 1 ]
    grep -qxF "learn_api_production" "${MOCK_DBS}"
    grep -qxF "learn_api_development" "${MOCK_DBS}"
    grep -qxF "learn_api_test" "${MOCK_DBS}"
    [ "$(dbs_count)" -eq 3 ]
    [[ "${output}" == *"creating role 'learn_api_user'"* ]]
    [[ "${output}" == *"creating database 'learn_api_production'"* ]]
}

@test "second run is a no-op (idempotent)" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    before_roles="$(roles_count)"
    before_dbs="$(dbs_count)"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(roles_count)" -eq "${before_roles}" ]
    [ "$(dbs_count)" -eq "${before_dbs}" ]
    [[ "${output}" == *"role 'learn_api_user' already exists"* ]]
    [[ "${output}" == *"already exists — skipping create"* ]]
}

@test "missing LEARN_API_DB_PASSWORD fails with clear error" {
    unset LEARN_API_DB_PASSWORD
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"LEARN_API_DB_PASSWORD is not set"* ]]
    # Must have done no work
    [ "$(roles_count)" -eq 0 ]
    [ "$(dbs_count)" -eq 0 ]
}

@test "missing psql binary fails with clear error" {
    export PSQL="definitely-not-a-real-binary-xyz"
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"not found on PATH"* ]]
}

@test "invalid role name is rejected before any psql call" {
    export LEARN_API_DB_USER="bad; drop table users"
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"invalid user name"* ]]
    [ ! -s "${MOCK_LOG}" ]
}

@test "invalid db name is rejected before any psql call" {
    export LEARN_API_DBS="good_db bad-db"
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"invalid database name 'bad-db'"* ]]
}

@test "honours LEARN_API_DBS override" {
    export LEARN_API_DBS="only_one_db"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(dbs_count)" -eq 1 ]
    grep -qxF "only_one_db" "${MOCK_DBS}"
}

@test "second run updates role password via ALTER ROLE" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    : > "${MOCK_LOG}"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "ALTER ROLE" "${MOCK_LOG}"
}

@test "POSTGRES_* project-style vars take precedence over libpq PG* vars" {
    export PGHOST="wrong-libpq-host"
    export PGPORT="1111"
    export PGUSER="wrong-libpq-user"
    export POSTGRES_HOST="right-project-host"
    export POSTGRES_PORT="5432"
    export POSTGRES_SUPERUSER="right-project-user"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"host=right-project-host:5432 user=right-project-user"* ]]
}
