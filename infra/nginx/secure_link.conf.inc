# =============================================================================
# secure_link.conf.inc — HMAC-keyed URL validation for /hls/ playback
# =============================================================================
#
# URL scheme: /hls/{path}?md5={hash}&expires={unix_ts}
#   where hash = base64url( md5( "{expires} {uri} {secret}" ) )
#   and base64url means standard base64 with:
#     '+' -> '-'
#     '/' -> '_'
#     trailing '=' stripped
#
# This exactly matches nginx's built-in secure_link_md5 directive when the
# expression is "$secure_link_expires$uri $secret" (with a single space between
# expires+uri and the secret). See:
#   https://nginx.org/en/docs/http/ngx_http_secure_link_module.html
#
# Nginx sets $secure_link to:
#   empty string  -> signature invalid        -> we return 403
#   "0"           -> signature valid but expired -> we return 410
#   "1"           -> signature valid and unexpired -> request proceeds
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
#
# Caller contract: the enclosing `location` (or `server`) block MUST define
# the $secure_link_secret variable before including this file, e.g.:
#
#     location /hls/ {
#         set $secure_link_secret "REPLACE_ME_WITH_HIGH_ENTROPY_SECRET";
#         include /etc/nginx/snippets/secure_link.conf.inc;
#         ...
#     }
#
# =============================================================================

# Validate: $arg_md5 is the base64url(md5(...)) from the client; $arg_expires
# is the unix timestamp the signature expires at.
secure_link $arg_md5,$arg_expires;
secure_link_md5 "$secure_link_expires$uri $secure_link_secret";

# $secure_link is "" (invalid), "0" (expired), or "1" (valid).
if ($secure_link = "") {
    return 403;
}
if ($secure_link = "0") {
    return 410;
}
