#!/usr/bin/env bats
# Tests for infra/scripts/create-buckets.sh.
# Mocks the aws CLI with a bash script that records invocations and tracks
# bucket state in a temporary "registry" file. Requires no SeaweedFS.
#
# Run from repo root:  bats infra/scripts/tests/create-buckets.bats

setup() {
    SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    SCRIPT="${SCRIPT_DIR}/create-buckets.sh"
    [[ -x "${SCRIPT}" ]] || chmod +x "${SCRIPT}"

    BATS_TMP="$(mktemp -d)"
    export BATS_TMP
    export MOCK_REGISTRY="${BATS_TMP}/buckets.state"
    export MOCK_LOG="${BATS_TMP}/aws.log"
    : > "${MOCK_REGISTRY}"
    : > "${MOCK_LOG}"

    # Build a fake 'aws' that understands the s3api subcommands we use.
    MOCK_BIN="${BATS_TMP}/bin"
    mkdir -p "${MOCK_BIN}"
    cat > "${MOCK_BIN}/aws" <<'MOCK'
#!/usr/bin/env bash
# Mock aws CLI for create-buckets tests.
# Accepts: aws --endpoint-url URL s3api <list-buckets|head-bucket|create-bucket> [--bucket NAME]
# State is kept in $MOCK_REGISTRY (one bucket name per line).
# If $MOCK_ENDPOINT_DOWN=1, list-buckets fails (simulates unreachable endpoint).

set -u
echo "aws $*" >> "${MOCK_LOG:-/dev/null}"

endpoint=""
cmd=""
sub=""
bucket=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --endpoint-url) endpoint="$2"; shift 2 ;;
        --bucket) bucket="$2"; shift 2 ;;
        s3api) cmd="s3api"; sub="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "${endpoint}" ]]; then
    echo "mock-aws: missing --endpoint-url" >&2
    exit 2
fi

registry="${MOCK_REGISTRY:?MOCK_REGISTRY not set}"
touch "${registry}"

case "${sub}" in
    list-buckets)
        if [[ "${MOCK_ENDPOINT_DOWN:-0}" == "1" ]]; then
            echo "mock-aws: endpoint ${endpoint} unreachable" >&2
            exit 1
        fi
        # Print something aws-like; the real script only checks exit code.
        echo '{"Buckets": []}'
        exit 0
        ;;
    head-bucket)
        [[ -n "${bucket}" ]] || { echo "mock-aws: head-bucket requires --bucket" >&2; exit 2; }
        if grep -qxF "${bucket}" "${registry}"; then
            exit 0
        fi
        exit 254  # s3api returns non-zero for missing bucket
        ;;
    create-bucket)
        [[ -n "${bucket}" ]] || { echo "mock-aws: create-bucket requires --bucket" >&2; exit 2; }
        if grep -qxF "${bucket}" "${registry}"; then
            echo "mock-aws: bucket already exists" >&2
            exit 1
        fi
        printf '%s\n' "${bucket}" >> "${registry}"
        echo "{\"Location\": \"/${bucket}\"}"
        exit 0
        ;;
    *)
        echo "mock-aws: unhandled subcommand '${sub}'" >&2
        exit 2
        ;;
esac
MOCK
    chmod +x "${MOCK_BIN}/aws"

    export PATH="${MOCK_BIN}:${PATH}"
    export AWS_CLI="aws"
    export S3_ENDPOINT="http://localhost:8333"
    export AWS_ACCESS_KEY_ID="test_key"
    export AWS_SECRET_ACCESS_KEY="test_secret"
}

teardown() {
    rm -rf "${BATS_TMP}"
}

registry_count() {
    # Count non-empty lines
    grep -cve '^$' "${MOCK_REGISTRY}" || true
}

@test "creates both buckets when neither exists" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qxF "learn-uploads" "${MOCK_REGISTRY}"
    grep -qxF "learn-vod" "${MOCK_REGISTRY}"
    [ "$(registry_count)" -eq 2 ]
    [[ "${output}" == *"creating bucket 'learn-uploads'"* ]]
    [[ "${output}" == *"creating bucket 'learn-vod'"* ]]
}

@test "re-running is idempotent (no duplicates, no failure)" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    first_count="$(registry_count)"
    [ "${first_count}" -eq 2 ]

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(registry_count)" -eq 2 ]
    [[ "${output}" == *"already exists"* ]]
}

@test "partial state: only missing bucket is created" {
    printf 'learn-uploads\n' > "${MOCK_REGISTRY}"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(registry_count)" -eq 2 ]
    [[ "${output}" == *"learn-uploads' already exists"* ]]
    [[ "${output}" == *"creating bucket 'learn-vod'"* ]]
}

@test "fails clearly when endpoint is unreachable" {
    export MOCK_ENDPOINT_DOWN=1
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"cannot reach SeaweedFS S3 endpoint"* ]]
}

@test "fails clearly when endpoint is empty" {
    export S3_ENDPOINT=""
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"S3_ENDPOINT is empty"* ]]
}

@test "fails clearly when aws CLI is missing" {
    export AWS_CLI="definitely-not-a-real-binary-xyz"
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"not found on PATH"* ]]
}

@test "honours BUCKETS override" {
    export BUCKETS="alpha beta gamma"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(registry_count)" -eq 3 ]
    grep -qxF "alpha" "${MOCK_REGISTRY}"
    grep -qxF "beta" "${MOCK_REGISTRY}"
    grep -qxF "gamma" "${MOCK_REGISTRY}"
}
