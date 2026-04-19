# Flutter App — Implementation Plan

**Owner:** Eric
**Created:** 2026-04-19
**Status:** Draft — ready for execution
**Spans:** Phase 4 → Phase 6 of `IMPLEMENTATION_PLAN.md`
**Companion to:** `IMPLEMENTATION_PLAN.md` (canonical phase spec); this plan is the *how*.

---

## Context

The backend pipeline (Phase 3) is wired end-to-end: API issues tusd upload coordinates, transcode worker produces a CMAF fMP4 HLS ladder, and `GET /api/videos/:id/playback` returns short-lived MD5 secure_link master URLs. There is no client yet — no learner can watch a video, no designer can author one. The Flutter app closes that gap and is the last big chunk of work before the project is "production-ready locally" (Phase 7) and a deploy track can open.

`app/` is **greenfield**: only `.gitignore` + `README.md`. Flutter 3.41.5 is installed at `/home/eric/flutter/bin/flutter` (Dart 3.11.3). No `pubspec.yaml`, no `lib/`, no fork pulled. `fvm` is not configured.

Phase 4 (read-only feed), Phase 5 (interactive cues), and Phase 6 (designer + analytics + polish) all live in the same Flutter binary, gated by role. The cue endpoints (`/api/cues`, `/api/attempts`, `/api/feed`, `/api/courses`, `/api/enrollments`, `/api/events`) are still 501 stubs on the backend and must be implemented in lockstep with the Phase 5/6 Flutter work.

This plan structures that work into self-contained sub-phases with exit criteria, identifies the parallel-subagent split points, and pins the API contract the client codes against (since the backend may evolve underneath us, freezing the contract per phase prevents flailing).

---

## API contract this plan codes against (snapshot 2026-04-19)

The following endpoints exist and are tested. Phase 4 of this plan only consumes endpoints in this section. Later phases that need new endpoints implement them on the backend first (Sub-phase 4.0 below).

### Auth
| Method | Path | Auth | Body | 2xx response |
|---|---|---|---|---|
| POST | `/api/auth/signup` | none | `{email, password (≥12 chars), displayName}` | 201 `{user, accessToken, refreshToken}` |
| POST | `/api/auth/login` | none | `{email, password}` | 200 `{user, accessToken, refreshToken}` |
| POST | `/api/auth/refresh` | none | `{refreshToken}` | 200 `{accessToken, refreshToken}` (rotation: old refresh invalidated) |
| GET | `/api/auth/me` | bearer | — | 200 `{id, email, role, displayName, createdAt}` |

JWT claims: access has `{sub, role, email, type:'access'}` (15m TTL); refresh has `{sub, type:'refresh', jti}` (30d TTL). Roles: `ADMIN | COURSE_DESIGNER | LEARNER`. Rate limits — signup 10/10min, login 5/5min, refresh 30/5min — return 429 with `{error:'RATE_LIMITED', message}` and `RateLimit-*` headers.

### Videos
| Method | Path | Auth | Body | 2xx response |
|---|---|---|---|---|
| POST | `/api/videos` | bearer + `ADMIN\|COURSE_DESIGNER` (owner/collaborator/admin of course) | `{courseId, title, orderIndex}` | 201 `{videoId, video, uploadUrl, uploadHeaders, sourceKey}` |
| GET | `/api/videos/:id` | bearer + access (admin/owner/collaborator/enrolled) | — | 200 `{id, courseId, title, orderIndex, status, durationMs, createdAt, updatedAt}` |
| GET | `/api/videos/:id/playback` | bearer + access + status===READY | — | 200 `{masterPlaylistUrl, expiresAt}` (URL is signed `?md5=...&expires=...`, ~2h TTL) |

### Health & docs
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/health` | none | `{status, dependencies, timestamp}` (200 ok / 503 degraded) |
| GET | `/health/liveness` | none | `{status:'ok'}` |
| GET | `/api/docs` | none (dev only) | Swagger UI |
| GET | `/api/docs.json` | none (dev only) | OpenAPI 3.0.3 JSON — feed to dart codegen if desired |

### Error envelope
`{ error: 'CODE', message: '...', details?: {...} }` — codes: `VALIDATION_ERROR | UNAUTHORIZED | FORBIDDEN | NOT_FOUND | CONFLICT | RATE_LIMITED | NOT_IMPLEMENTED | INTERNAL_ERROR`. The Dart HTTP client must decode every 4xx/5xx to this shape.

### Stubs (must be implemented before the Flutter feature that consumes them)
`/api/cues`, `/api/attempts`, `/api/voice-attempts` (501 forever), `/api/feed`, `/api/courses`, `/api/designer-applications`, `/api/events`. See Sub-phase 4.0.

### Non-obvious gotchas the Dart client must handle
1. **`Upload-Metadata` value is base64-no-padding.** `videoId <base64(videoId).replace(/=+$/,'')>` — `tus_client_dart` accepts a metadata map that it base64-encodes itself; verify the implementation strips padding, otherwise pre-encode and pass as raw header string. Reference: `api/src/controllers/videos.controller.ts:48-58`.
2. **Refresh rotation is mandatory.** Every `/api/auth/refresh` returns a *new* refresh token; the old one is unusable. The `dio` interceptor must persist both tokens atomically.
3. **Signed playback URLs must be passed verbatim to the player.** Don't strip query params, don't re-encode. `video_player` for Android delegates to ExoPlayer which handles HLS natively.
4. **Clock skew matters.** Signed URLs validate against nginx's wall clock; the device clock determines `expiresAt`. If the device clock is >60s off, the player will start fine but mid-stream segment requests can 410. Show a warning if `DateTime.now()` deviates significantly from the API response's `Date` header.
5. **Video access semantics:** admin sees everything; designer/collaborator sees their course's videos at any status; learner only sees status=READY videos in courses they're enrolled in.

---

## Phase structure

This plan splits Flutter work into four sub-phases. Each maps to a chunk of `IMPLEMENTATION_PLAN.md`:

| Sub-phase | Maps to | Goal | Estimate |
|---|---|---|---|
| **4.0** Backend cue/attempt/course/feed APIs | §Phase 5 backend tasks (Subagent A) | Replace 501 stubs with real endpoints + tests | 2-3 days |
| **4.1** Flutter init + auth + HTTP plumbing | §Phase 4 tasks 1-7 + part of §6 | Greenfield Flutter project; auth flow; Dio with refresh interceptor; routing scaffold | 2-3 days |
| **4.2** Read-only feed | §Phase 4 tasks 5-10 | Vertical feed, video player, ABR, integration test | 3-4 days |
| **4.3** Interactive cue engine | §Phase 5 task list (Subagent B + C) | MCQ / Blanks / Matching widgets; designer authoring; cue-trigger timing | 5-7 days |
| **4.4** Designer approval + analytics + polish | §Phase 6 | Application flow, enrollment, analytics batching, store-ready polish | 4-5 days |

**Total: ~16-22 days of focused work.** Matches the high-level estimate in `IMPLEMENTATION_PLAN.md` §8 (Phase 4 + 5 + 6 = 14-19 days), with the extra days representing 4.0's backend work that the headline plan grouped into Phase 5.

Sub-phases 4.0 and 4.1 can run in **parallel** (different repos / concerns). 4.2 blocks on both. 4.3 blocks on 4.2. 4.4 blocks on 4.3.

---

## Sub-phase 4.0 — Backend cue / attempt / course / feed APIs

**Why first:** Phase 5 of `IMPLEMENTATION_PLAN.md` explicitly calls out a parallel subagent split where Subagent A implements backend cue CRUD + attempts while Subagent B builds the Flutter cue widgets. To keep that parallelism clean, the *whole* set of stubs the Flutter app needs (course CRUD, enrollments, feed, cue CRUD, attempt grading, designer applications, analytics events) lands first as one focused backend push. The Flutter app then targets a stable, real API.

**Endpoints to implement (per `IMPLEMENTATION_PLAN.md` §4 data model):**

### Courses
- `POST /api/courses` (COURSE_DESIGNER|ADMIN) — `{title, slug?, description, coverImageUrl?}` → 201 Course; auto-set ownerId=req.user.id; slug auto-generated if absent.
- `GET /api/courses` — paginated list of published courses (any authenticated user); query `?cursor=&limit=&owned=true|false&enrolled=true|false`.
- `GET /api/courses/:id` — Course with videos summary; 403 if not enrolled / not owner / not collaborator / not admin AND not published.
- `PATCH /api/courses/:id` (owner|admin) — partial update; cannot transfer ownership.
- `POST /api/courses/:id/publish` (owner|admin) — flip `published=true`; requires ≥1 READY video.
- `POST /api/courses/:id/collaborators` (owner|admin) — `{userId}` → 201 CourseCollaborator.

### Enrollments
- `POST /api/enrollments` (any authenticated) — `{courseId}` → 201 Enrollment; only published courses; idempotent on `(userId, courseId)`.
- `GET /api/enrollments` — current user's enrollments with last-watched position.
- `PATCH /api/enrollments/:courseId/progress` — `{lastVideoId, lastPosMs}` → 204; called from feed.

### Cues
- `POST /api/videos/:id/cues` (owner|collaborator|admin of course) — `{atMs, pause, type, payload, orderIndex}`; payload validated by Zod discriminated union per `type` (MCQ | MATCHING | BLANKS); reject VOICE with 501 (per ADR 0004).
- `GET /api/videos/:id/cues` — ordered cues for any user with access to the video.
- `PATCH /api/cues/:id` — same auth + same Zod validation.
- `DELETE /api/cues/:id`.

### Attempts
- `POST /api/attempts` (any authenticated) — `{cueId, response}`; **server-side grade**; response shape varies per cue type. Returns `{correct, scoreJson, explanation?}`. Stores Attempt row.
- `GET /api/attempts?videoId=&userId=` (own attempts only unless admin).

### Feed
- `GET /api/feed?cursor=&limit=` — paginated list of videos for the current learner: from enrolled courses, status=READY, ordered by enrollment recency + orderIndex. Each entry includes `{video, course (id+title+coverImageUrl), cueCount, hasAttempted}`.

### Designer applications
- `POST /api/designer-applications` (LEARNER role only) — `{note?}` → 201; idempotent per user.
- `GET /api/admin/designer-applications?status=PENDING` (ADMIN) — list.
- `PATCH /api/admin/designer-applications/:id` (ADMIN) — `{status: APPROVED|REJECTED, reviewerNote?}`; on APPROVED, promote user role to COURSE_DESIGNER atomically.

### Analytics events
- `POST /api/events` (any authenticated) — `[{eventType, occurredAt, videoId?, cueId?, payload?}]` (batch, max 100); fast-path insert; never block the request on derived analytics. `occurredAt` is client-sourced; server stamps `receivedAt`.

**Cross-cutting:**
- All inputs validated with Zod schemas in `src/validators/`.
- Grading logic (`src/services/grading/`) is pure functions per cue type; **≥95% unit coverage** per CONTRIBUTING.md (security-sensitive — wrong correct/incorrect leaks the answer).
- All write endpoints idempotent where the data model allows.
- All endpoints documented with `@openapi` JSDoc so `/api/docs.json` stays current.
- Replace 501 stubs in `src/routes/stubs/` by mounting the new routers; delete the corresponding stub file.

**Tests:**
- Unit: validators + grading + each service method (mocked Prisma). Cue grading hits ≥95%.
- Integration: full happy-path per resource against `learn_api_test` Postgres + Redis; 403/401/404/409 paths covered.

**Exit criteria:**
- All listed endpoints return real data, not 501.
- `npm run validate` clean; `npm run test:integration` clean; coverage thresholds (80/85/95) met.
- `/api/docs.json` lists all new endpoints with request/response schemas.
- Manual smoke: create course → upload video (Phase 3 flow) → author MCQ + Blanks + Matching cues → another user enrolls → posts attempts → grading correct.

**Parallel split:** four agents — (a) courses + enrollments, (b) cues + grading, (c) attempts + feed, (d) designer-applications + analytics. Each owns its routes/controllers/services/validators/tests. Coordinate on shared Zod schemas in `src/validators/cue-payloads.ts`.

---

## Sub-phase 4.1 — Flutter init + auth + HTTP plumbing

**Goal:** A Flutter app that can sign up, log in, refresh tokens, hit `/api/auth/me`, and navigate between role-gated routes. No video, no feed yet — the foundation the rest builds on.

**Tasks:**

1. **Decide: fork-or-init.** The plan says fork `FlutterWiz/flutter_video_feed` (MIT). Two viable approaches:
   - **(a) Clone-as-template:** `git clone https://github.com/FlutterWiz/flutter_video_feed app-vendor && cp -r app-vendor/* app/ && rm -rf app-vendor/.git` — preserves the LRU controller cache + BLoC scaffolding intact. Update `pubspec.yaml` name to `lifestream_learn_app`, license to AGPL-3.0, attribution preserved in NOTICE file.
   - **(b) Fresh `flutter create`** + manually port the controller cache + feed BLoC patterns we need.
   - **Recommend (a)** because the LRU cache + ±1 preload is non-trivial to rewrite and was the explicit reason for picking the fork (`IMPLEMENTATION_PLAN.md` §2). Carries an attribution obligation (MIT requires preserving copyright); ship the upstream LICENSE alongside ours under `app/THIRD_PARTY_LICENSES.md`.

2. **fvm + version pin.** `cd app && fvm install 3.41.5 && fvm use 3.41.5` → commits `.fvm/fvm_config.json` and `.fvmrc`. Add `fvm` install instructions to `app/README.md`.

3. **Pin core dependencies in `pubspec.yaml`:**
   - `flutter_bloc` (state) — already in upstream
   - `dio` (HTTP) — replaces upstream's HTTP client to get refresh-rotation interceptor
   - `dio_cache_interceptor` (optional, for course list caching)
   - `flutter_secure_storage` (token persistence)
   - `tus_client_dart` (resumable upload)
   - `video_player` + `fvp` (player + backend registrar)
   - `go_router` (typed routing) — replaces whatever the upstream uses if it's `Navigator 1.0`
   - `freezed` + `json_serializable` (immutable DTOs from API responses)
   - `intl` (date formatting)
   - Dev: `flutter_lints`, `build_runner`, `mockito` or `mocktail`

4. **Project layout** (matches `app/README.md`):
   ```
   lib/
     main.dart
     core/
       http/                # Dio client + interceptors (auth, refresh, error envelope)
       auth/                # AuthBloc, token storage, role guard
       routing/             # GoRouter config + role-gated redirect
       theme/               # Material3 theme
       errors/              # ApiException class mirroring the error envelope
     features/
       auth/                # Signup + login screens
       feed/                # Phase 4.2
       player/              # Phase 4.2 + 4.3 (cue engine)
       cues/                # Phase 4.3 widgets
       courses/             # Phase 4.2 (browse) + 4.4 (enroll)
       designer/            # Phase 4.3 (cue authoring) + 4.4 (course mgmt)
       admin/               # Phase 4.4 (designer-applications review)
     data/
       api/                 # Generated or hand-written request/response DTOs
       models/              # Domain models (PublicVideo, Cue, Course, etc.)
       repositories/        # One per resource; thin wrappers over the API client
   ```

5. **Auth flow implementation:**
   - `AuthBloc` states: `Initial | Authenticating | Authenticated(user, accessToken) | Unauthenticated | Refreshing`.
   - `TokenStore` over `flutter_secure_storage` — persists `{accessToken, refreshToken}` atomically with `Future<void> save(AuthTokens)` writing both keys in the same await. On read, parse JWT to extract role + expiry.
   - `Dio` interceptors:
     - `AuthInterceptor` adds `Authorization: Bearer <accessToken>` to every request, except `/api/auth/signup|login|refresh` and `/health*`.
     - `RefreshInterceptor` catches 401, single-flight `/api/auth/refresh`, retries the original request once. Multiple concurrent 401s share the same in-flight refresh future. On refresh failure → `AuthBloc.add(LoggedOut)`.
     - `ErrorEnvelopeInterceptor` maps 4xx/5xx to `ApiException(code, message, details, statusCode)`.
   - Signup screen: email + password (live-validate ≥12 chars + valid email per the API's Zod) + displayName. Submit → `AuthBloc.add(SignupRequested)` → on success navigate to feed.
   - Login screen: email + password. Submit → same pattern. Error mapping: `RATE_LIMITED` → "too many attempts, try in 5 min"; `UNAUTHORIZED` → "invalid email or password" (don't disambiguate, matches backend's anti-enumeration design at `auth.service.ts`).

6. **Routing:**
   - `go_router` with redirect: unauthenticated → `/login`; authenticated `LEARNER` lands on `/feed`; `COURSE_DESIGNER` lands on `/designer`; `ADMIN` lands on `/admin`.
   - Role guards on routes via `redirect:`. A `LEARNER` hitting `/designer` → `/feed`.

7. **Health probe.** On app start, ping `GET /health` and surface a banner if `status==='degraded'` or non-200. Don't block UI on failure.

8. **Dev/release config:**
   - `--dart-define=API_BASE_URL=http://10.0.2.2:8090` for Android emulator (10.0.2.2 → host loopback). For physical device on Wi-Fi: `--dart-define=API_BASE_URL=http://<dev-machine-LAN-ip>:8090`.
   - `flutter_dotenv` *not* used — secrets stay out of the binary; only the API base URL is configurable, via `--dart-define` (same shape as `.env`).

**Tests:**
- Unit: `TokenStore` round-trip; `AuthInterceptor` adds header; `RefreshInterceptor` single-flight under 5 concurrent 401s; `ErrorEnvelopeInterceptor` decodes the canonical envelope and bubbles `ApiException`.
- Widget: signup form validates inline; login form shows the right error per `ApiException.code`.
- Integration (with real local API): boot → signup → see authenticated landing screen.

**Exit criteria:**
- `flutter analyze` clean; `flutter test` clean.
- `flutter run` on the Android emulator: signup → log out → log in → kill app → reopen → still authenticated (token persisted).
- A 15-min sit on the login screen, then a request: refresh fires once and succeeds (test by setting `JWT_ACCESS_TTL=30s` in `api/.env.local` for this exercise).
- `flutter build apk --release` succeeds.

---

## Sub-phase 4.2 — Read-only feed

**Goal:** Phase 4 of `IMPLEMENTATION_PLAN.md` is met. A learner scrolls a vertical feed of seeded videos and watches them with ABR. No interactivity yet.

**Prereq:** 4.0 done so `/api/feed` and `/api/courses/:id` and `/api/enrollments` are real.

**Tasks:**

1. **Repositories** (`lib/data/repositories/`):
   - `FeedRepository`: `Stream<FeedPage> watchFeed({String? cursor})` over Dio; cursor pagination.
   - `VideoRepository`: `Future<PublicVideo> get(id)`, `Future<PlaybackUrl> playback(id)`. Caches `playback` for the URL's TTL minus 5 min (so we don't re-sign for every scroll).
   - `CourseRepository`: `Future<List<Course>> mine()`, `Future<Course> get(id)`.

2. **Feed BLoC + screen.** Reuse upstream's `PageView` + LRU `VideoControllerCache`. Adapt:
   - State: `FeedInitial | FeedLoading | FeedLoaded(videos, cursor, hasMore) | FeedError(apiException)`.
   - `PageView.builder` with `onPageChanged` triggering preload of pages `±1` (the cache handles disposal of `±2`).
   - Empty state: "Enroll in a course to start your feed." → CTA → `/courses`.
   - Pull-to-refresh refetches from cursor=null.

3. **Player widget.** `LearnVideoPlayer`:
   - Takes a `PublicVideo` + signed `playbackUrl`.
   - `VideoPlayerController.networkUrl(playbackUrl)` (HLS, ExoPlayer-backed via fvp on Android).
   - Auto-play on visible; pause on scroll-away; dispose via the controller cache.
   - Tap to play/pause toggle; double-tap seeks ±10s; long-press shows scrubber.
   - On `mediaInformationLoaded` event, persist `lastVideoId` + `lastPosMs` every 5s via `EnrollmentRepository.updateProgress`.

4. **Course browse screen** (`/courses`): grid of published courses; tap → course detail with video list; "Enroll" button → `POST /api/enrollments`; on success navigate to feed.

5. **Resume-where-left-off.** On feed load, if the current `Enrollment.lastVideoId` is in the page, scroll to it and seek to `lastPosMs`.

6. **Network resilience.**
   - Dio retry interceptor (3 attempts, exponential backoff) on idempotent reads only.
   - On `ApiException(code:'UNAUTHORIZED')` after refresh failure → bounce to login.
   - Player buffering UX: show a spinner only after 1s of buffering (avoid flash on fast networks).
   - On `404` from `/playback`: show "video unavailable" inline rather than crashing the page.

7. **Logging hygiene.** Never log `accessToken`, `refreshToken`, signed playback URLs, or request bodies in production builds. Use a `kDebugMode`-gated logger.

**Tests:**
- Unit: `FeedBloc` state transitions; `VideoRepository.playback` cache invalidates after TTL.
- Widget: feed renders ≥3 mocked videos; scroll triggers preload; tap-to-pause toggles correctly.
- Integration: against local API with 5 seeded videos, scroll the feed to the end and back; verify last-watched persists across restart.

**Exit criteria** (per `IMPLEMENTATION_PLAN.md` §Phase 4):
- APK installs on a physical Android 10+ device.
- Signup + login work against local API.
- Feed loads ≥5 seeded videos; each plays immediately on view.
- Swipe up advances with no visible buffer gap on a good connection.
- Network throttled to 3G (Android emulator network shaping): ABR drops to 360p within ~10s; no stalls >3s.
- No JWT or playback URL leaks in `adb logcat`.
- Refresh rotation tested by expiring an access token mid-session.

---

## Sub-phase 4.3 — Interactive cue engine

**Goal:** Phase 5 of `IMPLEMENTATION_PLAN.md` is met. Learners see and complete MCQ, Blanks, Matching exercises mid-video; designers author them.

**Prereq:** 4.0 done; 4.2 done.

This sub-phase is the largest and naturally splits into **three parallel agents** (mirrors the §Phase 5 prescribed split):

### Agent B — Cue trigger engine + widgets (learner-facing)

1. **`CueScheduler`:** wraps `VideoPlayerController`. Polls `controller.value.position` every 50ms. Maintains the next upcoming cue. When `position >= cue.atMs - 200ms`, calls `await controller.pause()` then `await controller.seekTo(Duration(ms: cue.atMs))` (snap to exact cue moment), then surfaces the cue to the UI via a `ValueNotifier<Cue?>`.
2. **`CueOverlay` (full-screen modal):** dispatches on `cue.type` to:
   - **`McqCueWidget`:** question + 2-4 choices (single-select); submit → `POST /api/attempts` → render correct/incorrect + optional explanation → "Continue" resumes video.
   - **`BlanksCueWidget`:** template parsed to `Text` + `TextField` segments per `{{N}}` placeholder; per-blank validation; submit → grade server-side; show diff.
   - **`MatchingCueWidget`:** two columns; drag-to-match or tap-to-pair UX; visual line connectors; submit → grade.
3. **Background handling:** if user backgrounds the app mid-cue, `WidgetsBindingObserver` saves the current cue + paused state. On resume, restore the overlay.
4. **Skipped-cue handling:** if `cue.pause === false`, render overlay non-modally (semitransparent overlay, video keeps playing); attempt submission still grades server-side but doesn't block.
5. **A11y:** every interactive element has a semantics label; live region announces correct/incorrect; minimum tap target 48x48dp.

### Agent C — Designer cue authoring (designer-facing)

1. **`DesignerHome`** (`/designer`): list of own courses + create-course CTA.
2. **`CourseEditor`:** course metadata form + video list + upload button (uses `tus_client_dart` against `POST /api/videos` then the returned `uploadUrl` + headers).
3. **`VideoEditor`:**
   - Timeline scrubber bound to `VideoPlayerController.value.position`.
   - "Add cue at current time" → modal form picker → cue-type-specific form:
     - MCQ: question text, 2-4 choices, mark correct, optional explanation.
     - Blanks: sentence template (with `{{0}}`, `{{1}}` placeholders), accept-list per blank, case-sensitive toggle.
     - Matching: paired list editor (left items + right items + valid pairings).
   - Save draft locally (sembast or shared_preferences); "Publish" sends to `POST /api/videos/:id/cues` (or `PATCH` if editing).
   - Cue list under timeline, grouped by `atMs`; tap to seek + edit.
4. **`CourseList` admin actions:** add collaborator (lookup by email), remove, transfer ownership (admin only).
5. **Validation parity:** every cue form validates with the same Zod-equivalent rules client-side (port the schema or use `freezed` unions); matches the backend so submission errors are rare.

### Agent D (or shared with B) — Wiring + tests

1. **End-to-end manual test fixtures:** seed script `api/scripts/mkcourse.ts` (already present) extended to support MCQ + Blanks + Matching cue types so the integration test path is reproducible.
2. **Integration test (Flutter `integration_test/`):** boot app → log in as designer → create course → upload fixture video → wait for status=READY (poll) → author one cue per type → publish → log out → log in as learner → enroll → play → verify each cue triggers within 100ms of `atMs` and grading flips a known-correct answer to "correct".
3. **Pre-flight checks:** if a video has cues at `atMs > durationMs`, surface a designer warning. If a cue payload fails client-side validation, the form blocks submission with an inline error.

**Exit criteria** (per `IMPLEMENTATION_PLAN.md` §Phase 5):
- All three cue types pass end-to-end manual test on-device: video pauses at correct timestamp (±100ms), overlay renders, submission scores correctly, video resumes.
- Server-side grading matches client expectations in 100% of unit test cases (parameterized per cue type).
- Designer can author a 5-cue video via the app without curl.
- Attempting to write cues without `COURSE_DESIGNER` role returns 403.
- `plan-validation-and-review` skill shows no dead/duplicate code.

---

## Sub-phase 4.4 — Designer approval + analytics + polish

**Goal:** Phase 6 of `IMPLEMENTATION_PLAN.md` is met. Admins approve designer applications; learners track progress; analytics flow.

**Prereq:** 4.3 done.

### Tasks

1. **Designer application flow** (any LEARNER):
   - Settings → "Become a Course Designer" → opens form with optional note → `POST /api/designer-applications` → confirmation screen.
   - Show pending state on subsequent visits until reviewed.

2. **Admin review screen** (`/admin/designer-applications`):
   - List of `status=PENDING` applications with applicant info + note.
   - Approve / Reject buttons → `PATCH /api/admin/designer-applications/:id`.
   - On approve, the user's role becomes `COURSE_DESIGNER` (backend handles atomically); next time they log in or refresh `/api/auth/me`, `/designer` becomes accessible.

3. **Course discovery + enrollment polish:**
   - "Browse" tab = published courses, search by title.
   - "My Courses" tab = enrolled courses with completion %.
   - Per-course screen: video list + completion check per video + "Continue from where you left off" button.

4. **Analytics batching:**
   - `AnalyticsBuffer` collects events: `video_view`, `video_complete`, `cue_shown`, `cue_answered`, `session_start`, `session_end`. Each carries `{eventType, occurredAt: DateTime.now().toIso8601String(), videoId?, cueId?, payload?}`.
   - Flush triggers: every 30s, on app pause, on buffer ≥50 events.
   - Persistent buffer (sembast) survives app kill / offline; flush on next online.
   - `POST /api/events` with the batch (max 100 per call). On 4xx, drop the batch (don't infinite-retry malformed events). On 5xx, retry with backoff up to 5min.
   - **Privacy:** never include personal text content (e.g., learner's free-text answers) — only structural data (`{cueType, correct, durationMs}`).

5. **Admin analytics surface:** simple per-course screen — `GET /api/admin/analytics/courses/:id` — shows views, completion rate, avg cue accuracy. (Can be a single SQL view on the backend; no need for a dashboard library.)

6. **App polish:**
   - Material3 theme with brand colors (placeholder palette, designer to fill).
   - Splash screen + adaptive launcher icon (use `flutter_launcher_icons` from a 1024x1024 PNG; iOS deferred).
   - Error screens: friendly text, retry button, never expose stack traces.
   - In-app "About" with links to `/terms` and `/privacy` (rendered from API or bundled HTML; matches the landing page's terms.html).
   - Empty states for every list screen.
   - Loading states use `Skeletonizer` or a single shimmer pattern across the app.

**Tests:**
- Unit: `AnalyticsBuffer` flush logic (30s tick, app-pause, capacity); persistence round-trip; backoff caps at 5min.
- Widget: designer-application form submits; admin review approves and updates list.
- Integration: full e2e (already specified in `IMPLEMENTATION_PLAN.md` §Phase 6 exit criteria).

**Exit criteria** (per `IMPLEMENTATION_PLAN.md` §Phase 6):
- Full e2e: new user → applies → admin approves → creates course → uploads video → authors cues → publishes → another learner enrolls → completes video → analytics show.
- Analytics batching tolerates 30 min offline without event loss.
- App passes Android Studio "App Inspection" with no leaked resources.
- Release APK installs cleanly on a fresh Android 10+ device.

---

## Cross-cutting concerns

### Security
- Tokens **only** in `flutter_secure_storage` (Android: encrypted SharedPreferences). Never in app docs dir, never in logs.
- Signed playback URLs treated as secrets in logs (redacted before logging URL).
- `targetSdkVersion` ≥ 34 (current Android requirement); cleartext HTTP only allowed in dev (`network_security_config.xml` per build flavor).
- `screenshotsEnabled=false` on the cue overlay screens (FLAG_SECURE) to prevent answer leakage in screenshot history.

### Build flavors
- `dev` — `API_BASE_URL=http://10.0.2.2:8090`, cleartext HTTP allowed, debug logging on.
- `prod` — `API_BASE_URL=https://...` (set at build time), HTTPS only, all debug logs stripped.
- Keep `ios/` directory unconfigured but not deleted (per `app/README.md` "deferred").

### CI (out of scope for this plan but flagged)
- A future Phase-7-adjacent task should run `flutter analyze`, `flutter test`, and a `flutter build apk` on PRs touching `app/`. The pre-existing `cicd-bootstrapping` skill in CLAUDE.md can produce the GitHub Actions workflow when we get to it.

### License hygiene
- `app/THIRD_PARTY_LICENSES.md` lists upstream MIT (FlutterWiz/flutter_video_feed) + every transitive dependency's license.
- `app/LICENSE` symlinks or duplicates root AGPL-3.0 since the published Flutter repo (`lifestream-learn-app`) ships separately.

### Test fixtures
- The Phase 3 test fixture (`api/tests/fixtures/sample-3s.mp4`) doubles as the Flutter integration test fixture. For cue-engine timing tests, add a 30s fixture with predictable scene cuts (`api/tests/fixtures/sample-30s.mp4`) so `atMs` assertions are stable.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Upstream `FlutterWiz/flutter_video_feed` API differs from the README description | Sub-phase 4.1 task 1 reads the upstream code first; if the BLoC shape is incompatible, fall back to fresh `flutter create` + manual port (estimate +2 days) |
| `tus_client_dart` doesn't strip base64 padding from `Upload-Metadata` | Verify in 4.1; fallback is to set `Upload-Metadata` as a raw header instead of using the metadata map |
| `video_player` cue-trigger jitter exceeds 100ms on low-end Android | Switch to `media_kit` (mentioned in `IMPLEMENTATION_PLAN.md` §2 as the upgrade path); estimate +3 days |
| Server-side grading diverges from client expectations | 4.0 publishes Zod schemas; 4.3 ports them to `freezed` unions in Dart with a one-shot generator script that watches for drift |
| Refresh token race conditions cause double-logout | Single-flight refresh inside `RefreshInterceptor`; widget tests in 4.1 cover concurrent 401 path |
| Clock skew breaks signed-URL playback | App pings `/health` and compares server `Date` header to `DateTime.now()`; warns if Δ > 60s |
| AGPL-3.0 vs Google Play store policy | Google Play accepts AGPL apps; the AGPL "network use" clause means we publish source for any backend changes (already our intent); no Play-store-blocking issue |

---

## Verification (full app, after 4.4)

```bash
# Backend up
cd infra && docker compose up -d
cd ../api && npm run dev   # terminal 1
cd ../api && npm run worker:transcode:dev   # terminal 2

# App boot on emulator
cd ../app && fvm flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8090 -d emulator-5554

# Manual e2e checklist (mirrors Phase 6 exit criteria)
# 1. Sign up as user A → role LEARNER
# 2. Apply to be a designer → log out
# 3. Sign up as user B → promote to ADMIN via prisma seed → log in → /admin → approve A
# 4. Log in as A (now COURSE_DESIGNER) → /designer → create course "Spanish 101"
# 5. Upload api/tests/fixtures/sample-30s.mp4 → wait status=READY
# 6. Author 1 MCQ + 1 Blanks + 1 Matching cue → Publish
# 7. Sign up as user C → /courses → enroll → play video → complete all cues
# 8. As B (admin), GET /api/admin/analytics/courses/:id → see view + completion + accuracy
```

Then `flutter build apk --release`, install on a real device, verify the same flow on a clean install.

---

## Critical files (quick reference)

| File / dir | Sub-phase | Role |
|---|---|---|
| `api/src/routes/stubs/*` | 4.0 | Replace with real routers; delete stubs |
| `api/src/services/grading/` | 4.0 | New: pure grading per cue type (≥95% coverage) |
| `api/src/validators/cue-payloads.ts` | 4.0 | New: Zod discriminated unions for MCQ/MATCHING/BLANKS |
| `api/scripts/mkcourse.ts` | 4.0 | Extend to seed cues for the integration fixture |
| `app/pubspec.yaml` | 4.1 | Pin Flutter 3.41.5 + dependency set above |
| `app/lib/core/http/dio_client.dart` | 4.1 | Dio + 3 interceptors (auth/refresh/error envelope) |
| `app/lib/core/auth/auth_bloc.dart` | 4.1 | AuthBloc state machine |
| `app/lib/core/routing/app_router.dart` | 4.1 | go_router with role-gated redirect |
| `app/lib/data/repositories/feed_repository.dart` | 4.2 | Cursor-paginated feed |
| `app/lib/features/player/learn_video_player.dart` | 4.2 + 4.3 | Player + scheduler integration |
| `app/lib/features/player/cue_scheduler.dart` | 4.3 | 50ms polling, pause-at-cue logic |
| `app/lib/features/cues/{mcq,blanks,matching}_cue_widget.dart` | 4.3 | Per-type widgets |
| `app/lib/features/designer/video_editor.dart` | 4.3 | Timeline + cue authoring |
| `app/lib/features/admin/designer_applications.dart` | 4.4 | Admin review |
| `app/lib/data/repositories/analytics_repository.dart` | 4.4 | AnalyticsBuffer + flush |
| `app/integration_test/full_journey_test.dart` | 4.3 + 4.4 | The big e2e test |
| `app/THIRD_PARTY_LICENSES.md` | 4.1 | MIT attribution for upstream + deps |
