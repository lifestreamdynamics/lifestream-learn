# Lifestream Learn — Implementation Plan

**Document owner:** Eric
**Last updated:** 2026-04-19
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

### Phase 2 — learn-api Scaffold

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

**Exit criteria:**
- `curl http://localhost:3011/health` returns 200 with all dependencies "ok".
- Signup → login → protected-route round-trip works end-to-end against local infra.
- Unit tests pass at ≥80% coverage on middleware and auth.
- Integration tests pass at ≥85% coverage against `learn_api_test` on accounting-postgres and a `learn:` prefix on accounting-redis.

---

### Phase 3 — Upload + Transcode Pipeline

**Goal:** A Course Designer (via curl/Postman for now) can upload a raw video, and the system produces a playable HLS ladder served behind signed URLs. Still no Flutter app.

**Tasks:**
1. `POST /api/videos` → creates `Video` row with `status=UPLOADING`, returns `{videoId, uploadUrl}` (tusd URL with pre-signed token)
2. tusd `pre-finish` hook → hits learn-api `/internal/hooks/upload-complete` → enqueues `learn:transcode` Bull job
3. `learn-transcode-worker` (separate process, `npm run worker:transcode:dev` in dev): pulls source from SeaweedFS, runs FFmpeg ladder (360/540/720/1080p CMAF fMP4), writes to `learn-vod/{videoId}/`, writes master playlist, updates DB `status=READY`, publishes `learn:video.ready` event (future analytics hook)
4. Failure path: retry with backoff (BullMQ built-in); after 3 fails, set `status=FAILED` + store error
5. `GET /api/videos/{id}/playback` → verify user has access (enrolled or owner) → generate HMAC-signed master playlist URL; tokens expire 2h
6. Nginx `secure_link` config validates HMAC on every request under `/hls/`
7. Shell tests via `shell-testing-workflow` skill for any bash plumbing (e.g. SeaweedFS bucket provisioning script)

**Exit criteria:**
- End-to-end: `curl` tus upload of a 90-second MP4 → within a few minutes locally, `GET /api/videos/{id}` shows `status=READY`
- `ffprobe` on produced master playlist shows 4 variant streams with correct bitrates
- `curl` to a signed master URL succeeds; same URL after expiry returns 403
- `curl` to a segment URL with tampered HMAC returns 403
- Transcode worker survives a simulated kill mid-job and resumes cleanly on restart without data corruption
- BullMQ dashboard (Bull Board, SSH-tunneled) shows completed/failed job history

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

### After Phase 7 — Deployment (separate work track)

Deployment is deliberately kept out of this plan. Once Phase 7 is green we pick a deploy strategy (self-hosted on the shared VPS, cloud, hybrid), write the relevant runbooks and automation, and schedule a closed beta. That track will include: TLS/domain/CDN decisions, process supervision, backup + restore drill, incident-response runbook, Google Play console setup, release-candidate sign-off.

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

Carry-overs that don't block Phase 2 but need to land before a deploy track opens:

1. **Payment / monetization**: Stripe-based subscription? Per-course one-time? Free tier limits? Stubbed behind a feature flag initially.
2. **Content moderation**: approved designers publish without review, or does admin review each course? (Current plan: no review post-approval — flag if that's wrong.)
3. **Data retention**: how long do we keep attempt history and analytics raw events? (GDPR / CCPA relevance before anything goes public.)
4. **Offline mode**: is "download course for offline playback" required? Currently assumed **no** for initial scope.
5. **iOS**: target launch date, or strictly post-Android?
6. **Terms/Privacy content**: real copy needed before anything goes public.
7. **GitHub org**: publish under personal account, a new `lifestream-dynamics` org, or an existing one? Affects brand and contribution UX.

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
