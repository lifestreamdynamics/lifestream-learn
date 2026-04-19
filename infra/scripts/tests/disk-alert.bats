#!/usr/bin/env bats
# Tests for infra/scripts/disk-alert.sh.
#
# Mocks `du` (controls reported usage), `mail` (records invocations), and
# uses NOW_CMD to control the "current time" seen by the script.
#
# Run from repo root:  bats infra/scripts/tests/disk-alert.bats

setup() {
    SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    SCRIPT="${SCRIPT_DIR}/disk-alert.sh"
    [[ -x "${SCRIPT}" ]] || chmod +x "${SCRIPT}"

    BATS_TMP="$(mktemp -d)"
    export BATS_TMP
    export SEAWEEDFS_DIR="${BATS_TMP}/seaweedfs"
    export MARKER_FILE="${BATS_TMP}/marker"
    export MOCK_MAIL_LOG="${BATS_TMP}/mail.log"
    mkdir -p "${SEAWEEDFS_DIR}"

    # Used by the mock du to decide what size to return.
    export MOCK_USAGE_GB="1"

    MOCK_BIN="${BATS_TMP}/bin"
    mkdir -p "${MOCK_BIN}"

    cat > "${MOCK_BIN}/du" <<'MOCK'
#!/usr/bin/env bash
# Mock du: ignore args, print "${MOCK_USAGE_GB}G\t<last-arg>" like the real thing.
set -u
last=""
for a in "$@"; do last="$a"; done
printf '%sG\t%s\n' "${MOCK_USAGE_GB:-0}" "${last}"
MOCK
    chmod +x "${MOCK_BIN}/du"

    cat > "${MOCK_BIN}/mail" <<'MOCK'
#!/usr/bin/env bash
# Mock mail: log args and stdin to $MOCK_MAIL_LOG.
set -u
{
    echo "--- mail invoked ---"
    echo "argv: $*"
    echo "stdin:"
    cat
    echo "--- end ---"
} >> "${MOCK_MAIL_LOG:-/dev/null}"
MOCK
    chmod +x "${MOCK_BIN}/mail"

    cat > "${MOCK_BIN}/fake-now" <<'MOCK'
#!/usr/bin/env bash
printf '%s' "${MOCK_NOW:-1000000000}"
MOCK
    chmod +x "${MOCK_BIN}/fake-now"

    export PATH="${MOCK_BIN}:${PATH}"
    export DU_CMD="du"
    export MAIL_CMD="mail"
    export NOW_CMD="${MOCK_BIN}/fake-now"
}

teardown() {
    rm -rf "${BATS_TMP}"
}

mail_invocations() {
    if [[ -f "${MOCK_MAIL_LOG}" ]]; then
        grep -c "^--- mail invoked ---" "${MOCK_MAIL_LOG}" || true
    else
        echo 0
    fi
}

@test "below threshold: no email sent, no marker written" {
    export MOCK_USAGE_GB="10"
    export THRESHOLD_GB="25"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"below threshold"* ]]
    [ "$(mail_invocations)" -eq 0 ]
    [ ! -f "${MARKER_FILE}" ]
}

@test "above threshold with no marker: email sent and marker written" {
    export MOCK_USAGE_GB="30"
    export THRESHOLD_GB="25"
    export MOCK_NOW="2000000000"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(mail_invocations)" -eq 1 ]
    [ -f "${MARKER_FILE}" ]
    [ "$(cat "${MARKER_FILE}")" = "2000000000" ]
    grep -q 'SeaweedFS usage 30G exceeds 25G' "${MOCK_MAIL_LOG}"
}

@test "above threshold exactly equal: email sent" {
    export MOCK_USAGE_GB="25"
    export THRESHOLD_GB="25"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(mail_invocations)" -eq 1 ]
}

@test "recently notified (marker fresh): no duplicate email" {
    export MOCK_USAGE_GB="30"
    export THRESHOLD_GB="25"
    # marker says last-notified = 2000000000; now = 2000000060 (60s later)
    printf '2000000000\n' > "${MARKER_FILE}"
    export MOCK_NOW="2000000060"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"suppression window"* ]]
    [ "$(mail_invocations)" -eq 0 ]
    # marker untouched
    [ "$(cat "${MARKER_FILE}")" = "2000000000" ]
}

@test "stale marker (>24h): email sent and marker refreshed" {
    export MOCK_USAGE_GB="30"
    export THRESHOLD_GB="25"
    # marker says last = 2000000000; now = 2000000000 + 86401 (just over 24h)
    printf '2000000000\n' > "${MARKER_FILE}"
    export MOCK_NOW="2000086401"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(mail_invocations)" -eq 1 ]
    [ "$(cat "${MARKER_FILE}")" = "2000086401" ]
}

@test "missing SeaweedFS dir: clear error, not a crash" {
    export SEAWEEDFS_DIR="${BATS_TMP}/definitely-not-there"
    export MOCK_USAGE_GB="30"
    export THRESHOLD_GB="25"
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"does not exist"* ]]
    [ "$(mail_invocations)" -eq 0 ]
}

@test "non-numeric threshold: clear error" {
    export THRESHOLD_GB="twenty"
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"must be a positive integer"* ]]
}

@test "mail binary missing: clear error when trying to send" {
    export MOCK_USAGE_GB="30"
    export THRESHOLD_GB="25"
    export MAIL_CMD="definitely-not-a-real-binary-xyz"
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"not found"* ]]
}

@test "marker with whitespace/newline is parsed tolerantly" {
    export MOCK_USAGE_GB="30"
    export THRESHOLD_GB="25"
    printf '   2000000000   \n' > "${MARKER_FILE}"
    export MOCK_NOW="2000000100"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"suppression window"* ]]
    [ "$(mail_invocations)" -eq 0 ]
}

@test "alerts to custom ALERT_EMAIL" {
    export MOCK_USAGE_GB="30"
    export THRESHOLD_GB="25"
    export ALERT_EMAIL="ops@example.invalid"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q 'ops@example.invalid' "${MOCK_MAIL_LOG}"
}
