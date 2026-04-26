# 0007 — JWT dual-secret rotation (`*_PREVIOUS`)

- **Status:** Accepted (2026-04-26)
- **Deciders:** Eric

## Context

learn-api signs and verifies its access and refresh tokens with HS256 using the symmetric secrets `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` (Zod-validated, `.min(32)`, no defaults). Until this ADR, the only way an operator could rotate either secret was an env-swap on the running process: write the new value into `/etc/learn-api/.env`, restart, and accept that every in-flight access token (15-minute TTL) and every still-valid refresh token (30-day TTL) was instantly invalid. The user-visible failure mode is a wall of 401s on `GET /api/auth/me` and `POST /api/auth/refresh` until everyone re-authenticates — which is also when their refresh tokens are gone, so it's a mass forced login event.

This was acceptable in dev (one user, restart, log in again) and was called out as an acknowledged weakness in the threat model:

> **JWT secret rotation is a manual env-swap.** Rotating a secret invalidates all in-flight tokens. — Mitigation: dual-secret rollover (`JWT_ACCESS_SECRET_PREVIOUS`) is a backlog item for the deployment track. (`docs/security/threat-model.md` §6, row 2)

Phase 8 is when this matters: a production rotation in response to a suspected secret compromise (or just calendar hygiene) needs to happen without 30 days of forced re-logins.

## Decision

Accept a token from EITHER the current secret OR a configured `*_PREVIOUS` secret on every verify; always sign with the current secret.

Concretely, `api/src/utils/jwt.ts` exposes a single private `verifyWithRotation(token, tokenType)` helper used by both `verifyAccessToken` and `verifyRefreshToken`. It tries `env.JWT_ACCESS_SECRET` (or `JWT_REFRESH_SECRET`) first. On a `JsonWebTokenError` whose message contains `'invalid signature'` AND with `env.JWT_ACCESS_SECRET_PREVIOUS` (resp. `..._REFRESH_SECRET_PREVIOUS`) set, it retries once with the previous secret. Every other error (`TokenExpiredError`, `NotBeforeError`, audience mismatch, malformed token) bubbles unchanged from the current-secret attempt.

A successful previous-secret verify increments the prom-client counter `learn_jwt_verify_with_previous_total{tokenType="access"|"refresh"}`. An operator monitoring the rotation window can confirm the metric is flat-zero before unsetting `*_PREVIOUS`.

Both `*_PREVIOUS` env vars are optional (`z.string().min(32).optional()`); when unset, verify only accepts the current secret — identical to the pre-ADR behaviour. The length floor matches the primary secret so an operator can't downgrade entropy by routing through `*_PREVIOUS`.

The error message for any verify failure remains the generic `'Invalid or expired token'` (raised as `UnauthorizedError`). It does not indicate which secret was tried, whether `*_PREVIOUS` was set, or why a particular check failed.

## Consequences

- **Operator runbook for rotation** (mirrored in `api/.env.example`):
  1. Copy the current `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` value into `JWT_ACCESS_SECRET_PREVIOUS` / `JWT_REFRESH_SECRET_PREVIOUS`. Deploy. Verify the API still serves `/api/auth/me` for existing sessions.
  2. Mint a fresh secret (`openssl rand -base64 48`) and replace the primary value. Deploy. Newly-minted tokens use the fresh secret; in-flight tokens continue verifying via `*_PREVIOUS`.
  3. Wait at least one `JWT_REFRESH_TTL` (default 30 days) so every outstanding refresh token has either rotated or expired. Confirm `learn_jwt_verify_with_previous_total{tokenType=...}` has been flat at zero. Then unset `*_PREVIOUS` and deploy a final time.
- **No behavioural change at zero-config.** Both new env vars default to undefined; existing deploys verify with the current secret only and see no metric increments.
- **Refresh-token rotation invariants are preserved.** `auth.service.refresh()` continues to atomically claim the old `jti`, mint a new `jti`, and rotate the `Session` row — all signed under the CURRENT secret.
- **Expiry semantics are preserved.** A token signed with `*_PREVIOUS` whose `exp` has passed still rejects; we do not fall through on `TokenExpiredError`. An attacker holding a stolen-but-expired token cannot replay it whenever a rotation window is open.
- **Cross-token-type isolation is preserved.** `JWT_ACCESS_SECRET_PREVIOUS` only fires the access fallback; `JWT_REFRESH_SECRET_PREVIOUS` only fires the refresh fallback. An operator who rotates only one of the two pairs cannot accidentally widen the trust on the other.
- **Observability cost.** One new prom-client Counter (`learn_jwt_verify_with_previous_total`) with two label values. Default-labels (`service="learn-api"`) keep multi-service scrapes distinguishable per the shared-resource-guardian rules in `CLAUDE.md`.

## Alternatives considered

- **Status quo: env-swap and accept the forced-logout window.** Acceptable in dev with one user, painful at any real install. Also creates incentives to NOT rotate after a suspected compromise because the cost feels disproportionate.
- **JWKS / asymmetric keys with a `kid` header.** The cleanest answer for a JWT system at any scale: include a `kid` in the header, look it up against a keyset, and rotate by adding a new entry. We deliberately did not adopt this here for three reasons:
  1. learn-api is single-process today; we do not have a key distribution problem.
  2. The HS256 → RS256 (or EdDSA) move is a code change in every JWT-aware corner of the system (sign, verify, plus any consumer of the token like the Flutter client when it eventually decodes for offline cache hints). That's a bigger lever than the rotation problem warrants right now.
  3. We can adopt JWKS later without migrating data — refresh-token storage is jti-keyed, not signature-keyed.
- **Server-side token allowlist (random-string opaque tokens).** Removes JWT entirely in favour of database-backed sessions; rotation is then irrelevant. Considered and rejected at the original auth design (Phase 2) because it adds a database round-trip to every authenticated request.
- **Three-way secret rollover (`*_PREVIOUS`, `*_PRE_PREVIOUS`).** Theoretically allows two overlapping rotations. We do not have a use case yet; YAGNI. Easy to extend later by adding another optional env var.

## References

- [`api/src/utils/jwt.ts`](../../api/src/utils/jwt.ts) — `verifyWithRotation` helper.
- [`api/src/config/env.ts`](../../api/src/config/env.ts) — `JWT_*_SECRET_PREVIOUS` schema entries.
- [`api/src/observability/metrics.ts`](../../api/src/observability/metrics.ts) — `learn_jwt_verify_with_previous_total` counter.
- [`api/.env.example`](../../api/.env.example) — operator runbook (rotation steps 1–3).
- [`docs/security/threat-model.md`](../security/threat-model.md) §6 — acknowledged weakness this ADR resolves.
- [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) §5 Phase 8 backlog — "JWT dual-secret rotation" row.
