#!/usr/bin/env bash
# =============================================================================
# create-buckets.sh
# Idempotent provisioning of the SeaweedFS S3 buckets that Lifestream Learn
# expects: learn-uploads (raw tus uploads) and learn-vod (HLS output).
#
# Safe to re-run. Exits 0 if buckets already exist.
#
# Env:
#   S3_ENDPOINT           default http://localhost:8333
#   AWS_ACCESS_KEY_ID     default learn_access_key  (matches seaweedfs/s3.json)
#   AWS_SECRET_ACCESS_KEY default learn_secret_key
#   AWS_REGION            default us-east-1
#   BUCKETS               space-separated list; default "learn-uploads learn-vod"
#   AWS_CLI               override the aws binary (used by BATS tests)
# =============================================================================

set -euo pipefail

S3_ENDPOINT="${S3_ENDPOINT-http://localhost:8333}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-learn_access_key}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-learn_secret_key}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

AWS_CLI="${AWS_CLI:-aws}"
BUCKETS="${BUCKETS:-learn-uploads learn-vod}"

log()  { printf '[create-buckets] %s\n' "$*"; }
warn() { printf '[create-buckets] WARN: %s\n' "$*" >&2; }
die()  { printf '[create-buckets] ERROR: %s\n' "$*" >&2; exit 1; }

if ! command -v "${AWS_CLI}" >/dev/null 2>&1; then
    die "aws CLI (${AWS_CLI}) not found on PATH. Install awscli or run via 'docker run --rm --network host amazon/aws-cli ...'."
fi

if [[ -z "${S3_ENDPOINT}" ]]; then
    die "S3_ENDPOINT is empty. Set it to e.g. http://localhost:8333."
fi

# Probe the endpoint. s3api list-buckets is cheap and validates creds + reachability.
if ! "${AWS_CLI}" --endpoint-url "${S3_ENDPOINT}" s3api list-buckets >/dev/null 2>&1; then
    die "cannot reach SeaweedFS S3 endpoint at ${S3_ENDPOINT} (is docker compose up?)"
fi

bucket_exists() {
    local bucket="$1"
    "${AWS_CLI}" --endpoint-url "${S3_ENDPOINT}" s3api head-bucket --bucket "${bucket}" >/dev/null 2>&1
}

create_bucket() {
    local bucket="$1"
    if bucket_exists "${bucket}"; then
        log "bucket '${bucket}' already exists — skipping"
        return 0
    fi
    log "creating bucket '${bucket}'"
    if ! "${AWS_CLI}" --endpoint-url "${S3_ENDPOINT}" s3api create-bucket --bucket "${bucket}" >/dev/null; then
        # Another racing invocation may have created it between head and create.
        if bucket_exists "${bucket}"; then
            log "bucket '${bucket}' appeared during create — treating as success"
            return 0
        fi
        die "failed to create bucket '${bucket}'"
    fi
    log "bucket '${bucket}' created"
}

log "endpoint=${S3_ENDPOINT} buckets='${BUCKETS}'"
for bucket in ${BUCKETS}; do
    create_bucket "${bucket}"
done

log "done."
