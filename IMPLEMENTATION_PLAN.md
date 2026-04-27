# Lifestream Learn — Implementation Plan

**Document owner:** Eric
**Last updated:** 2026-04-26 (Phase 8 deployment hardening in flight; Phase 7 hardening complete in code; ADR-0007 JWT rotation + tusd fix resolved)
**Status:** Draft — pending approval

> **Scope note (2026-04-19):** deployment is deliberately out of scope for this plan. The goal is a fully functional, locally tested application end-to-end before we pick a hosting strategy. Shared-resource hygiene (ports, key prefixes, DB naming) is honoured from day one so that decision stays low-friction later.

### Distribution model

**Open-source core, commercial SaaS eventually.** Code is public; content and data are not. Precedent: GitLab, Mattermost, Sentry, Plausible.

- **License:** AGPL-3.0 for both backend and app repos. Protects against a well-funded competitor running a hosted clone against us; self-hosters and contributors remain unaffected. Option to dual-license later if enterprise demand appears.
- **Repo layout:** three public repos — `lifestream-learn-api`, `lifestream-learn-app`, `lifestream-learn-infra`. A private `ops/` directory at the top of the monorepo holds phase reports and environment notes; it never ships to a public repo.
- **Kept out of public repos:** any `.env` files with real values, course content, DB dumps, real hostnames or paths, signing keys, third-party API keys.

---

## 0. Product Summary

An Android-first educational short-video app. Learners scroll a vertical TikTok-style feed of course videos that pause at authored timestamps to present interactive exercises: multiple-choice, matching, fill-in-the-blank, and voice-capture pronunciation scoring. Content is organized into courses authored by approved Course Designers. Video storage, transcoding, streaming, and APIs are designed for self-hosting (SeaweedFS + tusd + FFmpeg + Nginx) with a deliberate migration seam to cloud CDN/object storage should that ever become the right trade-off.

### Roles

- **Admin** — approves Course Designer applications; global moderation
- **Course Designer** — creates courses, uploads videos, authors interactive cues; managed via admin approval + per-course collaborator list
- **Learner** — default role; consumes feed, completes exercises, tracks progress

### Surfaces

- A minimal landing page (pitch + terms/privacy/app-store links) — whatever domain the eventual host uses
- A REST API (the same host)
- All learner and designer UI lives inside the Flutter app

---

## 1. Architecture (Target State — local)

```
┌──────────────────────────┐        ┌─────────────────────────────────────┐
│  Flutter App (Android)   │        │  Local dev machine                  │
│  ─────────────────────   │        │  ──────────────────────────────     │
│  • TikTok-style feed     │ HTTP   │  Nginx (routing, secure_link)       │
│  • Interactive overlays  │◀──────▶│    ├─ /          → landing          │
│  • tus resumable upload  │        │    ├─ /api/*     → learn-api        │
│  • record → audio blob   │        │    ├─ /uploads/* → tusd              │
│  • HLS playback          │        │    └─ /hls/*     → SeaweedFS (signed)│
│                          │        │                                     │
└──────────────────────────┘        │  learn-api (Node 22, Express,       │
                                     │    Prisma, port 3011)              │
                                     │  learn-transcode-worker            │
                                     │  tusd (resumable upload, :1080)    │
                                     │  SeaweedFS (S3-compatible,         │
                                     │    buckets: learn-uploads/learn-vod│
                                     │  [shared] PostgreSQL via           │
                                     │    accounting-postgres (learn_api_*│
                                     │  [shared] Redis via accounting-redis│
                                     │    (prefix learn:)                  │
                                     └─────────────────────────────────────┘
```

TLS, domain name, process supervisor, and host paths are deliberately left abstract — those are deployment decisions for later.

### Data flow — video upload

1. App authenticates (JWT, Course Designer role) → requests `POST /api/videos` → gets `{videoId, uploadUrl}` pointing at tusd.
2. App uploads chunks via tus to `uploads/{videoId}` bucket in SeaweedFS.
3. tusd `pre-finish` hook calls learn-api → learn-api enqueues BullMQ job `learn:transcode`.
4. Worker pulls source from SeaweedFS `uploads/`, runs FFmpeg to produce H.264/AAC CMAF fMP4 HLS ladder (360/540/720/1080p), writes to SeaweedFS `vod/{videoId}/`, updates DB status `READY`.
5. Designer authors cues in the app → `POST /api/videos/{id}/cues`.

### Data flow — learner playback

1. App calls `GET /api/feed?cursor=…` → list of videos with metadata + cue manifest URL.
2. App calls `GET /api/videos/{id}/playback` → learn-api returns a master-playlist URL containing an HMAC `secure_link` signature (2–4h TTL).
3. Flutter `video_player` fetches master → segments via Nginx (HMAC validated per request); ExoPlayer handles ABR.
4. At each cue's `atMs - 200ms`, a 50ms polling timer calls `controller.pause()`; overlay widget renders; on submit, app `POST /api/attempts`; then `controller.play()`.

---

## 2. Technology Decisions (with rationale)

| Layer | Choice | Rationale |
|---|---|---|
| Mobile framework | Flutter 3.x, Android-first | User-selected; cross-platform ready for iOS later |
| Feed base | Fork [`FlutterWiz/flutter_video_feed`](https://github.com/FlutterWiz/flutter_video_feed) (MIT) | LRU controller cache, BLoC architecture, 2025-maintained; saves ~1-2 weeks |
| Video player | `video_player` (official) + `fvp` backend registrar | ExoPlayer HLS on Android, free overlay composition via `Stack`; upgrade to `media_kit` only if <100ms cue accuracy required |
| Upload client | `tus_client_dart` | Resumable on flaky cellular |
| Backend runtime | Node 22.12+ LTS + TypeScript strict + Express 4 | **Upgrade from accounting-api's Node 20 baseline.** Required-minimum 22.12 (Prisma 7), locked via `.nvmrc` and `engines` in `package.json`. Node 22 is Active LTS through late 2025, Maintenance LTS into 2027. |
| ORM / DB | Prisma + PostgreSQL 15 | Matches ecosystem; Prisma preferred over chatbot-api's raw SQL |
| Queue | BullMQ ≥5.x on shared Redis 7 (prefix `learn:`) | **Diverges from accounting-api** (which uses legacy Bull). Bull entered EOL in 2026; BullMQ is the maintained TypeScript rewrite with Node 22+ support. Accounting-api should migrate eventually, but learn-api starts on BullMQ from day one. |
| Auth | JWT access+refresh, roles `ADMIN`/`COURSE_DESIGNER`/`LEARNER` | Mirrors ecosystem auth-helpers shape |
| Object storage | **SeaweedFS** (S3-compatible, Apache-2.0) | Chosen over MinIO because MinIO Inc. enforces AGPL aggressively against commercial users and we're open-sourcing the code. SeaweedFS is permissively licensed, single-binary, and keeps the "migrate to S3/R2/CloudFront later = config change" property |
| Upload server | tusd | Industry-standard resumable protocol |
| Transcode | FFmpeg CLI in a BullMQ worker (separate process) | No separate packager; HLS CMAF fMP4 |
| Streaming | Nginx static serving of SeaweedFS-backed HLS + `secure_link` | VOD = static files; simplest viable stack |
| Codec | H.264 Main + AAC | Universal Android; skip HEVC (licensing) and AV1 (decoder coverage) |
| Pronunciation scoring | **Deferred to post-MVP** | MVP ships MCQ, matching, blanks only. Voice cue type reserved in schema; engine hooks left as stubs. Revisit after PMF — candidates: Azure Pronunciation Assessment, self-hosted Kaldi GOP |
| Cue schema | Custom JSON sidecar (discriminated union) | H5P has no Flutter runtime; bespoke schema is simpler and exportable later |
| Reverse proxy | Nginx | Handles `secure_link` HMAC validation for HLS; TLS configured per deployment later |
| Deployment | **Out of scope until the app is production-ready locally.** | Design still assumes shared infra (ports, prefixes) so the eventual deploy is low-friction. |

### Active risks

- **SeaweedFS operational familiarity** — less mainstream than MinIO. Phase 1 smoke test passed; if it proves painful later, fall back to filesystem behind an S3-API shim (same abstraction, still license-safe).
- **Open-source repo hygiene** — every config template and script must be clean of real hostnames, internal paths, and secrets before first public push. Enforced via `.githooks/pre-push` secret scan and the `ops/` gitignore wall.
- **AGPL-3.0 contribution friction** — some contributors avoid AGPL. Accept as a trade-off; mention dual-licensing option in CONTRIBUTING.md.

---

## 3. Shared-resource allocation

Fixed from day one so the app is deploy-ready onto a shared host without conflict. None of these are deployment decisions — they're naming conventions that prevent later surprises.

| Resource | Value |
|---|---|
| learn-api port (dev) | **3011** |
| learn-api port (reserved for later prod) | **3101** |
| tusd port (internal) | 1080 |
| SeaweedFS S3 API port (internal) | 8333 |
| SeaweedFS master/filer ports (internal) | 9333 (master), 8888 (filer) |
| PostgreSQL DB names | `learn_api_production`, `learn_api_development`, `learn_api_test` |
| PostgreSQL user | `learn_api_user` |
| Redis key prefix | `learn:` |
| BullMQ queue prefix | `learn:` (e.g. `learn:transcode`) |
| SeaweedFS bucket names | `learn-uploads`, `learn-vod`, (future) `learn-backups` |

Postgres (`accounting-postgres`) and Redis (`accounting-redis`) are shared with accounting-api during local dev — we only own the role, DBs, and key prefix above.

---

## 4. Data Model (initial)

Prisma schema outline (not final SQL):

```prisma
model User {
  id             String   @id @default(uuid())
  email          String   @unique
  passwordHash   String
  role           Role     @default(LEARNER)   // ADMIN | COURSE_DESIGNER | LEARNER
  displayName    String
  createdAt      DateTime @default(now())
  designerApp    DesignerApplication?
  enrollments    Enrollment[]
  attempts       Attempt[]
  ownedCourses   Course[]      @relation("CourseOwner")
  collaborations CourseCollaborator[]
}

model DesignerApplication {
  id          String   @id @default(uuid())
  userId      String   @unique
  status      AppStatus  // PENDING | APPROVED | REJECTED
  reviewedBy  String?
  submittedAt DateTime
  reviewedAt  DateTime?
  note        String?
}

model Course {
  id            String   @id @default(uuid())
  slug          String   @unique
  title         String
  description   String
  coverImageUrl String?
  ownerId       String
  owner         User     @relation("CourseOwner", fields: [ownerId], references: [id])
  published     Boolean  @default(false)
  videos        Video[]
  collaborators CourseCollaborator[]
  enrollments   Enrollment[]
  createdAt     DateTime @default(now())
}

model CourseCollaborator {
  courseId String
  userId   String
  course   Course @relation(fields: [courseId], references: [id])
  user     User   @relation(fields: [userId], references: [id])
  addedAt  DateTime @default(now())
  @@id([courseId, userId])
}

model Video {
  id             String   @id @default(uuid())
  courseId       String
  course         Course   @relation(fields: [courseId], references: [id])
  title          String
  orderIndex     Int
  status         VideoStatus  // UPLOADING | TRANSCODING | READY | FAILED
  durationMs     Int?
  sourceKey      String?      // SeaweedFS key of original upload
  hlsPrefix      String?      // SeaweedFS prefix of HLS ladder
  cues           Cue[]
  attempts       Attempt[]
  createdAt      DateTime @default(now())
}

model Cue {
  id         String  @id @default(uuid())
  videoId    String
  video      Video   @relation(fields: [videoId], references: [id])
  atMs       Int
  pause      Boolean @default(true)
  type       CueType // MCQ | MATCHING | BLANKS | VOICE
  payload    Json    // discriminated union by type
  orderIndex Int
}

model Enrollment {
  id        String   @id @default(uuid())
  userId    String
  courseId  String
  user      User     @relation(fields: [userId], references: [id])
  course    Course   @relation(fields: [courseId], references: [id])
  startedAt DateTime @default(now())
  lastVideoId String?
  lastPosMs  Int?
  @@unique([userId, courseId])
}

model Attempt {
  id         String   @id @default(uuid())
  userId     String
  videoId    String
  cueId      String
  correct    Boolean
  scoreJson  Json?      // pronunciation detail, match pairings, etc.
  submittedAt DateTime @default(now())
  user       User @relation(fields: [userId], references: [id])
  video      Video @relation(fields: [videoId], references: [id])
}

model AnalyticsEvent {
  id         String   @id @default(uuid())
  userId     String?
  eventType  String   // video_view, video_complete, cue_shown, cue_answered, session_start, …
  videoId    String?
  cueId      String?
  payload    Json
  occurredAt DateTime
  receivedAt DateTime @default(now())
}
```

### Cue payload schemas (canonical)

```ts
// type: "MCQ"
{ question: string; choices: string[]; answerIndex: number; explanation?: string }

// type: "MATCHING"
{ prompt: string; left: string[]; right: string[]; pairs: [number, number][] }

// type: "BLANKS"
{ sentenceTemplate: string;  // e.g. "The capital of France is {{0}}."
  blanks: { accept: string[]; caseSensitive?: boolean }[] }

// type: "VOICE" — reserved enum value; payload shape deferred until post-MVP.
// Cue authoring UI will not expose this type; backend rejects creation with 501.
```

---

## 5. Phases

Each phase has **exit criteria** that must all be met before the next phase begins. Phases 2-7 are intended to be implemented with parallel subagents where tasks are independent (per user-level CLAUDE.md rules).

### Phase 0 — Decisions & Scaffolding  ✓ complete

**Goal:** Lock the major decisions; land the repo skeleton.

**Resolved:**
- Voice capture cue deferred to post-MVP (ADR 0004). Schema keeps the `VOICE` enum value; engine treats it as `unimplemented` until revisited.
- Object storage: SeaweedFS, not MinIO (ADR 0002).
- License: AGPL-3.0 for all three public repos (ADR 0001).
- Monorepo with private top-level `ops/` directory (ADR 0005).
- Storage-conscious guardrails at the API and worker layer (ADR 0006).

**Delivered:**
- `api/`, `app/`, `infra/` scaffolds plus root LICENSE, README, CONTRIBUTING, CODE_OF_CONDUCT.
- `.gitignore` + `.githooks/pre-push` secret scan.

---

### Phase 1 — Local infrastructure  ✓ complete for MVP scope

**Goal:** A local docker-compose stack that backs every piece of the app — object store, upload gateway, reverse proxy, landing page — so Phase 2+ work has somewhere to plug in.

**Delivered:**
1. `infra/docker-compose.yml` — seaweedfs, tusd, nginx. **No Postgres or Redis here**: this project borrows `accounting-postgres` and `accounting-redis` from accounting-api's compose and isolates itself with a `learn_api_user` role + `learn_api_*` DBs + `learn:` Redis key prefix.
2. `infra/nginx/local.conf` + `infra/nginx/secure_link.conf.inc` — plain-HTTP reverse proxy for `/api/*`, `/uploads/*`, `/hls/*` (signed-URL validation using Nginx `secure_link` stock MD5 — see `secure_link.conf.inc` for the rationale and SHA256 upgrade path).
3. `infra/seaweedfs/s3.json` — two-identity IAM: `learn-api-rw` (full) and `tusd-upload` (write-only to `learn-uploads/`).
4. `infra/landing/` — `index.html`, `terms.html`, `privacy.html`.
5. `infra/scripts/` — `create-databases.sh` (idempotent DB/user bootstrap on the shared Postgres), `create-buckets.sh` (SeaweedFS bucket provisioning), `sign-hls-url.sh` (signed-URL helper), `disk-alert.sh` (standalone watchdog — not yet scheduled, that's a deploy concern).
6. `scripts/tests/*.bats` — 34 BATS cases covering every shell script.

**Exit criteria — all met:**
- Landing page served, `/health` → 200.
- `learn_api_user` connects to `learn_api_development` on accounting-postgres.
- `redis-cli SET learn:ping` round-trips on accounting-redis.
- SeaweedFS buckets `learn-uploads` + `learn-vod` created idempotently.
- tus resumable upload via `/uploads/files/` → 201 Created, file lands in `learn-uploads`.
- `secure_link`: unsigned → 403, tampered → 403, expired → 410, valid → proxied to SeaweedFS.
- BATS: 34/34 pass.

**Not in scope:** TLS/Certbot, systemd units, process supervision, domain registration, disk-alert scheduling — all deferred with the deploy strategy.

---

### Phase 2 — learn-api Scaffold  ✓ complete

**Goal:** A working Express API on port 3011 (dev) with auth, health check, and empty domain routes — but no video logic yet.

**Tasks:**
1. Clone structure from `accounting-api` (do NOT copy domain code; copy only scaffolding: TS config, ESLint, Prettier, Jest, Winston/Morgan/Helmet/rate-limit setup, Prisma setup, OpenAPI JSDoc scaffold). **Do not copy the Bull queue code** — rewrite against BullMQ API (`Queue`, `Worker`, `QueueEvents` classes; no `Queue#process` callback).
2. Initialize Prisma 7 (requires Node 22.12+) with schema from §4.
3. Run initial migration against `learn_api_development` on the shared accounting-postgres.
4. Auth: email/password signup + login endpoints returning JWT access (15 min) + refresh (30 days); role claim present; copy `authenticate`, `requireRole` middleware shape from `accounting-api/src/middleware/helpers/auth-helpers.ts`.
5. Role seed: create admin user via Prisma seed script (idempotent).
6. Route stubs (return `501 Not Implemented`) for: `/api/courses`, `/api/videos`, `/api/cues`, `/api/attempts`, `/api/voice-attempts`, `/api/feed`, `/api/designer-applications`, `/api/events`.
7. Health endpoint at `/health` returning DB + Redis + SeaweedFS connectivity status.
8. OpenAPI docs served at `/api/docs` (local/dev only).

**Exit criteria — all met:**
- `curl http://localhost:3011/health` returns 200 with all dependencies "ok" (DB + Redis + S3 + BullMQ).
- Signup → login → protected-route round-trip works end-to-end (`tests/integration/auth.flow.test.ts`).
- Unit tests pass at ≥80% coverage on middleware and auth.
- Integration tests pass at ≥85% coverage against `learn_api_test`.

---

### Phase 3 — Upload + Transcode Pipeline  (in flight)

**Goal:** A Course Designer (via curl/Postman for now) can upload a raw video, and the system produces a playable HLS ladder served behind signed URLs. Still no Flutter app.

**Tasks (status as of 2026-04-19):**
1. ✓ `POST /api/videos` → creates `Video` row with `status=UPLOADING`, returns `{videoId, uploadUrl, uploadHeaders, sourceKey}` for resumable tusd upload.
2. ✓ tusd `pre-finish` hook → hits learn-api `POST /internal/hooks/tusd` (timing-safe shared secret via `?token=`) → enqueues `learn:transcode` BullMQ job keyed by `videoId`.
3. ✓ `learn-transcode-worker` (separate process, `npm run worker:transcode:dev` in dev): pulls source via `ObjectStore.downloadToFile`, ffprobe, FFmpeg CMAF fMP4 ladder, uploads via `ObjectStore.uploadDirectory`, writes master playlist last, transitions `Video` → `READY`, deletes raw upload (ADR 0006).
4. ✓ Failure path: BullMQ `attempts: 3` + exponential backoff (2s base); after exhaustion the row stays UPLOADING/TRANSCODING and the job sits in `failed` for inspection. Pipeline tolerates Prisma P2025 on the UPLOADING→TRANSCODING transition (idempotent retry) and only commits READY from `{UPLOADING,TRANSCODING}`.
5. ✓ `GET /api/videos/{id}/playback` → `videoService.canAccessVideo` checks `ADMIN | owner | collaborator | enrolled learner`; signs master playlist URL via `signPlaybackUrl` (MD5 secure_link, 2h TTL); 409 when status≠READY.
6. ✓ Nginx `secure_link` config validates HMAC on every request under `/hls/` (delivered in Phase 1; `infra/nginx/secure_link.conf.inc`).
7. ✓ Shell tests under `infra/scripts/tests/*.bats` (delivered in Phase 1).

**Exit criteria:**
- ✓ End-to-end: tus upload of `tests/fixtures/sample-3s.mp4` → status reaches READY (`tests/integration/transcode-e2e.test.ts`).
- ✓ `ffprobe` on produced master playlist shows 4 variant streams with correct bitrates — programmatic assertion in `tests/integration/transcode-e2e.test.ts:174-219` parses `master.m3u8`, verifies every variant exists in S3, checks codec strings (`avc1.`, `mp4a.`) and bandwidth values (Slice G3, 2026-04-23).
- ✓ Signed master URL → `tests/unit/utils/hls-signer.test.ts` covers MD5 byte-equivalence with `infra/scripts/sign-hls-url.sh`; nginx behaviour (403 expired/tampered, 200 valid) is exercised by infra BATS suite.
- ✓ `curl` to a segment URL with tampered HMAC → asserted via `tests/integration/secure-link.test.ts:38-74` (tampered signature → 403, tampered videoId → 403, expired URL → 410). Covers both nginx layer and API-side multi-path token authorization.
- ✓ Transcode worker survives a simulated kill mid-job and resumes cleanly (`tests/integration/transcode-resilience.test.ts`).
- ✗ BullMQ dashboard (Bull Board) — deferred; not blocking pipeline correctness.
7. ✓ FFmpeg input policy enforced (`src/services/ffmpeg/input-policy.ts`): rejects unsupported containers, codec combinations, oversized/overlong inputs, and rotated-portrait edge cases.
8. ✓ Poster extraction on transcode completion (`src/services/ffmpeg/poster.ts`); `posterKey` stored on `Video` row.

---

### Phase 4 — Flutter Learner App (read-only feed)

**Goal:** Learner can sign up, log in, scroll a vertical feed of seeded videos, and watch them with ABR. No interactivity yet.

**Tasks:**
1. Fork `FlutterWiz/flutter_video_feed` into `app/` (Flutter project)
2. Flutter project setup: Android-only build initially; Dart/Flutter version pinned; `fvm` config
3. Seed the local learn-api with 3-5 test videos (uploaded via Phase 3 flow) and enroll a test learner
4. Auth screens: signup, login, "forgot password" stub
5. Feed screen: `PageView` wrapping `flutter_video_feed`'s controller pool, points at `/api/feed` + `/api/videos/{id}/playback`
6. Video player wiring: `video_player` controller per page, preload ±1, dispose on leave
7. Dio HTTP client with JWT interceptor (access/refresh rotation)
8. Riverpod or BLoC for state (stick with BLoC since the fork uses it)
9. Error/loading/empty states
10. Integration test: a widget test that mounts the feed with a fake API and scrolls 3 pages

**Exit criteria:**
- APK installs on a physical Android device (Android 10+)
- Signup + login work against the local learn-api
- Feed loads ≥5 seeded videos; each plays immediately on view
- Swipe up advances to next video with no visible buffer gap on a good connection
- Network throttled to 3G: ABR drops to 360p within ~10s; no stalls >3s
- No JWT leaks in logs; refresh rotation works (tested by expiring an access token)

---

### Phase 5 — Interactive Cues (MCQ → Blanks → Matching)

**Goal:** Learners see and complete MCQ, fill-in-the-blank, and matching exercises mid-video. Course Designers can author them via the app. Voice cue type is stubbed in the schema but not exposed in UI.

**Tasks (split into parallel subagent work):**

**Subagent A — Backend cue CRUD + attempts:**
1. `POST /api/videos/{id}/cues`, `PATCH /api/cues/{id}`, `DELETE /api/cues/{id}` with Zod validation per cue type
2. Authorization: only course owner or collaborator can write
3. `GET /api/videos/{id}/cues` returns ordered cues for authenticated enrolled learner
4. `POST /api/attempts` — accepts `{cueId, response}`, server-side grades (never trust client), stores result
5. Grading logic per cue type in pure functions; unit tests ≥95% coverage on grading

**Subagent B — Flutter cue engine:**
1. 50ms `Timer.periodic` in the video page polls `controller.value.position`; when next cue `atMs - 200ms` reached, `await controller.pause()` + `seekTo(cue.atMs)`, show overlay
2. Cue registry: discriminated union on `type` → widget factory
3. MCQ widget: question + 2-4 choices; single-select; submit disables; feedback render + optional explanation; continue button resumes video
4. Blanks widget: template rendered with inline `TextField`s; submit → grade server-side
5. Matching widget: two columns, draw-line or drag-to-match interaction; submit → grade server-side
6. Post-submit: `POST /api/attempts`; display correctness + explanation; `controller.play()` on "Continue"
7. Skipped cue handling: if `pause=false`, show overlay but allow video to continue; if `pause=true` and user backgrounds the app, pause persists until they return

**Subagent C — Designer cue authoring (app-side):**
1. Designer login route; gated by `COURSE_DESIGNER` role
2. "My Courses" screen (list + create)
3. Per-course video list + upload button (tus_client_dart against `/api/videos` → tusd)
4. Video editor: timeline scrubber + "add cue at current time" button → modal form per cue type
5. Save drafts locally; "Publish" sends to API

**Exit criteria:**
- All three cue types pass end-to-end manual test on-device: video pauses at correct timestamp (±100ms), overlay renders, submission scores correctly, video resumes
- Server-side grading matches client expectations in 100% of unit test cases (parameterized tests per cue type)
- Designer can author a 5-cue video via the app without touching curl
- Attempting to write cues without `COURSE_DESIGNER` role returns 403
- `plan-validation-and-review` skill shows no dead/duplicate code

---

### Phase 6 — Designer Approval, Analytics, Polish

**Goal:** Admin can approve designer applications; learners see course/progress UI; analytics captured.

**Tasks:**
1. `POST /api/designer-applications` (any authenticated learner); `GET /api/admin/designer-applications`; `PATCH /api/admin/designer-applications/{id}` (approve/reject)
2. Flutter: "Become a Course Designer" flow for learners; admin review screen for admins
3. Enrollment: `POST /api/enrollments`, `GET /api/enrollments`; learner-facing "My Courses" + "Browse Courses"
4. Resume-where-left-off: enrollment stores `lastVideoId` + `lastPosMs`, updated on video progress events
5. Analytics: Flutter batches events (start/pause/resume/complete, cue shown/answered) to `POST /api/events`; backend stores in `AnalyticsEvent`
6. Minimal admin analytics endpoints: `/api/admin/analytics/courses/{id}` (views, completion rate, avg cue accuracy)
7. App polish: icon, splash, store-ready screenshots, in-app "About" with links to terms/privacy

**Exit criteria:**
- Full end-to-end: new user → applies to be designer → admin approves → creates course → uploads video → authors cues → publishes → another learner enrolls → completes video → analytics show in admin endpoint
- Analytics batching tolerates 30 min offline without event loss
- App passes a run of Android Studio "App Inspection" with no leaked resources

---

### Phase 7 — Local hardening

**Goal:** The full app is production-ready *locally* — correctness, accessibility, crash reporting, security review — before any deployment work.

**Tasks:**
1. Local load test of learn-api against the local stack: 200 concurrent simulated learners, sustained 30 min; tune Postgres pool, Nginx workers, SeaweedFS connection limits. Record baseline numbers so we have something to compare against after a future deploy.
2. Security audit: run `security-review` skill on all backend code.
3. Accessibility pass on the Flutter app: TalkBack works on MCQ/blanks/matching; sufficient color contrast.
4. Crash reporting wired into app + API (Sentry or equivalent). Configurable via env so the endpoint can be pointed anywhere later.
5. `plan-validation-and-review` skill on the whole codebase.

**Exit criteria:**
- Full end-to-end user journey works reliably on a local build for multiple days without manual intervention
- Local load test meets targets with p95 latency <500ms on API and <1s TTFB on HLS master playlist
- Zero crashes in a 2-day smoke test on 3 devices
- Security review green

---

### Phase 8 — Deployment Hardening  (in flight)
**Goal:** Ship to the production VPS with the same quality bar as local. Deployment is driven by `lsd` (Lifestream ecosystem deploy CLI) against operator-private manifests in `ops/lsd/`; this phase closes the gap between "locally production-ready" (Phase 7) and "publicly accessible."

**Tasks:**
1. `lsd`-driven atomic deploy with PM2 reload — runs from operator workstation; idempotent. Manifests at `ops/lsd/learn-api/deploy.yaml` and `ops/lsd/learn-landing/deploy.yaml` (operator-private).
2. PM2 services declared in the lsd manifest: `learn-api`, `learn-transcode-worker`. Long-running daemons (`learn-tusd`, `learn-seaweedfs`) remain hand-managed via a one-time PM2 `start` + `pm2 save`. `TRANSCODE_CONCURRENCY=1` baked into env.
3. Nginx vhosts for the API + landing page rendered by lsd from operator-private templates in `ops/nginx/`. `/metrics` and `/internal/` IP-allowlisted to loopback + docker bridge (resolved 2026-04-26 — see threat model TM-001).
4. Let's Encrypt TLS auto-provisioned by lsd Phase 4 if missing, with renewal handled by certbot's system timer.
5. First-time VPS prereqs (`deploy/lsd-migration.md`): FFmpeg install, SeaweedFS bucket provisioning, secrets imported into lsd-vault.
6. Health verification post-deploy: `/health/liveness`, `/health/readiness`, signed playback round-trip.

**Exit criteria:**
1. `lsd deploy learn-api` green on a clean VPS (documented in `deploy/lsd-migration.md`).
2. Learn-api + transcode worker running under PM2; both restart cleanly on PM2 reload.
3. Nginx vhost for the public API host serves with valid TLS; `/metrics` + `/internal/` reject non-allowlisted IPs.
4. `/health/readiness` is 200 at the production URL.
5. `~~CPR-007~~` (bootstrap HLS port bug) resolved (2026-04-26).
6. Signed playback round-trips in production: tusd upload → transcode → master playlist returns 200, segment fetch with valid HMAC returns 200, tampered HMAC returns 403.

**Phase 8 Slices ledger (post-Phase-7 work shipped through 2026-04-26):**

These slices landed after the original Phase 7 close and span observability, hardening, UX, deploy prep, and designer authoring. On-device verification for Flutter slices remains the operator's call (per the Flutter rule in `CLAUDE.md`); Claude marks them `✎ compiled-and-analyzed-only` and Eric promotes to `✓ verified` after a real-device pass.

| Slice | Scope (one-line) |
|---|---|
| G1 | Observability env vars (`METRICS_ENABLED`, IP-allowlist note); CLAUDE.md shared-resource note for `/metrics` on `:3011`. |
| G2 | k6 learner-session scenario, HTTP keepalive on signed-playback path, perf baseline captured. |
| G3 | `npm audit` clean-up, ffprobe assertion in transcode tests, tampered-HMAC + expired-URL coverage, threat model v1, pre-push hook regex fallback fix. |
| H | Account/profile feature bundle: gamification, progress, data export, MFA UI (TOTP + WebAuthn + backup codes), session management. |
| V1 | Video-input hardening (container/codec/duration/size policy) + FLAG_SECURE-ready player polish. |
| U1 | UI overhaul: brand rollout, cyan theme, dark/light mode, splash + launcher icon. |
| P5–P9 | Playback polish: seek bar refinement, double-tap accumulation, back-button guard, fullscreen orientation, layout fix. |
| D1, D1.1 | Production deploy prep for `learn-api` + landing page on the production VPS; Android release signing wiring. |
| D2, D2.1 | Designer editor timeline seek + live playhead; deploy polish, privacy/terms content, Android manifest fixes. |

**Phase 8 backlog (deferred items, ordered by priority):**

| Item | Source | Notes |
|---|---|---|
| Linode block-storage volume attach (≥100 GB) | `ops/vps-prereq-check-2026-04-18.md` (VPS-002) | Operator decision; software guardrails (180s duration cap, raw-upload deletion per ADR 0006) keep MVP launch viable on the existing 38 GB until volume is attached. |
| VPS RAM/CPU upgrade (8 GB / 4 cores) | `ops/vps-prereq-check-2026-04-18.md` (VPS-003/004) | Linode plan upgrade. Software mitigations already in place: `TRANSCODE_CONCURRENCY=1` (`api/src/config/env.ts:93`), `nice -n 10` wrapper (`deploy/pm2/ecosystem.config.cjs:60-66`). |
| JWT dual-secret rotation (`*_PREVIOUS`) | threat-model.md §6 row 2 | RESOLVED 2026-04-26 — see ADR 0007. `JWT_ACCESS_SECRET_PREVIOUS` / `JWT_REFRESH_SECRET_PREVIOUS` are accepted on verify (sign always uses current); `learn_jwt_verify_with_previous_total{tokenType=...}` reports rotation-window usage. Operator runbook in `api/.env.example`. |
| MD5 → SHA256 secure_link upgrade | threat-model.md §6 row 1 | Nginx supports `secure_link_sha256`; `hls-signer.ts` swap is a one-line change. Run both algorithms in parallel for ~1 week, then cut over. |
| `disk-alert.sh` scheduling | ADR 0006; `ops/phase-1-completion-2026-04-19.md` | Script + BATS tests exist (`infra/scripts/disk-alert.sh`); systemd timer/cron not yet wired. |
| `gitleaks` install + CI enforcement | threat-model.md §6 row 5 | Document install in CONTRIBUTING.md; add CI check in `.github/workflows/secret-scan.yml` to fail when binary missing. |
| ~~tusd `Location` header `-base-path` fix~~ | `ops/phase-1-completion-2026-04-19.md` (V8) | RESOLVED 2026-04-26 — tusd started with `-base-path=/uploads/files/ -behind-proxy`; nginx rewrite removed; `TUSD_PUBLIC_URL` now nginx-proxied; BATS + Flutter regression tests added. |
| `tus_client_dart` major upgrade (5.0+) | `app/pubspec.yaml:26` | Roadmap target was `^5.0.0`; pinned at `^2.5.0` because the upstream 5.x line was a fork that never hit pub.dev. Reassess in H2 2026 dep upgrade slice. |
| Flutter dep upgrade pass (24 outdated, 3 discontinued transitives) | threat-model.md §6 row 4 | Single dedicated slice; full test suite must stay green under fresh lint rules. |
| Crash reporter wiring (`@lifestream/doctor-node`) | `api/src/observability/doctor-reporter.ts` | Seam exists; awaits upstream package publication. Until then `CRASH_REPORTING_ENABLED=true` logs captures only. |
| Production APK signing config | `app/README.md:100` | Conditional release signing already wired (`app/android/app/build.gradle.kts:62-69`); operator must populate `ops/keystore/key.properties`. Separate Play Store slice. |
| Compose-dependent tests in CI | CPR-011 (now resolved as documentation) | Pre-merge local gate documented in `CONTRIBUTING.md` (2026-04-26). Promoting to a nightly GHA workflow is a future option if local gate fails to hold the line. |
| AWS SDK dynamic-import friction under Jest | `tests/integration/health.test.ts` | `@aws-sdk/client-s3` v3 lazily `await import('node:http')` / `'@smithy/credential-provider-imds'` from middleware paths. Jest's classic VM rejects these without `--experimental-vm-modules` (surfaces as `ERR_VM_DYNAMIC_IMPORT_CALLBACK_MISSING_FLAG`). Mitigated in `src/config/s3.ts` (eager `NodeHttpHandler` + `defaultsMode: 'standard'`); the deepest middleware path still fails one assertion in the health integration test. Real fix: migrate the integration suite to ESM Jest, or vendor a thinner S3 client. Production code path is unaffected — manually verified that the API serves `/health = ok` against the local compose stack. |

---

## 6. Parallel Work Opportunities

Per user-level CLAUDE.md, phases with 2+ independent tasks should be implemented with parallel subagents. Natural split points:

- **Phase 1 (done):** one subagent per service — SeaweedFS + tusd, Nginx + secure_link, scripts + landing page + disk-alert — ran 3-way parallel during scaffolding.
- **Phase 2:** one for Prisma schema + migrations, one for auth middleware + JWT, one for route scaffolding + OpenAPI.
- **Phase 3:** one for tusd+hook integration, one for transcode worker + FFmpeg ladder, one for signed-URL issuance + secure_link tuning.
- **Phase 4:** one for auth flows, one for feed + player, one for API client + state.
- **Phase 5:** subagents A/B/C as specified above.
- **Phase 7:** one for load test, one for security audit.

---

## 7. Migration Seams (host-portable from day one)

Deliberate seams so the eventual hosting decision stays a config change, not a rewrite:

1. **Storage abstraction:** all reads/writes go through a single `ObjectStore` interface (S3 SDK under the hood). Swap the `S3_ENDPOINT` env var to any S3-compatible endpoint (AWS S3, Cloudflare R2, Backblaze B2, a self-hosted SeaweedFS, etc.) with no code change.
2. **Playback URL builder:** one `getPlaybackUrl(videoId, userId)` service method. Replace its body to issue CloudFront signed URLs, Cloudflare Stream signed tokens, etc.
3. **Transcode abstraction:** `VideoTranscoder` interface with `transcode(sourceKey) → hlsPrefix`. Replace the FFmpeg worker with AWS MediaConvert or Cloudflare Stream API without touching routes.
4. **CMAF fMP4 output format:** portable across CloudFront, Cloudflare, Bunny, Fastly, etc.

---

## 8. Effort Estimate (rough)

Assuming Eric + Claude Code working through these in order, with subagent parallelism where noted:

| Phase | Estimate |
|---|---|
| 0 — Decisions & scaffolding | ✓ complete |
| 1 — Local infra | ✓ complete |
| 2 — API scaffold | 2-3 days |
| 3 — Upload/transcode | 3-4 days |
| 4 — Flutter feed | 4-6 days |
| 5 — Cues MVP (MCQ, matching, blanks) | 6-8 days |
| 6 — Approval+analytics+polish | 4-5 days |
| 7 — Local hardening | 3-5 days |
| **Total remaining** | **~2.5-3.5 weeks of focused work to production-ready locally** (voice deferred; deploy after) |

---

## 9. Open Questions

Items below carry an **owner** tag because they require human decisions (legal, business, brand) rather than code. They do not block the implementation phases but each blocks some part of the public-launch gate.

| # | Question | Owner | Blocks | Default if no decision |
|---|----------|-------|--------|------------------------|
| 1 | **Payment / monetization** — Stripe subscription? Per-course one-time? Free tier limits? | Operator (business) | Public commercial launch | Stubbed behind feature flag; free-only MVP. |
| 2 | **Content moderation** — approved designers publish without review, or admin reviews each course? | Operator (policy) | First public designer onboarding | No review post-approval (current plan). |
| 3 | **Data retention** — how long do we keep attempt history + analytics raw events? | Operator (legal — GDPR/CCPA) | First public learner signup outside test users | 12 months (provisional; revisit before launch). |
| 4 | **Offline mode** — required at launch? | Operator (product) | None — MVP-out-of-scope | No (assumed). |
| 5 | **iOS target** — launch date, or strictly post-Android? | Operator (product) | iOS app store submission | Post-Android (assumed). |
| 6 | **Terms/Privacy copy** — real legal text needed for `infra/landing/`. | Operator (legal) | Public landing page going live | Placeholder text remains until replaced. |
| 7 | **GitHub org** — personal account, new `lifestream-dynamics` org, or existing? Affects landing page link (`infra/landing/index.html`). | Operator (brand) | Repo split (ADR 0005) and public push | Placeholder slug remains; must resolve before split. |

These items are intentionally **not** scheduled in the phase timeline — they require operator action outside the codebase. Each PR that depends on one should reference this section and gate behind the decision.

---

## 10. References

- Flutter feed fork: https://github.com/FlutterWiz/flutter_video_feed
- Player packages: https://pub.dev/packages/video_player · https://pub.dev/packages/fvp · https://pub.dev/packages/media_kit
- Upload: https://github.com/tus/tusd · https://pub.dev/packages/tus_client_dart
- Storage: https://github.com/seaweedfs/seaweedfs
- Streaming: https://nginx.org/en/docs/http/ngx_http_secure_link_module.html · https://ffmpeg.org/ffmpeg-formats.html#hls-2 · https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices
- License: https://www.gnu.org/licenses/agpl-3.0.en.html
- Node.js 22 LTS: https://nodesource.com/blog/Node.js-v22-Long-Term-Support-LTS
- Prisma system requirements: https://www.prisma.io/docs/orm/reference/system-requirements
- BullMQ (Bull EOL 2026): https://docs.bullmq.io · https://pocketlantern.dev/briefs/bull-vs-bullmq-node-job-queue-performance-2026

---

## 11. Code Problem Register (CPR)

Tracked issues that warrant future attention. Reported, not fixed, by the /actualizar-todo grooming pass on 2026-04-20. Status values: OPEN, IN_PROGRESS, RESOLVED, WONTFIX, DEFERRED.

| ID | Category | Severity | Description | First seen | Status |
|----|----------|----------|-------------|------------|--------|
| CPR-001 | CI_CONFIG | CRITICAL | `.github/workflows/app-ci.yml` pinned `flutter-version: '3.35.x'` (lines 32 and 73) while `app/.fvmrc` pins `3.41.5`. Fixed in the grooming pass on 2026-04-20 — both lines now pin `3.41.5`. | 2026-04-20 | RESOLVED (2026-04-20) |
| CPR-002 | TEST_GAP | MINOR | Compose-dependent integration tests (`transcode-e2e`, `transcode-resilience`, `secure-link`, `health`) are excluded from `api-ci.yml` and only run locally. Accepted trade-off until the project moves to a CI runner that can host docker-compose; documented in CLAUDE.md §Phase awareness. | 2026-04-20 | DEFERRED |
| CPR-003 | DOC_GAP | MINOR | Video input-hardening work in flight (WIP commit `3e2a615` + follow-ups: `api/src/services/ffmpeg/input-policy.ts`, `poster.ts`, VP9 rejection, rotated-portrait handling, poster-key + failure-reason schema migration) is not yet reflected in the Phase 3 exit criteria below. Update Phase 3 once WIP lands. V1 slice landed; exit criteria updated above. | 2026-04-20 | RESOLVED 2026-04-23 |
| CPR-004 | FEATURE_DEFERRED | COSMETIC | Bull Board dashboard deferred as Phase 3 polish per CLAUDE.md §Phase awareness; non-blocking for Phase 3 completion. Prometheus `/metrics` endpoint (Slice G1) covers observability needs for MVP; Bull Board adds no blocking value. | 2026-04-20 | WONTFIX 2026-04-23 |
| CPR-005 | CONFIG_DRIFT | CRITICAL | CONFIG_DRIFT — `scripts/bootstrap-dev.sh:105` hard-codes `HLS_BASE_URL=http://10.0.2.2:80/hls` but `infra/.env` sets `NGINX_HOST_PORT=8090`. A fresh `make bootstrap` writes a broken HLS URL that breaks video playback on a clean checkout. Fix: interpolate `NGINX_HOST_PORT` from `infra/.env` into the sed replacement. | 2026-04-20 | RESOLVED 2026-04-26 — bootstrap reads `NGINX_HOST_PORT` from `infra/.env` (fallback 80) and interpolates into `HLS_BASE_URL`. Regression test: `scripts/tests/bootstrap-dev.bats`. |
| CPR-006 | OPEN_SOURCE_HYGIENE | MAJOR | `app/README.md` "Manual run" and "Test + analyze + build" blocks reference the private absolute path `/home/eric/flutter/bin/flutter` (and `dart`). This violates the project's open-source hygiene rule in CLAUDE.md ("Never commit internal paths (e.g. `/home/eric/...`)") and will leak once the monorepo splits. Replace with `fvm flutter` (roadmap calls for fvm) or a plain `flutter` assuming the operator has the pinned SDK on `PATH`. Left unchanged in the grooming pass — this needs a small call from the owner about which invocation style to standardise. Private paths removed from app/README.md. | 2026-04-20 | RESOLVED 2026-04-23 |

| CPR-007 | CONFIG_DRIFT | CRITICAL | `scripts/bootstrap-dev.sh:105` hard-codes `HLS_BASE_URL=http://10.0.2.2:80/hls` but `infra/.env` sets `NGINX_HOST_PORT=8090`. Breaks video playback on fresh checkout. Fix: read `NGINX_HOST_PORT` from written `infra/.env` and interpolate. | 2026-04-23 | RESOLVED 2026-04-26 — duplicate of CPR-005, resolved by the same change. |
| CPR-008 | DOC_GAP | MINOR | IMPLEMENTATION_PLAN.md §5 Phase 3 exit criteria did not mention input-policy or poster hardening from Slice V1. Fixed in this grooming pass. | 2026-04-23 | RESOLVED 2026-04-23 |
| CPR-009 | ROADMAP_DRIFT | MINOR | Slices G1–G3, H, V1, U1, P5–P9, D1–D2.1 shipped after the original Phase 7 scope. These represent deployment hardening and feature polish beyond the plan. IMPLEMENTATION_PLAN.md should add a Phase 8 (Deployment Hardening) section or reference a separate DEPLOYMENT_PLAN.md. | 2026-04-23 | RESOLVED 2026-04-26 — Phase 8 expanded with task list, exit criteria, and a "Phase 8 backlog" subsection enumerating deferred items. See §5 Phase 8. |
| CPR-010 | FEATURE_DEFERRED | COSMETIC | Bull Board dashboard (CPR-004) — marked WONTFIX. See CPR-004. | 2026-04-23 | WONTFIX 2026-04-23 |
| CPR-011 | TEST_GAP | MEDIUM | Compose-dependent integration tests (`transcode-e2e`, `transcode-resilience`, `secure-link`, `health`) remain excluded from CI. Slice G3 added new HMAC integration tests also excluded. CI cannot validate the full pipeline. Options: add docker-in-docker CI runner, or document these as a required pre-merge local gate. | 2026-04-23 | RESOLVED 2026-04-26 — chose option 2 (pre-merge local gate). `CONTRIBUTING.md` now lists the four suites with exact commands and a per-PR result-capture rule. Promoting to a nightly GHA workflow remains a Phase 8 backlog item if the local gate doesn't hold. |

Update this table on each grooming pass. Mark entries RESOLVED (with date) rather than removing them, so the history stays visible.
