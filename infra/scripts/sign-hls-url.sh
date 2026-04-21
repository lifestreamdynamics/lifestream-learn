#!/usr/bin/env bash
# =============================================================================
# sign-hls-url.sh — produce a secure_link-compatible signed URL for HLS
# =============================================================================
# Usage:
#   SECURE_LINK_SECRET=<secret> ./sign-hls-url.sh <videoId> [ttl-seconds]
#
# Example:
#   SECURE_LINK_SECRET=local_dev_secret_do_not_use_in_prod \
#     ./sign-hls-url.sh abc 7200
#
# Writes one line to stdout:
#   /hls/<sig>/<expires>/<videoId>/master.m3u8
#
# The URL shape embeds the signature and expiry into the PATH (not the
# query string). HLS players do NOT propagate the parent URL's query
# string to relative child requests (RFC 3986 §5.3), so a query-string
# token cannot authorize variant playlists or segments. Putting the token
# in the path lets every relative URL inside the playlist carry it
# structurally. Nginx strips the `<sig>/<expires>/` prefix via an
# internal rewrite before `secure_link` runs — see
# `infra/nginx/local.conf`.
#
# Signing scheme:
#   sig = base64url( md5( "<expires>/hls/<videoId>/ <secret>" ) )
# where base64url means base64 with '+' -> '-', '/' -> '_', '=' stripped.
#
# Exit codes:
#   0  success
#   1  bad arguments or missing secret
# =============================================================================

set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: SECURE_LINK_SECRET=<secret> $0 <videoId> [ttl-seconds]

  <videoId>       The video id to sign a playback URL for (no slashes).
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

video_id="$1"
ttl="${2:-7200}"

if [[ -z "${SECURE_LINK_SECRET:-}" ]]; then
  echo "ERROR: SECURE_LINK_SECRET environment variable is required." >&2
  exit 1
fi

if [[ -z "$video_id" || "$video_id" == */* ]]; then
  echo "ERROR: <videoId> must be non-empty and contain no slashes." >&2
  exit 1
fi

if ! [[ "$ttl" =~ ^[0-9]+$ ]]; then
  echo "ERROR: ttl-seconds must be a non-negative integer." >&2
  exit 1
fi

# Allow callers to override the clock for deterministic testing.
now="${NOW_OVERRIDE:-$(date +%s)}"
expires=$(( now + ttl ))

# Signed expression is the logical prefix `/hls/<videoId>/` — with trailing
# slash — so one signature authorizes every URL under it (master, variant
# playlists, init segments, media segments). Nginx reconstructs this same
# expression from the captured path segments and recomputes the hash.
signed_prefix="/hls/${video_id}/"
input="${expires}${signed_prefix} ${SECURE_LINK_SECRET}"

# md5 -> 16 raw bytes -> base64 -> base64url (strip =, swap +/ for -/_).
sig=$(printf '%s' "$input" \
  | openssl dgst -md5 -binary \
  | openssl base64 -A \
  | tr '+/' '-_' \
  | tr -d '=')

printf '/hls/%s/%s/%s/master.m3u8\n' "$sig" "$expires" "$video_id"
