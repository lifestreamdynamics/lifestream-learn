# Dependency audit summary — 2026-04

Part of Slice G3. Captures what was found, what was fixed, and what was
deferred with rationale. Raw output lives in `ops/security-review-2026-04.md`
(gitignored at the top level).

## Backend — `npm audit`

Ran `cd api && npm audit` (full tree, all severities).

| Package | Severity | Path | Disposition |
|---|---|---|---|
| `@hono/node-server <1.19.13` | Moderate | `prisma → @prisma/dev → @hono/node-server` | **Resolved 2026-04-20** via npm `overrides` in `api/package.json` pinning `@hono/node-server: ^1.19.14`. Prisma 7 kept per ADR 0003. `npm audit` now reports 0 vulnerabilities. Advisory GHSA-92pp-h63x-v22m is a middleware-bypass via repeated slashes in `serveStatic` — not a runtime path for learn-api, but the override closes the audit line. |

**Totals:** 0 moderate, 0 high, 0 critical on the current tree.
Production-only scope (`npm audit --omit=dev --audit-level=high`): clean.

### Follow-up
Drop the `overrides` block in `api/package.json` when Prisma upstream
bumps `@hono/node-server` past `1.19.14` in its own dependency pin;
until then the override guards against a regression if the transitive
drifts back.

## Flutter app — `flutter pub outdated`

Ran `cd app && flutter pub outdated`. **No CVE annotations** in the
Flutter output; `flutter pub outdated` surfaces only version
upgradability, not advisories (Dart's `pub` doesn't have a `pub audit`
equivalent).

24 packages have newer resolvable versions. 3 transitive packages are
marked discontinued:

| Package | Status | Disposition |
|---|---|---|
| `js` | Discontinued (transitive of multiple SDK packages) | Tracked upstream; no action at our layer. |
| `build_resolvers` | Discontinued (transitive of `build_runner`) | Tracked upstream. |
| `build_runner_core` | Discontinued (transitive of `build_runner`) | Tracked upstream. |

None of the discontinued packages have known CVEs. Major-version
upgrades (e.g. `freezed` 2→3, `flutter_lints` 5→6, `json_serializable`
6.9→6.13) are **deferred to a dedicated Flutter-upgrade slice**
post-Phase-7; bundling them into G3 would balloon the slice and
require re-running the Flutter test suite under fresh lint rules.

### Follow-up
Open a backlog slice "Flutter dep upgrade 2026 H2" covering the
24 outdated lines + the `freezed`/`json_serializable` generator
regeneration.

## Pre-push secret scan

`.githooks/pre-push` runs `gitleaks` if installed, else a regex
fallback. Verified on `2026-04-19`:

```bash
$ git config --get core.hooksPath
.githooks

$ .githooks/pre-push main 0123...deadbeef main     # sanity invocation
[pre-push] scanning 3 new commits for secrets...
[pre-push] no secrets detected
```

No secrets in the Phase-7 delta. The hook fires on `git push`; don't
bypass with `--no-verify`.

## Security-review skill

Full output archived in `ops/security-review-2026-04.md` (gitignored).
Summary of findings:

See `docs/security/threat-model.md` §6 for the acknowledged-weaknesses
list and deferred items. No critical findings were identified in the
Slice-G1/G2/G3 delta. The pre-existing issues flagged previously
(MD5 secure_link, VOICE cue deferral) are unchanged and already
documented in ADR-0002 / ADR-0004 / `secure_link.conf.inc`.
