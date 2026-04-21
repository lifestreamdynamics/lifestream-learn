# =============================================================================
# secure_link.conf.inc — HMAC-keyed URL validation for /hls/ playback
# =============================================================================
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
# The token lives in the URL PATH, not the query string, so every
# relative URL inside the playlist (variant playlists, init segments,
# media segments) structurally carries the token to nginx. HLS players
# are NOT required by RFC 8216 / RFC 3986 §5.3 to propagate the parent
# URL's query string to child requests — and none of the ones we target
# (fvp/libmdk, ExoPlayer, hls.js, ffplay, VLC) do. Path-embedding is the
# portable workaround.
#
# The caller must arrange for the external request to be rewritten into
# an internal URI whose $uri reflects the path WITHOUT the {sig}/{expires}
# prefix, and must set $secure_link_expires_override + $signed_prefix +
# $secure_link_secret as variables before including this file. Typically
# the caller uses a `map` or `location ~` block that captures the three
# path components via named groups:
#
#     location ~ ^/hls/(?<sig>[A-Za-z0-9_-]+)/(?<expires>[0-9]+)/(?<video_id>[A-Za-z0-9-]+)/.*$ {
#         set $secure_link_expires_override $expires;
#         set $signed_prefix "/hls/$video_id/";
#         set $secure_link_secret "REPLACE_ME_WITH_HIGH_ENTROPY_SECRET";
#         include /etc/nginx/snippets/secure_link.conf.inc;
#         # (on validation pass) rewrite + proxy_pass to the backing store
#     }
#
# ---------------------------------------------------------------------------
# Deviation from the plan (MD5 vs HMAC-SHA256)
# ---------------------------------------------------------------------------
# The implementation plan called for HMAC-SHA256. Nginx's stock
# ngx_http_secure_link_module (shipped in Ubuntu's `nginx-full` on 24.04)
# only supports MD5-keyed hashes. For signed VOD URLs with:
#   - a high-entropy server-side secret (>=32 random bytes)
#   - a short TTL (2-4 hours)
#   - the URL being the only thing the attacker sees
# keyed-MD5 is acceptable: the attacker must recover the secret from a
# 128-bit keyed digest, which is infeasible at current compute levels for
# VOD-scale attacker models. MD5 collision attacks do not help here because
# the server-side check is a prefix-secret keyed hash, not a signature over
# attacker-chosen content.
#
# Post-MVP upgrade path: switch to njs or OpenResty/Lua and compute
# HMAC-SHA256 in the same $secure_link style. That swap lives behind this
# single include file; callers won't need to change.
# =============================================================================

# Validate: $sig is the base64url(md5(...)) from the client (captured from
# the URL path); $secure_link_expires_override is the unix timestamp the
# signature expires at (also from the path).
#
# Note: we reference `$secure_link_expires_override` (the path-captured
# variable) in BOTH the `secure_link` expiry argument AND the
# `secure_link_md5` hash expression. The nginx docs describe a
# `$secure_link_expires` variable populated from the second argument of
# `secure_link`, but that's only useful when the expiry is sourced from a
# query arg and you want to avoid referencing `$arg_expires` twice; in our
# path-captured case the named regex group is already the value we want.
secure_link $sig,$secure_link_expires_override;
secure_link_md5 "$secure_link_expires_override$signed_prefix $secure_link_secret";

# $secure_link is "" (invalid), "0" (expired), or "1" (valid).
if ($secure_link = "") {
    return 403;
}
if ($secure_link = "0") {
    return 410;
}
