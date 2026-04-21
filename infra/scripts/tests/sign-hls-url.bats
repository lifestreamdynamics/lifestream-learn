#!/usr/bin/env bats
# =============================================================================
# sign-hls-url.bats — tests for infra/scripts/sign-hls-url.sh
# =============================================================================
# Run from the repo root (or infra/):
#   bats infra/scripts/tests/sign-hls-url.bats
#
# Tests cover:
#   1. Output format: /hls/<sig>/<expires>/<videoId>/master.m3u8
#   2. Known-input -> known-output round trip (pinned clock + fixed secret)
#   3. Missing SECURE_LINK_SECRET aborts with non-zero exit
#   4. Empty / slash-bearing videoId aborts
#   5. Non-numeric TTL aborts
#   6. Default TTL is 7200s (2h)
# =============================================================================

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../sign-hls-url.sh"
  [ -x "$SCRIPT" ] || chmod +x "$SCRIPT"
}

@test "emits URL matching /hls/<sig>/<expires>/<videoId>/master.m3u8" {
  run env SECURE_LINK_SECRET=some_secret "$SCRIPT" x 60
  [ "$status" -eq 0 ]
  # One line. Base64url alphabet = [A-Za-z0-9_-], no '=' padding.
  [[ "$output" =~ ^/hls/[A-Za-z0-9_-]+/[0-9]+/x/master\.m3u8$ ]]
}

@test "known-input -> known-output (fixed secret + pinned clock)" {
  # NOW_OVERRIDE pins the clock to 2023-11-14 22:13:20 UTC.
  # Signed string: "1700007200/hls/abc/ local_dev_secret_do_not_use_in_prod"
  # Expected sig recomputed with the same md5 -> base64url pipeline.
  run env \
    SECURE_LINK_SECRET=local_dev_secret_do_not_use_in_prod \
    NOW_OVERRIDE=1700000000 \
    "$SCRIPT" abc 7200
  [ "$status" -eq 0 ]
  [ "$output" = "/hls/291Pw6Mpt2Vi2igXZwuwwA/1700007200/abc/master.m3u8" ]
}

@test "missing SECURE_LINK_SECRET is a fatal error" {
  run env -u SECURE_LINK_SECRET "$SCRIPT" x 60
  [ "$status" -ne 0 ]
  [[ "$output" == *"SECURE_LINK_SECRET"* ]]
}

@test "videoId with a slash is rejected" {
  run env SECURE_LINK_SECRET=s "$SCRIPT" a/b 60
  [ "$status" -ne 0 ]
  [[ "$output" == *"slashes"* ]]
}

@test "empty videoId is rejected" {
  run env SECURE_LINK_SECRET=s "$SCRIPT" "" 60
  [ "$status" -ne 0 ]
  [[ "$output" == *"non-empty"* ]]
}

@test "non-numeric TTL is rejected" {
  run env SECURE_LINK_SECRET=s "$SCRIPT" x notanumber
  [ "$status" -ne 0 ]
  [[ "$output" == *"ttl-seconds"* ]]
}

@test "default TTL is 7200 seconds" {
  run env \
    SECURE_LINK_SECRET=s \
    NOW_OVERRIDE=1000000 \
    "$SCRIPT" x
  [ "$status" -eq 0 ]
  # Path shape is /hls/<sig>/<expires>/<videoId>/master.m3u8; the expires
  # path segment should be now+7200 = 1007200.
  [[ "$output" == */1007200/x/master.m3u8 ]]
}

@test "prints usage on no args" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "rejects too many args" {
  run env SECURE_LINK_SECRET=s "$SCRIPT" x 60 extra
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}
