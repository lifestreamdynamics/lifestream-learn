# Contributing to Lifestream Learn

Thanks for your interest. This project is open source under AGPL-3.0 while being operated commercially as a SaaS. Contributions are welcome under those terms.

## Before you start

- **License:** by opening a PR you agree your contribution is licensed under AGPL-3.0. If you need a different license for your use case, email `eric@REDACTED-DOMAIN` before contributing.
- **Issues first:** for non-trivial changes, open an issue to discuss the approach before writing code. Drive-by refactors will usually be closed.
- **Scope:** this project deliberately keeps a narrow feature surface. New interaction cue types, new auth flows, and major architectural changes should be discussed before implementation.

## Development setup

Each sub-project has its own setup instructions:

- [`api/README.md`](./api/README.md) — backend
- [`app/README.md`](./app/README.md) — Flutter app
- [`infra/README.md`](./infra/README.md) — self-hosting stack

## Pull request expectations

- One logical change per PR
- Tests for any business logic (unit ≥80%, integration ≥85% on the backend)
- Passes the linter and type checker
- No secrets, no hostnames, no personal paths committed — see `.gitignore` and the `gitleaks` pre-push hook
- Sign your commits (`git commit -S`) — required on the protected `main` branch
- Never use Zod to validate fields whose *values* are secrets (JWTs, API keys, HMAC signing material). The error envelope surfaces Zod issue paths to the client, so a validation error on a secret-bearing field can leak portions of the secret. Validate shape at the boundary; verify secrets via `crypto.timingSafeEqual` against a hashed representation.

## Required CI checks

These must pass before a PR is merged to `main`:

- `api-ci / lint-type-unit` — ESLint, `tsc --noEmit`, Jest unit tests with coverage thresholds.
- `api-ci / integration` — Integration tests against Postgres + Redis services. Compose-dependent suites (`transcode-e2e`, `transcode-resilience`, `secure-link`, `health`) are excluded from CI and must be run locally — see the **Required pre-merge local gate** below.
- `app-ci / analyze-test` — `flutter analyze`, `flutter test --coverage`, and a generated-files-up-to-date check.
- `secret-scan / gitleaks` — server-side secret scan (belt-and-braces alongside the local pre-push hook).

## Required pre-merge local gate (compose-dependent integration tests)

GitHub Actions doesn't run docker-compose stacks for PRs, so four integration suites cannot run in CI. They MUST run locally and be green before you open or update a PR that touches the upload→transcode→playback pipeline, the HLS signer, or the health endpoint:

| Suite | What it covers | Touched by changes to |
|---|---|---|
| `transcode-e2e` | Full upload → transcode → HLS ladder happy path, ffprobe variant assertions | `api/src/workers/transcode.*`, `api/src/services/ffmpeg/`, tusd hooks |
| `transcode-resilience` | Kill-and-resume, BullMQ retry/backoff, FAILED transitions | `api/src/workers/`, `api/src/services/transcode-queue.ts` |
| `secure-link` | nginx HMAC validation, tampered/expired URL rejection | `api/src/utils/hls-signer.ts`, `infra/nginx/secure_link.conf.inc`, `deploy/nginx/` |
| `health` | `/health/*` endpoints against the live compose stack | `api/src/routes/health.ts`, infra dependencies |

**Setup (one-time, then leave running):**

```bash
# 1. Bring up the accounting-api compose stack (provides shared Postgres + Redis).
# 2. From the repo root:
make up                              # learn infra: seaweedfs, tusd, nginx, DBs, buckets
```

**Run the four suites:**

```bash
cd api
npm run test:integration -- --testPathPattern="transcode-e2e"
npm run test:integration -- --testPathPattern="transcode-resilience"
npm run test:integration -- --testPathPattern="secure-link"
npm run test:integration -- --testPathPattern="health\.test"
```

All four must finish green. Capture the result in your PR description (`transcode-e2e ✓ / transcode-resilience ✓ / secure-link ✓ / health ✓`) so reviewers can see you ran them.

If your change does not touch any of the columns above, you may skip the suite — but state that in the PR description.

## Areas where help is welcome

- Additional cue type proposals (e.g. code playground, video response)
- iOS builds of the Flutter app
- Translations of the learner-facing UI
- Accessibility testing (TalkBack on Android)
- Self-hosting documentation improvements in `infra/`

## Code of conduct

See [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md).
