#!/usr/bin/env bash
# =============================================================================
# sign-hls-url.sh — produce a secure_link-compatible signed URL for HLS
# =============================================================================
# Usage:
#   SECURE_LINK_SECRET=<secret> ./sign-hls-url.sh <uri-path> [ttl-seconds]
#
# Example:
#   SECURE_LINK_SECRET=local_dev_secret_do_not_use_in_prod \
#     ./sign-hls-url.sh /hls/abc/master.m3u8 7200
#
# Writes one line to stdout:
#   /hls/abc/master.m3u8?md5=<base64url>&expires=<unix_ts>
#
# The scheme must match nginx/secure_link.conf.inc exactly:
#   hash = base64url( md5( "{expires}{uri} {secret}" ) )
# where base64url means base64 with '+' -> '-', '/' -> '_', '=' stripped.
#
# Exit codes:
#   0  success
#   1  bad arguments or missing secret
# =============================================================================

set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: SECURE_LINK_SECRET=<secret> $0 <uri-path> [ttl-seconds]

  <uri-path>      The path to sign, must start with /hls/ (e.g. /hls/abc/master.m3u8)
  [ttl-seconds]   How long the URL stays valid. Default 7200 (2h).

Environment:
  SECURE_LINK_SECRET   Required. High-entropy shared secret matching the
                       value configured in nginx (set \$secure_link_secret).
EOF
  exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

uri="$1"
ttl="${2:-7200}"

if [[ -z "${SECURE_LINK_SECRET:-}" ]]; then
  echo "ERROR: SECURE_LINK_SECRET environment variable is required." >&2
  exit 1
fi

if [[ "$uri" != /* ]]; then
  echo "ERROR: <uri-path> must be absolute (start with /)." >&2
  exit 1
fi

if ! [[ "$ttl" =~ ^[0-9]+$ ]]; then
  echo "ERROR: ttl-seconds must be a non-negative integer." >&2
  exit 1
fi

# Allow callers to override the clock for deterministic testing.
now="${NOW_OVERRIDE:-$(date +%s)}"
expires=$(( now + ttl ))

# Input to md5: concatenation of expires, uri, space, secret — exactly what
# nginx computes from `secure_link_md5 "$secure_link_expires$uri $secret"`.
input="${expires}${uri} ${SECURE_LINK_SECRET}"

# md5 -> 16 raw bytes -> base64 -> base64url (strip =, swap +/ for -/_).
hash=$(printf '%s' "$input" \
  | openssl dgst -md5 -binary \
  | openssl base64 -A \
  | tr '+/' '-_' \
  | tr -d '=')

printf '%s?md5=%s&expires=%s\n' "$uri" "$hash" "$expires"
