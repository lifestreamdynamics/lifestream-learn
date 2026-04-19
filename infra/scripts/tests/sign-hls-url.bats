#!/usr/bin/env bats
# =============================================================================
# sign-hls-url.bats — tests for infra/scripts/sign-hls-url.sh
# =============================================================================
# Run from the repo root (or infra/):
#   bats infra/scripts/tests/sign-hls-url.bats
#
# Tests cover:
#   1. Output format: /path?md5=<base64url>&expires=<unix_ts>
#   2. Known-input -> known-output round trip (pinned clock + fixed secret)
#   3. Missing SECURE_LINK_SECRET aborts with non-zero exit
#   4. Non-absolute URI aborts
#   5. Non-numeric TTL aborts
#   6. Default TTL is 7200s (2h)
# =============================================================================

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../sign-hls-url.sh"
  [ -x "$SCRIPT" ] || chmod +x "$SCRIPT"
}

@test "emits URL matching /path?md5=<base64url>&expires=<ts>" {
  run env SECURE_LINK_SECRET=some_secret "$SCRIPT" /hls/x/master.m3u8 60
  [ "$status" -eq 0 ]
  # One line. Base64url alphabet = [A-Za-z0-9_-], no '=' padding.
  [[ "$output" =~ ^/hls/x/master\.m3u8\?md5=[A-Za-z0-9_-]+\&expires=[0-9]+$ ]]
}

@test "known-input -> known-output (fixed secret + pinned clock)" {
  # NOW_OVERRIDE pins the clock to 2023-11-14 22:13:20 UTC.
  # Expected signature computed offline and checked against nginx's own
  # secure_link_md5 "$secure_link_expires$uri $secret" expression.
  run env \
    SECURE_LINK_SECRET=local_dev_secret_do_not_use_in_prod \
    NOW_OVERRIDE=1700000000 \
    "$SCRIPT" /hls/abc/master.m3u8 7200
  [ "$status" -eq 0 ]
  [ "$output" = "/hls/abc/master.m3u8?md5=2xTxZPCSUDTAWi-Z3hiivw&expires=1700007200" ]
}

@test "missing SECURE_LINK_SECRET is a fatal error" {
  run env -u SECURE_LINK_SECRET "$SCRIPT" /hls/x/master.m3u8 60
  [ "$status" -ne 0 ]
  [[ "$output" == *"SECURE_LINK_SECRET"* ]]
}

@test "non-absolute URI is rejected" {
  run env SECURE_LINK_SECRET=s "$SCRIPT" hls/x/master.m3u8 60
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be absolute"* ]]
}

@test "non-numeric TTL is rejected" {
  run env SECURE_LINK_SECRET=s "$SCRIPT" /hls/x.m3u8 notanumber
  [ "$status" -ne 0 ]
  [[ "$output" == *"ttl-seconds"* ]]
}

@test "default TTL is 7200 seconds" {
  run env \
    SECURE_LINK_SECRET=s \
    NOW_OVERRIDE=1000000 \
    "$SCRIPT" /hls/x.m3u8
  [ "$status" -eq 0 ]
  [[ "$output" == *"expires=1007200" ]]
}

@test "prints usage on no args" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "rejects too many args" {
  run env SECURE_LINK_SECRET=s "$SCRIPT" /hls/x 60 extra
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}
