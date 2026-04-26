# learn-api threat model — v1

**Owner:** Eric
**Created:** 2026-04-19 (Slice G3, Phase 7)
**Status:** Accepted — manual review pass 2026-04-26.
The repo has no git remote yet (per ADR 0005 the public split happens
later); the `security-review` skill expects a remote, so a re-run via
the skill is required at split time. Until then this document tracks
the security posture; manual updates supersede the skill output.

This is a one-page, living threat model. Update it when the architecture
shifts or when an ADR lands a new trust decision.

## 1. Scope

**In scope:**
- The `learn-api` REST service (`api/`).
- The local nginx reverse proxy, SeaweedFS S3 gateway, and tusd upload
  server (`infra/`).
- The Flutter app's interaction with the API (auth tokens, signed
  playback URLs, cue submissions).
- Shared-infrastructure hygiene against accounting-api and chatbot-api
  on the eventual shared VPS.

**Out of scope (deferred to deployment track):**
- TLS termination, domain/DNS setup, Certbot rotation.
- Multi-tenant isolation beyond the current single-tenant dev stack.
- CDN-scale abuse handling (DDoS, credential stuffing at >200 VU).
- Supply-chain attestation (sigstore, SLSA).

## 2. Assumptions

| Assumption | Confidence | Notes |
|---|---|---|
| Code in `api/`, `app/`, `infra/`, `docs/` is published publicly under AGPL-3.0. | Certain | ADR 0001. No real secrets, hostnames, or internal paths land in these trees; secret scanning enforced via `.githooks/pre-push`. |
| Single-tenant local dev today; shared-VPS multi-tenant later. | Certain | IMPLEMENTATION_PLAN.md scope note. |
| Postgres + Redis are shared with accounting-api via compose, but scoped via `learn_api_user` role, `learn_api_*` databases, and a `learn:` Redis key prefix. | Certain | `CLAUDE.md` shared-resource discipline section. |
| Object storage stays on SeaweedFS (self-hosted). No AWS, R2, or other cloud S3. | Certain | ADR 0002. `@aws-sdk/client-s3` in `package.json` is the S3-protocol client we use to talk to SeaweedFS — it's not a cloud dependency. |
| The reverse proxy (nginx) IP-allowlists `/metrics` and `/internal/*` before any deployment. | Implemented | `deploy/nginx/learn-api.lifestreamdynamics.com.conf` (2026-04-26) — both locations have `allow 127.0.0.1; allow 172.16.0.0/12; deny all;`. Loopback covers a same-VPS Prometheus / tusd; the `172.16.0.0/12` range covers the docker bridge. |

## 3. Trust boundaries

Left-to-right: less trusted → more trusted.

```
Internet → nginx → { learn-api / tusd / SeaweedFS }
                         ↓
                   accounting-postgres + accounting-redis
```

Trust boundary crossings and the checks enforced at each one:

| Crossing | Check |
|---|---|
| Internet → nginx `/api/*` | CORS origin check (`CORS_ALLOWED_ORIGINS`), Helmet default headers. |
| Internet → nginx `/hls/*` | `secure_link` HMAC validation (MD5; see §6 acknowledged weaknesses). |
| Internet → nginx `/uploads/*` | tusd's own protocol checks; no auth on upload creation (by design — pre-finish hook validates). |
| nginx → learn-api `/api/*` | JWT `authenticate` middleware + role gates (`requireRole`) on mutating routes. `trust proxy` configured to 1 so rate-limiter sees real client IP. |
| tusd → learn-api `/internal/hooks/tusd` | `TUSD_HOOK_SECRET` as `?token=` query param, compared with `crypto.timingSafeEqual`. |
| learn-api → Postgres | Prisma with credentials from `DATABASE_URL`; scoped to `learn_api_user` role (no cross-project DB access). |
| learn-api → Redis | Keys always prefixed `learn:` (BullMQ sub-prefix `learn:bull`). |
| learn-api → SeaweedFS | Access key `learn-api-rw` (full); tusd has its own `tusd-upload` identity (write-only to `learn-uploads/`). |

## 4. Authentication + authorisation

- **User auth.** Email + password (bcrypt, cost 12). Access JWT (HS256,
  15 min default). Refresh JWT (HS256, 30d default). Both secrets
  Zod-validated `.min(32)`; no defaults. Tokens never logged (pino
  redact list in `api/src/config/logger.ts`).
- **Roles.** `ADMIN`, `COURSE_DESIGNER`, `LEARNER`. Role claim is
  embedded in the access token; the server re-checks against the
  database on every mutation (router-level `requireRole` is a
  fast-fail; `cue.service.ts` / `course.service.ts` re-verify
  owner/collaborator/admin).
- **Rate limiting** (Redis-backed, per-IP): signup 10/10min, login
  5/5min, refresh 30/5min. All configurable via `RATE_LIMIT_*` env
  vars (Slice G2). Any future deployment must keep the prod defaults;
  Slice G2's higher ceilings are local-dev-only.

## 5. Grading integrity

From `CLAUDE.md`: "a wrong correct/incorrect leaks the answer or
miscredits a learner." All cue grading lives in
`src/services/grading/*.ts` as pure functions with ≥95% branch
coverage enforced at the Jest config level. The client never grades
itself — `POST /api/attempts` always re-runs the grader server-side.
The attempt response carries the *result*, never the cue's secret
fields (`answerIndex`, `pairs`).

## 6. Acknowledged weaknesses

| Weakness | Risk | Mitigation / upgrade path |
|---|---|---|
| **Nginx `secure_link` uses MD5.** | Not pre-image resistant for an adversary with substantial compute; fine for 2-4h signed URLs in practice. | Upgrade path documented inline in `infra/nginx/secure_link.conf.inc` — switch to `secure_link_sha256` by flipping one directive. No code change needed in `hls-signer.ts` if we swap in parallel. Tracked; not blocking. |
| ~~**JWT secret rotation is a manual env-swap.**~~ | ~~Rotating a secret invalidates all in-flight tokens.~~ | **Resolved 2026-04-26** by ADR 0007. `verifyAccessToken` / `verifyRefreshToken` accept either the current or `JWT_*_SECRET_PREVIOUS` secret; sign paths always use the current. Rotation-window usage is observable via `learn_jwt_verify_with_previous_total{tokenType=access\|refresh}`. Operator runbook in `api/.env.example` and ADR 0007 §Consequences. |
| ~~**`@hono/node-server <1.19.13` (transitive of Prisma).**~~ | ~~Moderate-severity `serveStatic` path-traversal in dev tooling.~~ | **Resolved 2026-04-20** via npm `overrides` pinning `^1.19.14`. `npm audit` is clean. See `docs/security/audit-summary-2026-04.md`. |
| **Flutter deps with 24 out-of-date lines + 3 discontinued transitives.** | Latent maintenance burden. | Dedicated "Flutter dep upgrade 2026 H2" backlog slice; none carry known CVEs today. |
| **No `gitleaks` installed locally.** | Pre-push hook falls back to a regex scanner; weaker coverage. | Install `gitleaks` via `apt install gitleaks` or `brew install gitleaks`. Slice G3 surfaced and fixed a subtle bug in the regex fallback (grep was receiving a `-`-prefixed pattern as a flag). |
| **VOICE cue type reserved but unimplemented.** | None today (API returns 501). | ADR 0004. |
| ~~**`/metrics` and `/internal/*` paths are not IP-allowlisted.**~~ | ~~Metrics or the tusd-hook endpoint reachable publicly on a future deploy would leak request counts / accept arbitrary tusd notifications.~~ | **Resolved 2026-04-26** in `deploy/nginx/learn-api.lifestreamdynamics.com.conf` — explicit `allow 127.0.0.1; allow 172.16.0.0/12; deny all;` on both locations. |

## 7. Non-goals

- DoS hardening beyond the existing per-IP rate-limits.
- Protecting course content from scraping (it's public-by-design).
- Hardening against adversaries with access to the VPS host
  (compromise at that level is not in learn-api's threat model).
- Cross-site scripting in the Flutter app's embedded WebViews (we
  don't embed any; all content is structured JSON served through
  authenticated API paths).

## 8. Pre-push secret scan

The `.githooks/pre-push` hook runs on every `git push`:

- With `gitleaks` installed: full `gitleaks detect --redact` over the
  pushed commit range.
- Without `gitleaks`: regex fallback covering AWS access keys, RSA/
  OpenSSH private keys, GitHub tokens, Stripe live keys, Slack tokens,
  and assignment-form `password=`/`api_key=` patterns.

Manually verified clean on `2026-04-19` against the Slice-G1/G2/G3
delta. Never bypass with `--no-verify`; if the hook blocks, investigate
the flagged line.

## 9. Security-review skill

Slice G3 ran the `security-review` skill against the current branch.
The full archive lives at `ops/security-review-2026-04.md` (ops/ is
gitignored). Findings summary:

- **No critical or high findings in the Slice G1/G2/G3 delta.**
- Moderate findings (rate-limit defaults, `/metrics` allowlisting)
  are reflected in §6 above and in the G2 tuning knobs. The
  `@hono/node-server` advisory was resolved 2026-04-20 via npm
  `overrides` — see the audit summary for the disposition.
- Pre-existing items (MD5 secure_link, VOICE cue deferral) unchanged
  from prior ADR documentation.

## 10. Changelog

| Date | Change |
|---|---|
| 2026-04-19 | Initial v1 (Slice G3). |
