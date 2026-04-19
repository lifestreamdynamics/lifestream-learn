#!/usr/bin/env bash
# =============================================================================
# disk-alert.sh
# Watches SeaweedFS disk usage and emails an operator when usage crosses the
# configured threshold (default 25 GB — see ADR 0006). Idempotent: suppresses
# duplicate emails within a 24h window by writing an epoch timestamp to a
# marker file.
#
# Designed to be driven by a systemd timer at a 5- to 15-minute cadence.
#
# Env:
#   SEAWEEDFS_DIR   directory to measure; default /var/lib/seaweedfs
#   THRESHOLD_GB    alert threshold in whole GB; default 25
#   ALERT_EMAIL     recipient; default root
#   MARKER_FILE     last-notified marker path;
#                   default /var/lib/learn/disk-alert-last-notified
#   SUPPRESS_SECS   duplicate-email suppression window; default 86400 (24h)
#   MAIL_CMD        binary used to send mail; default mail
#                   (must accept: MAIL_CMD -s "subject" recipient < body)
#   DU_CMD          override du binary (for tests)
#   NOW_CMD         override date +%s source (for tests)
# =============================================================================

set -euo pipefail

SEAWEEDFS_DIR="${SEAWEEDFS_DIR:-/var/lib/seaweedfs}"
THRESHOLD_GB="${THRESHOLD_GB:-25}"
ALERT_EMAIL="${ALERT_EMAIL:-root}"
MARKER_FILE="${MARKER_FILE:-/var/lib/learn/disk-alert-last-notified}"
SUPPRESS_SECS="${SUPPRESS_SECS:-86400}"
MAIL_CMD="${MAIL_CMD:-mail}"
DU_CMD="${DU_CMD:-du}"

log()  { printf '[disk-alert] %s\n' "$*"; }
die()  { printf '[disk-alert] ERROR: %s\n' "$*" >&2; exit 1; }

if [[ ! "${THRESHOLD_GB}" =~ ^[0-9]+$ ]]; then
    die "THRESHOLD_GB must be a positive integer (got '${THRESHOLD_GB}')"
fi

if [[ ! -d "${SEAWEEDFS_DIR}" ]]; then
    die "SEAWEEDFS_DIR '${SEAWEEDFS_DIR}' does not exist or is not a directory"
fi

now_epoch() {
    if [[ -n "${NOW_CMD:-}" ]]; then
        "${NOW_CMD}"
    else
        date +%s
    fi
}

# Read current usage. `du -sBG` emits a single line "42G\t<path>"; strip the G.
current_usage_gb() {
    local out size
    if ! out="$("${DU_CMD}" -sBG "${SEAWEEDFS_DIR}" 2>/dev/null)"; then
        die "failed to run ${DU_CMD} -sBG ${SEAWEEDFS_DIR}"
    fi
    size="${out%%[[:space:]]*}"   # first whitespace-delimited field
    size="${size%G}"               # trim trailing G
    if [[ ! "${size}" =~ ^[0-9]+$ ]]; then
        die "unexpected du output: '${out}'"
    fi
    printf '%s' "${size}"
}

last_notified_epoch() {
    if [[ -s "${MARKER_FILE}" ]]; then
        local val
        val="$(head -n1 "${MARKER_FILE}" | tr -dc '0-9')"
        if [[ -n "${val}" ]]; then
            printf '%s' "${val}"
            return
        fi
    fi
    printf '0'
}

write_marker() {
    local now="$1"
    local dir
    dir="$(dirname "${MARKER_FILE}")"
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
    fi
    printf '%s\n' "${now}" > "${MARKER_FILE}"
}

send_alert() {
    local usage="$1"
    local subject="[lifestream-learn] SeaweedFS usage ${usage}G exceeds ${THRESHOLD_GB}G"
    local body
    body="$(cat <<EOM
SeaweedFS storage on this host has crossed the configured alert threshold.

  path      : ${SEAWEEDFS_DIR}
  usage     : ${usage} GB
  threshold : ${THRESHOLD_GB} GB
  host      : $(hostname -f 2>/dev/null || hostname)

See ADR 0006 for context and the remediation options
(attach block storage, tighten duration cap, prune raw uploads).
EOM
)"
    if ! command -v "${MAIL_CMD}" >/dev/null 2>&1; then
        die "mail command '${MAIL_CMD}' not found — cannot send alert"
    fi
    printf '%s\n' "${body}" | "${MAIL_CMD}" -s "${subject}" "${ALERT_EMAIL}"
}

USAGE_GB="$(current_usage_gb)"
NOW="$(now_epoch)"
LAST="$(last_notified_epoch)"

log "usage=${USAGE_GB}G threshold=${THRESHOLD_GB}G last_notified=${LAST} now=${NOW}"

if (( USAGE_GB < THRESHOLD_GB )); then
    log "below threshold — no alert"
    exit 0
fi

if (( LAST > 0 )) && (( NOW - LAST < SUPPRESS_SECS )); then
    log "within ${SUPPRESS_SECS}s suppression window — skipping duplicate alert"
    exit 0
fi

log "sending alert to ${ALERT_EMAIL}"
send_alert "${USAGE_GB}"
write_marker "${NOW}"
log "alert sent; marker updated"
