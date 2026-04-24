# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository shape

This is a **single working directory that will split into multiple public repos** before 1.0 (see `docs/decisions/0005-monorepo-with-private-ops-split.md`). Sub-projects cross-link with relative paths today; those links get rewritten at split time. Treat each sub-project as if it were already its own repo when making changes — keep boundaries clean.

| Path | Sub-project | Status |
|---|---|---|
| `api/` | Node 22 / TypeScript / Express / Prisma / Postgres / Redis / BullMQ REST API. Dev port 3011, prod 3101. | Phase 3 (pipeline) |
| `app/` | Flutter Android app — learner feed, player + cue engine, designer authoring, admin, analytics. BLoC state, Dio HTTP, GoRouter, `video_player` + `fvp` (ffmpeg backend). Dev/prod flavors. | Phases 4–6 (in flight) |
| `infra/` | Docker Compose for local dev (seaweedfs, tusd, nginx). Postgres + Redis are borrowed from accounting-api's local stack. | Phase 1 (complete for MVP scope) |
| `Makefile` | Top-level dev task runner. `make bootstrap` writes env files; `make up` brings up infra + DBs + buckets + migrate + seed; `make api` / `make worker` / `make app` are the three dev terminals. `make status` prints a health line. Prefer these over per-subproject commands unless you need finer control. | — |
| `scripts/bootstrap-dev.sh` | First-time setup: writes `infra/.env` + `api/.env.local` with random secrets. Invoked by `make bootstrap`. | — |
| `.github/workflows/` | CI: `api-ci` (lint + typecheck + unit + integration), `app-ci` (analyze + test + codegen-freshness check), `secret-scan` (gitleaks). Compose-dependent API suites (`transcode-e2e`, `transcode-resilience`, `secure-link`, `health`) are **excluded from CI** and must be run locally. | — |
| `ops/` | **Private, git-ignored at top level.** Phase reports, environment snapshots, future deployment notes. Never commit anything here through the public monorepo. | — |
| `docs/decisions/` | ADRs — numbered `NNNN-slug.md`. Edit when reality changes; add a new one when a fundamentally different direction is chosen. | — |
| `IMPLEMENTATION_PLAN.md` | Canonical phase-by-phase plan with exit criteria. Always check §5 before starting work to confirm which phase gates apply. | — |

## Canonical source of truth

- **`IMPLEMENTATION_PLAN.md`** is the source of truth for phases, exit criteria, parallel-work splits, and migration seams. Read it before planning non-trivial work.
- **ADRs in `docs/decisions/`** record *why* decisions were made (AGPL license, SeaweedFS over MinIO, BullMQ over Bull, VOICE cue deferred, monorepo layout). They're living documents — update them when the rationale or reality shifts.
- **Architecture docs** in `docs/architecture/` will describe *what is*, not what was — rewrite rather than append when reality changes. (Phase 3 architecture doc: `docs/architecture/phase-3-upload-transcode-playback.md`.)

## Commands (top-level Makefile)

The top-level `Makefile` is the recommended entrypoint for local dev — it encodes the shared-service preflight check, the healthcheck wait, and the DB/bucket provisioning order so you don't have to remember them. `make help` lists targets.

```bash
make bootstrap   # one-time: writes infra/.env + api/.env.local with random secrets
make up          # compose up + create-databases + create-buckets + prisma migrate + seed
make api         # terminal 1: API hot-reload on :3011
make worker      # terminal 2: BullMQ transcode worker
make app         # terminal 3: launches AVD (if needed) + flutter run --flavor dev
make app-deps    # one-time (or after pubspec changes): pub get + build_runner codegen
make status      # one-line health check (API / nginx / adb devices)
make reset       # DESTRUCTIVE: drops SeaweedFS volumes then re-ups (prompts for yes)
```

`make up` requires the `accounting-api` compose stack to already be running (Postgres :5432 + Redis :6379). `make app` reads `NGINX_HOST_PORT` from `infra/.env` and passes `API_BASE_URL=http://10.0.2.2:<port>` via `--dart-define` so the Android emulator can reach the host-side nginx. Seeded dev users (password `Dev12345!Pass` unless `SEED_DEV_USER_PASSWORD` is set): `admin@example.local` (ADMIN), `designer@example.local` (COURSE_DESIGNER), `learner@example.local` (LEARNER).

## Commands (api/)

Run from `api/`. Node 22.12+ required (pinned in `.nvmrc` and `engines`). Use these when you need finer control than the Makefile provides.

```bash
nvm use                           # Node 22
npm install
cp .env.example .env.local        # fill in secrets
npm run prisma:migrate            # dev migrations
npm run dev                       # hot-reload on :3011
```

| Command | Purpose |
|---|---|
| `npm run dev` | Hot-reload API (ts-node + nodemon) on :3011 |
| `npm run build` | `tsc -p tsconfig.build.json && tsc-alias` → `dist/` |
| `npm start` | Run compiled `dist/index.js` |
| `npm test` | Unit tests (Jest, `tests/unit/` + colocated `*.test.ts`) |
| `npm run test:watch` | Unit tests in watch mode |
| `npm run test:coverage` | Unit tests with coverage (thresholds: 80% lines/functions/statements, 70% branches) |
| `npm run test:integration` | Integration tests (needs Postgres + Redis; runs serially, 30s timeout) |
| `npm run test:integration:coverage` | Integration coverage (thresholds: 85% lines/functions/statements, 75% branches) |
| `npm run test:all` | Unit + integration with coverage |
| `npm run lint` / `lint:fix` | ESLint on `.ts` |
| `npm run typecheck` | `tsc --noEmit` |
| `npm run validate` | lint + typecheck + unit tests (run before opening a PR — note: integration tests are **not** included; run `npm run test:integration` separately, per `CONTRIBUTING.md`) |
| `npm run prisma:migrate` | `prisma migrate dev` |
| `npm run prisma:deploy` | `prisma migrate deploy` (prod) |
| `npm run prisma:generate` | Regenerate client |
| `npm run prisma:seed` | Idempotent seed script |
| `npm run prisma:studio` | Prisma Studio GUI |
| `npm run worker:transcode` / `worker:transcode:dev` | Standalone BullMQ transcode worker (prod / dev) |

**Run a single test file:** `npx jest path/to/file.test.ts` (unit) or `npx jest --config jest.integration.config.js path/to/file.test.ts` (integration). Use `-t "test name"` to filter by name.

**TS path aliases:** `@/*` → `src/*`, `@tests/*` → `tests/*` (via `tsconfig-paths` at runtime, `tsc-alias` at build).

## Commands (infra/)

```bash
cd infra
cp .env.example .env
docker compose up -d              # seaweedfs :8333, tusd :1080, nginx :80
set -a; source .env; set +a
./scripts/create-databases.sh     # provision learn_api_* on the shared accounting-postgres
./scripts/create-buckets.sh       # provision SeaweedFS buckets (after ~10s healthcheck wait)
```

Postgres (`accounting-postgres`) and Redis (`accounting-redis`) come from accounting-api's compose stack — start that first if it isn't already running. Learn-api uses `learn_api_user` + `learn_api_*` DBs + the `learn:` Redis prefix for isolation on those shared instances. Point the API at `S3_ENDPOINT=http://localhost:8333`.

**Deployment infrastructure exists in `deploy/`** (runbook: `deploy/README.md`). This is a parallel work-track, not a Phase 0–7 milestone. Focus remains on Phase 7 local hardening first; `deploy/` is ready when needed. Design respects shared-resource hygiene (ports, key prefixes, DB naming) for conflict-free VPS deployment.

## Architecture big picture

### Upload → transcode → playback pipeline

1. **Upload:** App (as `COURSE_DESIGNER`) → `POST /api/videos` → gets `{videoId, uploadUrl}` for tusd → uploads chunks (resumable) to `learn-uploads` SeaweedFS bucket.
2. **Transcode trigger:** tusd `pre-finish` hook calls `POST /internal/hooks/tusd` on learn-api → enqueues BullMQ job on the `learn:transcode` queue (shared Redis, keys prefixed `learn:`).
3. **Transcode worker** (separate process, `learn-transcode-worker`): pulls source from `learn-uploads`, FFmpeg → H.264/AAC CMAF fMP4 HLS ladder (360/540/720/1080p) → writes to `learn-vod/{videoId}/` → sets `Video.status = READY`. On success, deletes the raw upload (ADR 0006). Retries with BullMQ backoff; 3 fails → `FAILED`. Worker entrypoint is `src/workers/transcode.ts` (BullMQ wiring); pipeline logic lives in `src/workers/transcode.pipeline.ts` so it's unit-testable in isolation.
4. **Playback:** App → `GET /api/videos/{id}/playback` → learn-api checks enrollment/ownership → returns HMAC-signed master playlist URL (2–4h TTL). Flutter `video_player` + ExoPlayer fetches → Nginx `secure_link` validates HMAC on every segment request → serves from SeaweedFS. ABR handled by ExoPlayer.
5. **Cue engine:** Flutter polls `controller.value.position` every 50ms; at `cue.atMs - 200ms` calls `pause()` + `seekTo(cue.atMs)`, renders overlay widget for the cue type. On submit, `POST /api/attempts` — **grading always happens server-side, never trust the client**. Then `controller.play()`.

### Service boundaries to respect

- **`ObjectStore` interface** wraps S3 SDK calls so SeaweedFS → S3/R2 is a config swap, not a rewrite.
- **`getPlaybackUrl(videoId, userId)`** is the single seam for signed URLs — replace the body to swap to CloudFront / Cloudflare Stream. The Nginx `secure_link` HMAC implementation lives in `src/utils/hls-signer.ts`; swap that file when moving to a different CDN's signing scheme.
- **`VideoTranscoder` interface** (`transcode(sourceKey) → hlsPrefix`) lets the FFmpeg worker be replaced by AWS MediaConvert or Cloudflare Stream. Current FFmpeg implementation is under `src/services/ffmpeg/`.
- **CMAF fMP4** output is portable across CDNs — don't regress to TS segments.
- **Grading service** (`src/services/grading/`) is the canonical implementation for MCQ, BLANKS, MATCHING, and VOICE scoring. Never move grading logic to the client or to request middleware — see the "client never grades" rule above.
- **FFmpeg input policy** (`src/services/ffmpeg/input-policy.ts`) enforces container, codec, duration, and file-size limits before transcoding begins. Add new rejection reasons to `VideoFailureReason` there; do not add ad-hoc checks in the worker.

### Roles and auth

Three roles on `User`: `ADMIN`, `COURSE_DESIGNER`, `LEARNER` (default). JWT access (15m) + refresh (30d) with role claim. Middleware pattern: `authenticate` + `requireRole(...)`. Cue writes, video uploads, and course mutations require `COURSE_DESIGNER` (owner or collaborator) or `ADMIN`. Applying to become a designer goes through `DesignerApplication` (admin-approved).

### Data model conventions

- Cue `payload` is `Json` in Postgres, but **discriminated union by `type`** (`MCQ` | `MATCHING` | `BLANKS` | `VOICE`) — validate with Zod on write. `VOICE` is reserved in the enum but rejected with 501 at the API layer (ADR 0004); don't expose it in UI.
- `AnalyticsEvent.occurredAt` (client-sourced) vs `receivedAt` (server) — batched events can arrive minutes late; analytics queries should prefer `occurredAt`.

## Divergences from other Lifestream projects

These are **intentional** (per `IMPLEMENTATION_PLAN.md` §2) — don't "fix" them to match the rest of the ecosystem:

- **Node 22**, not Node 20 (required by Prisma 7; accounting-api and chatbot-api should migrate eventually, but this project starts on 22).
- **BullMQ**, not Bull (Bull is EOL in 2026; rewrite against `Queue`/`Worker`/`QueueEvents` classes — **no `Queue#process` callback**).
- **Prisma**, not raw SQL (chatbot-api uses raw SQL; this project uses Prisma like accounting-api).
- **SeaweedFS**, not MinIO (MinIO Inc. enforces AGPL against commercial users and we're publishing the code; ADR 0002).

When cloning scaffolding from `accounting-api` (TS config, ESLint, Prettier, Jest), **do not copy Bull queue code** — rewrite against BullMQ.

## Open-source hygiene (non-negotiable)

Code in `api/`, `app/`, `infra/`, `docs/` is published publicly under AGPL-3.0. Before any commit:

- **Never commit** real hostnames, internal paths (e.g. `/home/eric/...`), production secrets, or third-party API keys to these directories. Anything environment-specific lives in `ops/` only.
- `.githooks/pre-push` runs a secret scan (gitleaks if installed, regex fallback otherwise). Don't bypass with `--no-verify`.
- `ops/` is `.gitignore`d at the top level — anything inside is invisible to the monorepo and that's the point.
- Signed commits are a pre-publish goal: set up signing + branch protection before the repo split. Until then, the pre-push gitleaks scan is the enforced gate; don't let this become a habit once the repo goes public.

## Shared-resource discipline

Even though deployment is out of scope today, this project will eventually run on a machine shared with other Lifestream services. Design as if that's already true:

- **Ports:** dev port `3011`, reserved prod port `3101` (see §3 of IMPLEMENTATION_PLAN.md). Never bind `:3000`, `:3100`, `:3177`, `:5432`, `:6379`, `:80` in anything we own — those belong to the rest of the ecosystem. The Slice-G1 `/metrics` endpoint shares `:3011` (gated by `METRICS_ENABLED`) — it does NOT claim a new port like `:9090`, since that could collide with a future Prometheus server on the same host. IP-allowlist this path at the reverse proxy before any deployment.
- **Redis:** every key prefixed with `learn:`. No unprefixed keys. Ever.
- **Postgres:** our DBs are `learn_api_{production,development,test}`; our only role is `learn_api_user`. Never reach into another project's schema.
- **BullMQ queue names:** prefixed `learn:` as well (e.g. `learn:transcode`).
- **Object storage bucket names:** `learn-uploads`, `learn-vod`, `learn-backups`.
- **Prom-client metric names:** every series prefixed `learn_` (including the default Node process metrics). Default labels include `service="learn-api"` so multi-service scrapes stay distinguishable.

## Testing expectations

Per `CONTRIBUTING.md`:
- Unit coverage ≥80% on backend (enforced by Jest config).
- Integration coverage ≥85% on backend (enforced by Jest config).
- Grading logic for cue types: ≥95% unit coverage (it's security-sensitive — a wrong correct/incorrect leaks the answer or miscredits a learner).
- Integration tests need a real Postgres + Redis. We share `accounting-postgres` and `accounting-redis` (see `infra/README.md`); our fixtures target `learn_api_test` on that Postgres and use the `learn:` Redis prefix. Tests run serially (`maxWorkers: 1`).

## Project subagents

Specialist agents live in `.claude/agents/`. Invoke via the Agent tool when the task matches:

| Agent | When to invoke |
|---|---|
| `transcode-pipeline-engineer` | Upload → transcode → playback pipeline: tusd hooks, BullMQ transcode queue, FFmpeg worker, HLS ladder, ObjectStore/HLS-signer swap seams, nginx `secure_link` |
| `cue-engine-architect` | Cue scheduler, video player integration, MCQ/BLANKS/MATCHING grading, FLAG_SECURE surfaces, analytics buffer, designer authoring timeline |
| `shared-resource-guardian` | Any addition touching Redis keys, Postgres DBs/roles, BullMQ queue names, object-storage buckets, port bindings, or Prometheus metric names |
| `flutter-expert` | General Flutter work NOT touching the cue engine, player, designer authoring, or learner assessment paths (those → `cue-engine-architect`) |
| `typescript-pro` | TypeScript type-level challenges: discriminated unions, Zod patterns, generic utilities |
| `security-auditor` | Architectural security review: grading integrity, secret handling, API authorization, threat modelling |
| `code-reviewer` | Code quality review on TypeScript backend, Flutter app, or infra |
| `accessibility-tester` | WCAG compliance, assistive technology, screen reader support |

## Flutter app development (overrides default "test UI before done" rule)

Claude Code's built-in system prompt says: *"For UI or frontend changes, start the dev server and use the feature in a browser before reporting the task as complete."* **That rule does not apply to `app/`** — Claude cannot launch an Android emulator or install an APK on a physical device from its sandbox, and attempting to gate Flutter work on that would make all UI work unshippable.

**Flutter codegen:** models use `freezed` + `json_serializable`. After adding or changing any annotated model, run `dart run build_runner build --delete-conflicting-outputs` (or `make app-deps`). The `app-ci` workflow checks codegen freshness — stale generated files fail CI.

**For `app/` (Flutter) work, a task is considered complete when all of the following pass:**
1. `flutter analyze` → 0 issues.
2. `flutter test` → green (unit + widget tests for the feature, coverage targets met).
3. `flutter build apk --debug --flavor dev` → succeeds (no build-time errors, proves the tree links). The app has `dev` and `prod` Android flavors — always pass `--flavor` on build/run; a flavorless invocation will fail.
4. The commit message includes a **manual-test checklist** for the human operator to run on a real device/emulator, and explicitly marks the slice as `✎ compiled-and-analyzed-only (device test needed)` rather than `✓ verified`.

The operator (Eric) drives the final on-device verification and promotes the slice to `✓ verified` in the progress ledger. Do not claim device behaviour was verified when it wasn't. If a behaviour cannot be asserted via `flutter test` (e.g. actual playback jitter, ABR, `adb logcat` inspection), say so — don't hand-wave.

Everything else in the repo (`api/`, `infra/`, `docs/`) still follows the default verification rule: tests pass, code runs locally, changes are proven before they're reported done.

## Phase awareness

The project is pre-alpha. Phases 0–3 are complete. Phase 3 (upload → transcode → playback pipeline) is wired end-to-end and hardened: `POST /api/videos` issues tusd upload coordinates, the tusd `pre-finish` hook enqueues a `learn:transcode` BullMQ job, the FFmpeg worker validates input policy then produces a CMAF fMP4 HLS ladder, and `GET /api/videos/:id/playback` returns a short-lived MD5 secure_link URL. Integration tests cover the happy path, kill-and-resume, ffprobe-level ladder variants, and tampered-HMAC / expired-URL edge cases.

Flutter work (Phases 4–6) has advanced in parallel: auth, feed, player + cue engine (MCQ/BLANKS/MATCHING), designer authoring, admin, and an offline-survivable analytics buffer are all present under `app/lib/features/`. `IMPLEMENTATION_PLAN.md` §5 remains the source of truth for per-slice exit criteria — check it before implementing anything to confirm:
- Which phase you're in and its exit criteria
- Whether the task is listed as a **parallel-subagent split point** (§6) — if so, spawn subagents per the prescribed split rather than doing the work sequentially.
