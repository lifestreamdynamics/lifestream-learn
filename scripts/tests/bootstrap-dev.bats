#!/usr/bin/env bats
# Tests for scripts/bootstrap-dev.sh.
#
# The script derives its repo root from BASH_SOURCE so we run the real script
# against a fake repo tree (tmpdir/scripts/bootstrap-dev.sh -> tmpdir/{api,infra}).
# This isolates the test from the real .env files and lets us assert on the
# generated api/.env.local without touching the developer's working copy.
#
# Run from repo root:  bats scripts/tests/bootstrap-dev.bats

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    REAL_SCRIPT="${REPO_ROOT}/scripts/bootstrap-dev.sh"
    REAL_API_EXAMPLE="${REPO_ROOT}/api/.env.example"
    REAL_INFRA_EXAMPLE="${REPO_ROOT}/infra/.env.example"
    [[ -f "${REAL_SCRIPT}" ]] || skip "bootstrap-dev.sh not found"

    BATS_TMP="$(mktemp -d)"
    export BATS_TMP

    mkdir -p "${BATS_TMP}/scripts" "${BATS_TMP}/api" "${BATS_TMP}/infra"
    cp "${REAL_SCRIPT}" "${BATS_TMP}/scripts/bootstrap-dev.sh"
    cp "${REAL_API_EXAMPLE}" "${BATS_TMP}/api/.env.example"
    cp "${REAL_INFRA_EXAMPLE}" "${BATS_TMP}/infra/.env.example"
    chmod +x "${BATS_TMP}/scripts/bootstrap-dev.sh"

    SCRIPT="${BATS_TMP}/scripts/bootstrap-dev.sh"
    API_ENV="${BATS_TMP}/api/.env.local"
    INFRA_ENV="${BATS_TMP}/infra/.env"
}

teardown() {
    rm -rf "${BATS_TMP}"
}

hls_base_url() {
    grep -E '^HLS_BASE_URL=' "${API_ENV}" | cut -d= -f2-
}

@test "writes infra/.env and api/.env.local on a fresh tree" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${INFRA_ENV}" ]
    [ -f "${API_ENV}" ]
}

@test "default HLS_BASE_URL falls back to nginx port 80 when infra/.env has no override" {
    # The .env.example template ships NGINX_HOST_PORT as a commented line,
    # so the bootstrap-written infra/.env will have no active override.
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    result="$(hls_base_url)"
    [ "${result}" = "http://10.0.2.2:80/hls" ]
}

@test "respects NGINX_HOST_PORT override in infra/.env (regression for CPR-005/007)" {
    # Pre-seed infra/.env with the operator-customized port BEFORE bootstrap
    # writes the API env, so the script's NGINX_HOST_PORT lookup sees 8090.
    cp "${BATS_TMP}/infra/.env.example" "${INFRA_ENV}"
    printf '\nNGINX_HOST_PORT=8090\n' >> "${INFRA_ENV}"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    result="$(hls_base_url)"
    [ "${result}" = "http://10.0.2.2:8090/hls" ]
}

@test "is idempotent: re-running does not overwrite api/.env.local" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    first_url="$(hls_base_url)"

    # Mutate the file and re-run; the script should leave it alone.
    sed -i "s|^HLS_BASE_URL=.*|HLS_BASE_URL=http://10.0.2.2:9999/hls|" "${API_ENV}"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"api/.env.local exists, skipping"* ]]
    result="$(hls_base_url)"
    [ "${result}" = "http://10.0.2.2:9999/hls" ]
    [ "${result}" != "${first_url}" ]
}

@test "TUSD_HOOK_SECRET matches between infra/.env and api/.env.local" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    infra_secret="$(grep -E '^TUSD_HOOK_SECRET=' "${INFRA_ENV}" | cut -d= -f2-)"
    api_secret="$(grep -E '^TUSD_HOOK_SECRET=' "${API_ENV}" | cut -d= -f2-)"
    [ -n "${infra_secret}" ]
    [ "${infra_secret}" = "${api_secret}" ]
    # The constant-time compare in the API requires >=16 chars.
    [ "${#infra_secret}" -ge 16 ]
}

@test "exits with clear error when openssl is missing" {
    # Shadow openssl by inserting a stub `command` builtin override-via-fake.
    # We can't strip openssl from PATH without losing /usr/bin (the script's
    # shebang and other tools), so instead we put an early PATH dir whose
    # `openssl` is a script that exits 127 — but command -v looks for an
    # executable existing under the name, so the simplest portable trick is
    # to override PATH to a curated directory that has every coreutil EXCEPT
    # openssl. Build that directory by symlinking common binaries from /usr/bin
    # and /bin and pointedly omitting openssl.
    STUB_BIN="${BATS_TMP}/stub-bin"
    mkdir -p "${STUB_BIN}"
    for bin in bash sh sed cat cp rm mkdir grep cut tail head printf chmod test \
               dirname basename true false; do
        if real_path="$(command -v "${bin}" 2>/dev/null)"; then
            ln -sf "${real_path}" "${STUB_BIN}/${bin}"
        fi
    done

    PATH="${STUB_BIN}" run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"openssl is required"* ]]
}

@test "exits with clear error when api/.env.example is missing" {
    rm "${BATS_TMP}/api/.env.example"
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"expected template file missing"* ]]
}
