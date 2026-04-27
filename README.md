# Lifestream Learn

Short-form educational video platform. Learners scroll a TikTok-style vertical feed of course videos that pause mid-play for interactive exercises — multiple choice, matching, fill-in-the-blank. Course Designers author courses, upload videos, and place interactive cues on a timeline.

**Source available under AGPL-3.0** · Maintained by Lifestream Dynamics

---

## Repositories

This is a multi-project workspace. Each subdirectory is published as its own public repository when we cut 1.0.

| Path | Purpose | License |
|---|---|---|
| [`api/`](./api) | Node 22 / Express / Prisma / Postgres REST API | AGPL-3.0 |
| [`app/`](./app) | Flutter Android app (iOS later) — learner + course-designer UI | AGPL-3.0 |
| [`infra/`](./infra) | Docker Compose for local development (postgres + redis are shared with accounting-api; this stack adds SeaweedFS, tusd, nginx). | AGPL-3.0 |
| [`ops/`](./ops) | **Private** — phase reports and environment notes. Git-ignored at the top level. |
| [`docs/`](./docs) | Architecture decisions, design notes, runbooks | — |

The canonical implementation plan lives at [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md).

---

## Business model

Open-source core, commercial SaaS. The code is public under AGPL-3.0. The content (videos, cues, course metadata) and user data are served only through the authenticated API run by Lifestream Dynamics. Anyone can self-host for their own content; paid subscriptions on the hosted service support development.

The hosted service URL, marketing pages, and operator contacts are not part of the open-source distribution — they live in the operator-private `ops/` directory.

---

## Tech stack at a glance

- **Mobile:** Flutter, Android-first, forked from [`FlutterWiz/flutter_video_feed`](https://github.com/FlutterWiz/flutter_video_feed) (MIT) for the feed shell
- **Backend:** Node 22.12+ · TypeScript (strict) · Express 4 · Prisma 7 · PostgreSQL 15 · Redis 7 · BullMQ
- **Storage:** SeaweedFS (S3-compatible, Apache-2.0)
- **Upload:** tusd (resumable)
- **Streaming:** FFmpeg → HLS (CMAF fMP4) → Nginx with `secure_link` HMAC tokens
- **Deploy:** not in scope yet — focus is a fully functional, locally tested app first. Migration seams (object-store abstraction, playback-URL builder, transcoder interface) are designed in from day one so the eventual hosting decision stays a config change, not a rewrite.

---

## Local development quickstart

The repo ships a top-level `Makefile` that collapses the multi-step dev workflow into a few targets. Prerequisite: the [`accounting-api`](https://github.com/lifestream-dynamics/accounting-api) compose stack must already be running, since this project shares its Postgres (`:5432`) and Redis (`:6379`).

```bash
make bootstrap   # one-time: writes infra/.env + api/.env.local with random secrets
make up          # docker compose up + DB provisioning + bucket creation + prisma migrate + seed
make api         # terminal 1: API hot-reload on :3011
make worker      # terminal 2: BullMQ transcode worker
make app         # terminal 3: launches the Android emulator + flutter run (dev flavor)
```

`make help` lists every target. `make status` prints a one-line health check. `make reset` is the destructive teardown (prompts for confirmation).

Three users are seeded automatically (all with password `Dev12345!Pass`):

| Email | Role |
|---|---|
| `admin@example.local` | ADMIN |
| `designer@example.local` | COURSE_DESIGNER |
| `learner@example.local` | LEARNER |

The verbose per-subproject command sequences are still documented in [`api/README.md`](./api), [`infra/README.md`](./infra), and [`app/README.md`](./app) for cases where you need finer control than the Makefile provides.

---

## Status

Pre-alpha. Phases 0–3 (decisions, infra, API scaffold, upload → transcode → playback pipeline) are complete. Flutter Phases 4–6 (auth, feed, player + cue engine, designer authoring, admin, analytics buffer) are code-complete on `main` — every slice passes `flutter analyze` + `flutter test` + `flutter build apk --debug --flavor dev`; on-device verification is operator-driven per the `app/` rule in `CLAUDE.md` and is currently in progress. Phase 7 (local hardening) is in flight; Phase 8 (deployment) automation lives in `deploy/`. See [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) §5 for per-phase exit criteria and the Phase 8 backlog.

---

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md). By contributing you agree your changes are licensed under AGPL-3.0. For commercial licensing inquiries, contact `learn@lifestreamdynamics.com`.
