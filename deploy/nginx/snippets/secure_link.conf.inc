# =============================================================================
# secure_link.conf.inc — HMAC-keyed URL validation for /hls/ playback (prod)
# =============================================================================
#
# Copied from infra/nginx/secure_link.conf.inc (local dev variant). Same
# validation logic — the caller is responsible for:
#   - capturing  $sig, $path_expires, $video_id  from the URL via a
#     named-group regex location (see learn-api.REDACTED-BRAND-DOMAIN.conf)
#   - setting    $secure_link_secret              before the include
#                (production value comes from /etc/learn-api/.env via
#                 HLS_SIGNING_SECRET, injected into this config at deploy
#                 time — see deploy/README.md §§"first-deploy" and
#                 "rotating the HMAC secret")
#   - setting    $secure_link_expires_override   = $path_expires
#   - setting    $signed_prefix                  = "/hls/$video_id/"
#
# URL scheme (path-embedded token):
#   /hls/{sig}/{expires}/{videoId}/...
#
#   where sig = base64url( md5( "{expires}/hls/{videoId}/ {secret}" ) )
#   (note the single space between the signed prefix and the secret)
#   and base64url means standard base64 with:
#     '+' -> '-'
#     '/' -> '_'
#     trailing '=' stripped
#
# Rationale for MD5 vs HMAC-SHA256, and the post-MVP njs/OpenResty upgrade
# path, are documented verbatim in infra/nginx/secure_link.conf.inc.
# Don't fork the rationale — if you change one, change both.
# =============================================================================

secure_link $sig,$secure_link_expires_override;
secure_link_md5 "$secure_link_expires_override$signed_prefix $secure_link_secret";

# $secure_link is "" (invalid), "0" (expired), or "1" (valid).
if ($secure_link = "") {
    return 403;
}
if ($secure_link = "0") {
    return 410;
}
