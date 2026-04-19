# Flutter App — Executable Roadmap

**Owner:** Eric
**Created:** 2026-04-19
**Status:** Active — replaces the aspirational plan in `flutter-app.md`
**Supersedes:** `flutter-app.md` (kept for reference on the API contract + risks sections)

---

## Why this plan exists

The earlier `flutter-app.md` treated the work as one 16-22 day push through IMPLEMENTATION_PLAN.md Phases 4-6. Attempting to execute it revealed three structural problems:

1. **Emulator-blocked verification.** Past the initial Flutter scaffold, every phase ends at "works on a physical Android device." Claude Code cannot launch an emulator from its sandbox, which means most slices would be "written, untested" — a quality mode the project's CLAUDE.md explicitly rejects.
2. **Fork-as-base carries heavy research debt.** Cloning `FlutterWiz/flutter_video_feed` wholesale means spending days understanding *their* BLoC shape, routing, and dependencies before our code starts. The value we actually wanted from that repo was two specific patterns (LRU controller cache, ±1 preload) — the rest is noise we'd carry forever.
3. **Phase boundaries don't match verification boundaries.** IMPLEMENTATION_PLAN.md phases are product milestones; this roadmap's slices are **verification milestones** — each ends at something that can be proven working, so forward progress isn't gated on device access.

---

## Guiding principles

1. **Reference the fork, don't adopt it.** We clone `FlutterWiz/flutter_video_feed` to `/tmp/flutter_video_feed-ref/` (never into `app/`), read the LRU cache (`VideoCacheManager` or equivalent) and the feed BLoC shape, then write our own lean implementations. No attribution debt. No upstream-cruft maintenance burden.
2. **Every slice ends at a provable state.** Either automated (`npm test`, `flutter analyze`, `flutter test`) or CLI-reproducible (`curl | jq` against a running stack). "Works on device" slices package a clean APK and leave device verification to you.
3. **Backend ships ahead of UI.** Every API endpoint the Flutter app consumes is already wired + tested before the Flutter code for that feature exists. Never a 501 between client and server.
4. **Slices are independently mergeable.** Each slice is a commit or two; a slice can be reverted without cascading breakage. No giant PRs.
5. **Clear quality marker in each commit message.** `✓ verified` vs `✎ compiled-and-analyzed-only (device test needed)`. No ambiguity about what "done" means.

---

## Slice catalog

Six slices. Hard execution order; each depends on the previous. Estimated effort is *Claude-working-time*, not elapsed days.

| # | Slice | Verification boundary | Est. effort |
|---|---|---|---|
| **A** | Backend cue grading + attempts + cue CRUD | Unit (≥95% grading) + integration against real Postgres/Redis | 4-6 hr |
| **B** | Backend courses + enrollments + feed + designer-apps + events | Integration against real Postgres | 4-6 hr |
| **C** | Flutter scaffold + Dio + Auth + token refresh | `flutter analyze` + `flutter test` + `flutter build apk` | 3-4 hr |
| **D** | Flutter feed + player (no cues) | `flutter analyze` + `flutter test` + APK installs | 3-4 hr |
| **E** | Flutter cue engine + designer authoring | `flutter analyze` + `flutter test` + APK installs | 4-6 hr |
| **F** | Flutter admin + analytics + polish | `flutter analyze` + `flutter test` + APK installs | 3-4 hr |

**Total: ~21-30 hours of Claude working time.** Not compressible — complexity is irreducible.

Slices A and B are verification-complete in this environment (I can run tests). Slices C-F produce buildable APKs with green static analysis and unit/widget tests; **the final "works on-device" verification is yours to drive**, and I'll provide a one-page manual-test checklist per slice.

---

## Slice A — Backend cue grading + attempts + cue CRUD

**Why first:** Cue grading is the most security-sensitive code in the app (CLAUDE.md: "≥95% unit coverage — it's security-sensitive, a wrong correct/incorrect leaks the answer"). Doing it first, in isolation, keeps the grading logic pure and testable without any coupling to routing, auth, or the rest of the Phase 5 surface. The attempt/cue CRUD endpoints then compose over that grading core.

### Deliverables

1. **`src/services/grading/`** — pure functions, one per cue type, no I/O:
   - `gradeMcq({choices, answerIndex, explanation?}, {choiceIndex}) → {correct, scoreJson, explanation?}`
   - `gradeBlanks({blanks}, {answers}) → {correct, scoreJson: {perBlank: boolean[]}, explanation?}` — case-insensitive by default, whitespace-trimmed, per-blank accept-list; all blanks must match.
   - `gradeMatching({pairs}, {userPairs}) → {correct, scoreJson: {correctPairs, totalPairs}, explanation?}` — exact set match.
   - `gradeVoice` throws `NotImplementedError` — schema only (ADR 0004).
   - Top-level `grade(cue, response)` dispatches on `cue.type`.

2. **`src/validators/cue-payloads.ts`** — Zod discriminated union exactly matching `IMPLEMENTATION_PLAN.md` §4:
   - `mcqPayloadSchema`: `{question, choices: [str,str,str?,str?], answerIndex: 0-3, explanation?}`
   - `blanksPayloadSchema`: `{sentenceTemplate, blanks: [{accept: str[], caseSensitive?: bool}]}`
   - `matchingPayloadSchema`: `{prompt, left: str[], right: str[], pairs: [[leftIdx, rightIdx], ...]}`
   - `cuePayloadSchema` = discriminated union keyed on `type`.
   - Response schemas keyed per type (input shape for `POST /api/attempts`).

3. **`src/services/cue.service.ts`** — CRUD + auth:
   - `createCue(videoId, userId, role, input)` — owner/collaborator/admin; validates payload against type; computes `orderIndex` by default (max+1 unless supplied).
   - `listCuesForVideo(videoId, userId, role)` — access check same as `canAccessVideo`; ordered by `atMs`.
   - `updateCue(cueId, userId, role, patch)`.
   - `deleteCue(cueId, userId, role)`.

4. **`src/services/attempt.service.ts`**:
   - `submitAttempt(cueId, userId, responseInput)` — loads cue, validates response shape matches cue type, calls `grade()`, persists `Attempt`. Returns the grading result to the client.
   - `listOwnAttempts(userId, videoId?)` — for designer/admin analytics later; learners see their own.

5. **`src/controllers/cues.controller.ts`** — thin HTTP shim over service; OpenAPI JSDoc per endpoint.

6. **`src/controllers/attempts.controller.ts`** — same.

7. **Routes:**
   - `src/routes/cues.routes.ts` — `POST /api/videos/:id/cues`, `GET /api/videos/:id/cues`, `PATCH /api/cues/:id`, `DELETE /api/cues/:id`. Wire both under `/api/videos/:id/cues` (for create + list) and `/api/cues/:id` (for update + delete) via two Router mounts in `routes/index.ts`.
   - `src/routes/attempts.routes.ts` — `POST /api/attempts`, `GET /api/attempts?videoId=...`.
   - Delete `src/routes/stubs/cues.routes.ts` and `src/routes/stubs/attempts.routes.ts`. Keep `voice-attempts` as stub (deferred).

8. **Tests:**
   - Unit: grading per cue type, edge cases (empty blanks, out-of-range MCQ index, duplicate matching pairs) — **target ≥95% branch coverage** on grading.
   - Unit: cue.service + attempt.service with mocked Prisma.
   - Unit: validators (parameterized: valid + invalid payload per type).
   - Integration: seed course+video → create 3 cues (one per type) → list cues → PATCH one → DELETE one → non-owner gets 403 → submit attempts and verify grading flows end-to-end.

### Exit criteria

- `npm run validate` green.
- `npm run test:integration` green.
- Grading branch coverage ≥95% (enforced at jest config level for this file if needed).
- `/api/docs.json` lists new endpoints with request/response schemas.
- `curl` recipe in commit message walks through create → list → submit → verify.

### Commit shape

One commit: `"Slice A: backend cue grading + attempts + cue CRUD"`.

---

## Slice B — Backend courses + enrollments + feed + designer-apps + events

**Why second:** These compose on top of Slice A (feed needs cues to attach; course-ownership checks are shared with cue-CRUD). Pure backend work; fully testable.

### Deliverables

1. **Courses** (`src/services/course.service.ts` + controller + routes):
   - `POST /api/courses` (COURSE_DESIGNER|ADMIN) — creates owned course; slug auto-generated as `slugify(title)-<short-uuid>` if absent; description required.
   - `GET /api/courses` — paginated list. Query params: `cursor`, `limit` (default 20, max 50), `owned=true|false`, `enrolled=true|false`. Unauthenticated users only see published courses without the `owned/enrolled` filters.
   - `GET /api/courses/:id` — Course + videos summary (just `id, title, orderIndex, status, durationMs`); 403 if not published AND not owner/collaborator/admin.
   - `PATCH /api/courses/:id` (owner|admin) — partial update; cannot transfer ownership here.
   - `POST /api/courses/:id/publish` (owner|admin) — requires ≥1 READY video; flips `published=true`.
   - `POST /api/courses/:id/collaborators` (owner|admin) — `{userId}` → 201; idempotent on conflict.
   - `DELETE /api/courses/:id/collaborators/:userId` (owner|admin).

2. **Enrollments** (`src/services/enrollment.service.ts`):
   - `POST /api/enrollments` — `{courseId}`; only published courses; idempotent on `(userId, courseId)`.
   - `GET /api/enrollments` — own enrollments with `{course, lastVideoId, lastPosMs, startedAt}`.
   - `PATCH /api/enrollments/:courseId/progress` — `{lastVideoId, lastPosMs}` → 204.

3. **Feed** (`src/services/feed.service.ts`):
   - `GET /api/feed?cursor=&limit=` — videos from current learner's enrolled courses, `status=READY`, ordered by enrollment recency desc, then orderIndex asc. Cursor is `<enrollmentStartedAt>_<orderIndex>_<videoId>` base64-encoded. Each entry: `{video, course: {id, title, coverImageUrl}, cueCount, hasAttempted}`.
   - Default limit 20, max 50.

4. **Designer applications** (`src/services/designer-application.service.ts`):
   - `POST /api/designer-applications` (LEARNER) — `{note?}`; 409 if existing PENDING; idempotent otherwise (new application after REJECTED allowed).
   - `GET /api/admin/designer-applications?status=...` (ADMIN) — list.
   - `PATCH /api/admin/designer-applications/:id` (ADMIN) — `{status: APPROVED|REJECTED, reviewerNote?}`. On APPROVED: atomically set `user.role = COURSE_DESIGNER` in a Prisma transaction with the application update.

5. **Analytics events** (`src/services/analytics.service.ts`):
   - `POST /api/events` — array of `{eventType: string, occurredAt: ISO8601, videoId?, cueId?, payload?: object}`. Max 100 per call. Fast-path batch insert via `prisma.analyticsEvent.createMany`. Non-blocking for the client: validate + enqueue, return 202.
   - No `GET` endpoint yet — admin analytics surface (Slice F) is read-only aggregates.
   - `GET /api/admin/analytics/courses/:id` (ADMIN) — raw aggregates: total views, completion rate (enrolled / completed at least one video to 90%), avg cue accuracy per cue type. Postgres queries grouped by course.

6. **Remove stubs:** delete `src/routes/stubs/courses.routes.ts`, `feed.routes.ts`, `designer-applications.routes.ts`, `events.routes.ts`. Keep `voice-attempts.routes.ts` only.

7. **Tests:** integration end-to-end per resource; admin transaction correctness verified (approve application + role promotion is atomic under simulated failure).

### Exit criteria

- `npm run validate` + `npm run test:integration` green.
- `/api/docs.json` complete.
- Smoke: 4-user scenario reproduces end-to-end via curl (documented in commit message) — admin approves designer, designer creates course + video + cues + publishes, learner enrolls + plays + answers + admin analytics shows result.

### Commit shape

One commit: `"Slice B: backend courses + enrollments + feed + designer-apps + events"`.

---

## Slice C — Flutter scaffold + Dio + Auth + token refresh

**Why third:** With the backend fully real, we can now write the Flutter app against a stable target. This slice deliberately stops at authenticated-but-empty — no feed, no video. The reason: auth plumbing has subtle concurrency bugs (refresh-token rotation races), and isolating it means we can unit-test it to death before any feature code depends on it.

### Deliverables

1. **Clone upstream for reference only.**
   - `git clone https://github.com/FlutterWiz/flutter_video_feed /tmp/flutter_video_feed-ref` (outside the repo).
   - Read the controller-cache implementation. Note the approach in a short file `docs/plans/flutter-feed-notes.md` so we don't re-read it each time.
   - We write our own lean version. Upstream is not copied into `app/`.

2. **Flutter project init.**
   - `cd app && /home/eric/flutter/bin/flutter create --org com.lifestream.learn --project-name lifestream_learn_app --platforms android .`
   - Pin via `.fvmrc`: `3.41.5` (write the file manually; `fvm install` can be deferred if fvm isn't present).
   - Edit `pubspec.yaml`: set description, set license `AGPL-3.0-or-later`, strip iOS-related commented blocks.
   - Delete generated `test/widget_test.dart` (replaced with our own).

3. **Dependencies pinned in `pubspec.yaml`:**
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     flutter_bloc: ^8.1.6
     dio: ^5.7.0
     go_router: ^14.2.0
     flutter_secure_storage: ^9.2.2
     freezed_annotation: ^2.4.4
     json_annotation: ^4.9.0
   dev_dependencies:
     flutter_test:
       sdk: flutter
     flutter_lints: ^5.0.0
     build_runner: ^2.4.13
     freezed: ^2.5.7
     json_serializable: ^6.8.0
     mocktail: ^1.0.4
   ```
   (Versions verified compatible with Dart 3.11.3 / Flutter 3.41.5 — if any are unavailable, pick closest published stable and note in commit.)

4. **Project layout** — hand-written from spec (ignore `flutter create`'s demo counter app):
   ```
   lib/
     main.dart
     config/
       api_config.dart          // API_BASE_URL from dart-define, default http://10.0.2.2:8090
     core/
       http/
         dio_client.dart        // Dio factory with base URL + interceptors
         error_envelope.dart    // ApiException + interceptor
         auth_interceptor.dart  // adds Bearer token; single-flight refresh on 401
       auth/
         token_store.dart       // flutter_secure_storage wrapper
         auth_tokens.dart       // freezed model
         auth_bloc.dart
         auth_event.dart
         auth_state.dart
       routing/
         app_router.dart        // go_router + role-gated redirect
       theme/
         app_theme.dart         // Material3, dark + light
     data/
       models/
         user.dart              // freezed + fromJson
       repositories/
         auth_repository.dart   // signup/login/refresh/me
     features/
       auth/
         login_screen.dart
         signup_screen.dart
       home/
         home_shell.dart        // placeholder — role-based landing
   ```

5. **Dio client** (`core/http/dio_client.dart`):
   - Factory takes `TokenStore` + `AuthBloc` (for logout-on-refresh-fail).
   - `BaseOptions` with `baseUrl` and reasonable timeouts (connect 10s, receive 30s).
   - Interceptors in order: `AuthInterceptor` (adds Bearer), `ErrorEnvelopeInterceptor` (decodes `{error, message, details}` into `ApiException`).

6. **`AuthInterceptor`** (single-flight refresh):
   - On every request (except `/api/auth/*` and `/health*`): attach `Authorization: Bearer <accessToken>` if present.
   - On 401: check `response.data.error === 'UNAUTHORIZED'`. If so:
     - If a refresh is already in flight, `await` it.
     - Otherwise start refresh, complete with new tokens, persist, retry original request once. Store the in-flight future in a static `Completer` so concurrent 401s share.
     - If refresh fails → emit `AuthBloc.add(LoggedOut())` and bubble the 401.

7. **`TokenStore`**:
   - `Future<void> save(AuthTokens tokens)` writes `accessToken` + `refreshToken` atomically (two writes in sequence; acceptable — Android Keystore is the bottleneck).
   - `Future<AuthTokens?> read()`.
   - `Future<void> clear()`.

8. **`AuthBloc`** states:
   - `AuthInitial` → on start, read TokenStore. If tokens present, `/api/auth/me` → `Authenticated(user)`; else `Unauthenticated`.
   - Events: `SignupRequested`, `LoginRequested`, `LoggedOut`, `AuthRehydrated`.
   - States: `AuthInitial`, `AuthAuthenticating`, `Authenticated(user)`, `Unauthenticated(errorMessage?)`.

9. **Routing**: `go_router` with `redirect` that consults `AuthBloc`:
   - Unauthenticated + not on `/login|/signup` → `/login`.
   - Authenticated + on `/login|/signup` → role-based home (`/feed`, `/designer`, `/admin`).
   - Role-gated: `LEARNER` cannot reach `/designer`; `COURSE_DESIGNER` cannot reach `/admin`.

10. **Screens (minimal):**
    - `LoginScreen`: email + password; submit → `AuthBloc.add(LoginRequested)`. Inline error shows `ApiException.message`. Link to signup.
    - `SignupScreen`: email + password + displayName; password field enforces ≥12 chars client-side; submit → `AuthBloc.add(SignupRequested)`.
    - `HomeShell`: placeholder "Welcome, ${user.displayName} (${user.role})" + logout button. Slice D replaces this.

11. **Tests:**
    - `flutter test` unit tests:
      - `TokenStore` mock: save/read/clear round-trip.
      - `ErrorEnvelopeInterceptor`: decodes canonical envelope → throws `ApiException` with correct `code/statusCode/message`.
      - `AuthInterceptor`: happy path attaches header; 401 path triggers refresh and retries; 5 concurrent 401s share one refresh call (assert `onFetchRefresh` called exactly once using `mocktail`); refresh failure emits logout.
      - `AuthBloc`: rehydrates from TokenStore; login/signup flows.
    - Widget tests:
      - `LoginScreen` validates email format; submit disables button; shows error on `ApiException`.
      - `SignupScreen` password length gate.

12. **`app/README.md` update** with run instructions:
    ```bash
    cd app
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8090
    # or on physical device:
    # flutter run --dart-define=API_BASE_URL=http://<dev-machine-ip>:8090
    ```

### Exit criteria

- `cd app && flutter pub get && dart run build_runner build` succeeds.
- `flutter analyze` → 0 issues.
- `flutter test` green (target ≥80% coverage on `core/` via `flutter test --coverage`).
- `flutter build apk --debug` produces `app/build/app/outputs/flutter-apk/app-debug.apk`.
- Manual-test checklist (for you, post-slice):
  - [ ] `flutter run` boots on emulator; lands on `/login`.
  - [ ] Signup with `test@example.com / CorrectHorseBattery1 / Test User` → lands on `HomeShell`.
  - [ ] Kill app, reopen → still on `HomeShell` (token persisted).
  - [ ] Set `JWT_ACCESS_TTL=30s` in `api/.env.local`, restart API, wait 30s, tap logout+login → verify refresh interceptor log line appears exactly once even if you hit the API a bunch quickly.
  - [ ] `adb logcat | grep -i token` → no token values in output.

### Commit shape

Two commits:
- `"Slice C: Flutter app scaffold (auth + HTTP plumbing)"` — project init + core/http + core/auth + routing + screens.
- `"Slice C: Flutter auth unit + widget tests"` — tests and any tweaks discovered during testing.

---

## Slice D — Flutter feed + player (no cues)

**Why fourth:** Feed + player is the biggest UI surface and the one most likely to need device iteration. Isolating it without the cue engine means timing bugs here don't cross-contaminate with cue-trigger bugs. Post-slice, a learner can scroll a vertical feed of videos and watch them — the Phase 4 "dumb pipe" the plan always targeted.

### Deliverables

1. **`lib/data/repositories/`**:
   - `CourseRepository.published({String? cursor, int limit})`.
   - `CourseRepository.enroll(String courseId)`.
   - `CourseRepository.myEnrollments()`.
   - `FeedRepository.page({String? cursor, int limit})` → returns `FeedPage{items, nextCursor, hasMore}`.
   - `VideoRepository.get(String id)`.
   - `VideoRepository.playback(String id)` with **in-memory TTL cache**: caches `{masterPlaylistUrl, expiresAt}` for `(expiresAt - now - 5min)`; stale entries refetch.
   - `EnrollmentRepository.updateProgress(courseId, videoId, posMs)` — debounced at the call site.

2. **Feed slice** (`lib/features/feed/`):
   - `FeedBloc`: `FeedInitial | Loading | Loaded(items, cursor, hasMore) | Error(ApiException)`.
   - `FeedScreen`:
     - `PageView.builder` (vertical, one page per video).
     - Uses our own **`VideoControllerCache`** (LRU, capacity 3, initialized inline in the screen's state): holds current + prev + next video controllers; disposes anything evicted. Controllers are keyed by `videoId`.
     - `onPageChanged` triggers preload of next (and prev) controllers.
     - `RefreshIndicator` on pull-to-refresh.
   - Empty state: "You're not enrolled in any courses yet." + button to `/courses`.

3. **Player** (`lib/features/player/learn_video_player.dart`):
   - Resolves signed URL via `VideoRepository.playback`, initializes `VideoPlayerController.networkUrl`.
   - Auto-plays when visible; pauses when scrolled away (via `VisibilityDetector` package or `PageController` listener).
   - Tap: play/pause toggle with fade overlay.
   - Double-tap left/right: seek ±10s.
   - Long-press: show scrubber (slider bound to controller position).
   - Error state: on 409 "not READY" → inline "Processing…" with a manual refresh button; on 401/403 → full-screen error; on 404 → "Video unavailable."
   - **Progress persistence:** every 5s (debounced) while playing, fire `EnrollmentRepository.updateProgress(courseId, videoId, posMs)`. Silent on failure.

4. **Video player plugin choice:**
   - Slice C added no video plugin. Now add `video_player: ^2.9.2` and `fvp: ^0.25.0` (backend registrar for Android — uses ffmpeg for broader codec support and future-proofs to media_kit migration if needed).
   - In `main.dart`, call `fvp.registerWith()` **only on Android** (guarded by `Platform.isAndroid`).

5. **Course browse** (`lib/features/courses/`):
   - `CoursesBrowseScreen`: grid of published courses (tapping a card → course detail).
   - `CourseDetailScreen`: course metadata + video list (READY only for learners) + "Enroll" button.
   - `MyCoursesScreen` (tab inside Home): enrolled list with last-watched indicator.

6. **Home shell refactor:**
   - `HomeShell` becomes a `BottomNavigationBar` with `Feed | Browse | Profile` (for LEARNER). Profile has the logout button + "Apply to become a course designer" link (stubbed in this slice, wired in Slice F).
   - Role-based: `COURSE_DESIGNER` gets `Feed | Designer | Profile`; `ADMIN` gets `Feed | Admin | Profile`.

7. **Tests:**
   - `FeedBloc` state transitions (initial load, next-page append, error recovery).
   - `VideoRepository.playback` TTL cache behavior (mock Dio: 1 call for first fetch + re-fetch, 0 calls within TTL).
   - `VideoControllerCache` eviction: add 4 items, assert only last 3 remain and 1st is disposed.
   - Widget: `FeedScreen` renders 3 mock items; pull-to-refresh triggers reload; empty state renders when list is empty.

### Exit criteria

- `flutter analyze` + `flutter test` green.
- `flutter build apk --debug` succeeds.
- Manual-test checklist (for you):
  - [ ] Enroll in a course via Browse.
  - [ ] Feed shows your enrolled course's READY videos.
  - [ ] Swipe up → next video plays without visible buffer gap (good network).
  - [ ] Swipe down → previous video resumes from ~start (preload warm).
  - [ ] Set network shaper to 3G → ABR drops within 10s, no stalls >3s (use Android Studio's network shaping tool).
  - [ ] Kill app mid-video → reopen → feed puts you back on the last-watched video around the same position.
  - [ ] `adb logcat | grep -E 'masterPlaylist|accessToken'` → no matches.

### Commit shape

Two commits:
- `"Slice D: Flutter feed + player (repositories + screens)"`.
- `"Slice D: Flutter feed tests"`.

---

## Slice E — Flutter cue engine + designer authoring

**Why fifth:** Cue engine depends on the player. Designer authoring depends on having a course + video upload path. Bundling them because they share `VideoEditor` (designer uses player + cue overlay in authoring mode).

### Deliverables

1. **Cue engine** (`lib/features/player/cue_scheduler.dart`):
   - `CueScheduler` takes `VideoPlayerController` + `List<Cue>`.
   - Maintains `int _nextCueIndex` and a `Timer.periodic(50ms)` that polls `controller.value.position`.
   - When `pos >= cues[_next].atMs - 200`:
     - If `pause=true`: `await controller.pause(); await controller.seekTo(atMs); notifier.value = cue;`.
     - If `pause=false`: `notifier.value = cue;` (overlay shown but video keeps playing).
     - On continue: `notifier.value = null; if (pause) await controller.play(); _nextCueIndex++;`.
   - App-lifecycle aware: on `AppLifecycleState.paused` mid-cue, persist `{cueId, videoId}` to secure storage; on resume, restore.

2. **Cue widgets** (`lib/features/cues/`):
   - `McqCueWidget`: question + up-to-4 radio choices; submit → `POST /api/attempts` → show correct/incorrect with explanation; "Continue" closes overlay.
   - `BlanksCueWidget`: parse `{{N}}` template; render interleaved `Text` + `TextField`; per-blank input; submit → grade. Show per-blank correctness diff on result.
   - `MatchingCueWidget`: two columns rendered as `Column` of `Card`s; tap left, then tap right to pair (draw line connectors using a `CustomPainter`); tap an existing pair to unpair. Submit → grade.
   - Common `CueOverlay` wraps these in a modal-like `Stack` child with backdrop, title bar (cue type icon), and Continue/Submit button bar.
   - Shared `AttemptRepository.submit(cueId, response)`.

3. **Designer authoring** (`lib/features/designer/`):
   - `DesignerHome`: list of owned courses + "Create course" CTA.
   - `CreateCourseScreen`: title + description + cover URL (optional) → `POST /api/courses`.
   - `CourseEditorScreen`: course metadata + video list + "Upload video" button. Upload uses `tus_client_dart`:
     - Calls `POST /api/videos` to get `{uploadUrl, uploadHeaders}`.
     - `TusClient(url: uploadUrl, file: xfile)` with metadata `{'videoId': videoId}`. **Verify `tus_client_dart` base64-encodes without padding**; if it pads, pre-encode and pass the raw header via `TusClient.headers`.
     - Progress indicator.
   - `VideoEditorScreen`: player (reuse `LearnVideoPlayer` in "authoring mode": no cue scheduler; adds a scrubber + timeline of existing cues). "Add cue at current time" → modal picker for cue type → cue-specific form → `POST /api/videos/:id/cues`.
   - Cue-specific forms validate client-side against the Zod-equivalent rules (we codify as simple Dart validators since we have only 3 types).

4. **Post-upload polling:** after upload completes, designer sees status=UPLOADING → transitions on poll (every 3s) to TRANSCODING → READY. Cue authoring blocks until READY.

5. **Tests:**
   - `CueScheduler`: advance a mocked `VideoPlayerController.value.position` and assert pause/notify happens within ±50ms. Edge: rapid seeking past multiple cues skips correctly.
   - `AttemptRepository.submit` round-trips against mocked Dio.
   - Widget: `McqCueWidget` renders, submit triggers attempt, result overlay shows.
   - Widget: `BlanksCueWidget` template parsing produces interleaved text+fields correctly.
   - Widget: `MatchingCueWidget` tap-to-pair builds correct pair list; invalid pair (same side twice) is rejected.
   - Widget: `VideoEditorScreen` shows timeline markers at correct positions for 3 mock cues.

### Exit criteria

- `flutter analyze` + `flutter test` green.
- `flutter build apk --debug` succeeds.
- Manual-test checklist:
  - [ ] As designer: create course → upload `sample-30s.mp4` → wait for READY → author 1 MCQ + 1 BLANKS + 1 MATCHING cue → publish course.
  - [ ] As learner: enroll → play → cue triggers at correct timestamp (±100ms) → answer each → grading matches expectation → video resumes.
  - [ ] Rapid-scrub past a cue during playback → cue is skipped (not replayed out of order).
  - [ ] Background app mid-cue → resume → overlay restored at correct position.
  - [ ] Attempting to write cues as LEARNER → 403 (but this is impossible in the UI; verify by hitting the API directly with a LEARNER token).

### Commit shape

Three commits:
- `"Slice E: cue scheduler + cue widgets"`.
- `"Slice E: designer authoring (course editor + video upload + cue forms)"`.
- `"Slice E: cue engine + designer tests"`.

---

## Slice F — Flutter admin + analytics + polish

**Why last:** This closes Phase 6. Admin flows are low-iteration (simple tables). Analytics needs the batch + offline-survival code. Polish is cross-cutting.

### Deliverables

1. **Designer application flow** (`lib/features/designer/designer_application_screen.dart`):
   - Learner Profile tab → "Become a Course Designer" → form with optional note → `POST /api/designer-applications` → confirmation screen + "pending review" state on subsequent visits.

2. **Admin review** (`lib/features/admin/`):
   - `AdminHome`: tab bar with `Applications | Analytics`.
   - `DesignerApplicationsScreen`: table of pending apps (applicant email, note, submitted date). Approve/Reject buttons → `PATCH /api/admin/designer-applications/:id`.
   - `CourseAnalyticsScreen`: pick a course → shows views, completion rate, per-cue accuracy. Single table, not a chart library.

3. **Analytics batching** (`lib/core/analytics/`):
   - `AnalyticsBuffer`: `Queue<AnalyticsEvent>` in memory + persistent backup via `flutter_secure_storage` (or `path_provider` + simple JSON file; secure storage is overkill for non-secret telemetry but keeps deps minimal).
   - `AnalyticsEvent{eventType, occurredAt, videoId?, cueId?, payload?}` — `freezed` model.
   - Flush triggers:
     - Every 30s via `Timer.periodic`.
     - On `AppLifecycleState.paused`.
     - When buffer size ≥ 50.
   - `POST /api/events` with batch (chunks of 100). On 4xx, drop batch with warning log. On 5xx or network error, retry with exponential backoff capped at 5min.
   - **Privacy guard:** reject any event whose `payload` contains free-text fields like `answer` or `response`. Only structural data (`{cueType, correct, durationMs, variantIndex}`).
   - Emit events at: video_view (on play), video_complete (90% watched), cue_shown, cue_answered (with correct/incorrect), session_start, session_end.

4. **Polish:**
   - `FLAG_SECURE` on cue overlay screens (prevents screenshots leaking answers). Use `flutter_windowmanager` or a platform channel; if plugin availability is iffy in 4.x, write a minimal Kotlin method channel in `android/app/src/main/kotlin/.../FlagSecurePlugin.kt`.
   - Material3 theme with a defined primary/secondary palette (placeholder values — designer fills in).
   - Adaptive launcher icon via `flutter_launcher_icons` from a placeholder 1024x1024 PNG at `app/assets/icon/app_icon.png`.
   - Splash screen via `flutter_native_splash`.
   - Error screens: friendly text + "Retry" + "Go home"; never expose stacks.
   - Loading states: single `Skeletonizer` pattern (or a custom shimmer).
   - Build flavors: `dev` (cleartext HTTP, debug logging) and `prod` (HTTPS required, debug logs stripped via `kDebugMode` guards).

5. **Tests:**
   - `AnalyticsBuffer`: 30s tick flushes; app-pause flushes; capacity-triggered flush; offline resilience (persist → restart → flush eventually succeeds); backoff caps at 5min; privacy guard rejects PII.
   - Widget: `DesignerApplicationsScreen` approve flow updates list; admin analytics screen renders aggregates from mocked API.

### Exit criteria

- `flutter analyze` + `flutter test` green.
- `flutter build apk --release` (not just `--debug`) succeeds with a signed debug keystore (default Flutter debug keystore is fine for this milestone).
- APK size under 50MB.
- Manual-test checklist (the full Phase 6 exit criteria):
  - [ ] User A signs up → applies to be designer.
  - [ ] User B (admin, seeded) approves A.
  - [ ] A (now designer) creates course "Spanish 101" → uploads fixture → authors 3 cues → publishes.
  - [ ] User C enrolls → watches → answers all cues → completes.
  - [ ] B views admin analytics for the course → sees 1 view, 100% completion, correct accuracy.
  - [ ] Analytics batching: disconnect device from Wi-Fi → watch a video → swipe up 3 times → reconnect → events are POSTed on next flush (watch `adb logcat | grep /api/events`).
  - [ ] `flutter build apk --release` then install on a clean Android 10+ device → full journey works.

### Commit shape

Three commits:
- `"Slice F: admin review + designer application"`.
- `"Slice F: analytics batching + offline survival"`.
- `"Slice F: polish (theme, icon, splash, FLAG_SECURE, build flavors)"`.

---

## Execution ledger

Each slice's execution updates this table. I fill it as I finish; you can spot-check progress.

| Slice | Status | Verified | Notes |
|---|---|---|---|
| A | ✅ verified | Unit + integration | Commit 8f77138. 320 unit + 70 integration green. Grading branch coverage 100%. |
| B | ✅ verified | Unit + integration | Commit d4f9858. 463 unit + 114 integration green. 4-user smoke scenario in commit. |
| C | 🟩 code complete, tests green | Static + unit + widget | Commit 34d9ea5. 38 tests green, analyze clean, APK builds, core/ coverage 91.8%. On-device verification pending. |
| D | 🟩 code complete, tests green | Static + unit + widget | Commit e3c8e31. 98 tests green, analyze clean, APK builds (212MB debug). On-device verification pending. |
| E | 🟩 code complete, tests green | Static + unit + widget | Commit 20be263. 175 tests green, analyze clean, APK builds (204MB debug). cue_validators 97.6% / cue_scheduler 94.9%. On-device verification pending. |
| F | 🟨 in progress | — | — |

Status values: `⬜ not started`, `🟨 in progress`, `🟩 code complete, tests green`, `✅ verified (where possible)`, `⚠️ blocked`.

---

## What this plan deliberately does NOT include

- **iOS** — deferred. `android/` only; `ios/` scaffolding skipped entirely. Easier to add later than to remove cruft now.
- **CI/CD** — deferred to Phase 7 (pre-existing `cicd-bootstrapping` skill handles this).
- **Voice cues** — reserved in schema (ADR 0004); backend rejects with 501; UI never exposes.
- **Offline video playback** — not a planned feature pre-1.0.
- **Payments/monetization** — IMPLEMENTATION_PLAN.md §9 open question; post-Phase-7.
- **Push notifications** — post-MVP.
- **Hot-swappable video player** — we ship `video_player`; the `media_kit` upgrade is a post-ship decision if jitter is unacceptable.

---

## Risks and mitigations (delta from `flutter-app.md`)

| Risk | Mitigation |
|---|---|
| `video_player` cue-trigger jitter exceeds 100ms on low-end devices | Slice E's scheduler uses 50ms polling + 200ms lead time; if measured jitter is bad, swap to `media_kit` is a ~2 day retrofit (the scheduler API doesn't care about the underlying controller) |
| `tus_client_dart` API changes / base64 padding | Slice E task 3 includes an inline verification; fallback is raw `Upload-Metadata` header |
| Refresh rotation race at scale | Slice C tests cover 5-concurrent-401 scenario explicitly with mocktail |
| Slice D/E emulator-free verification gap | Each slice ships a clear manual-test checklist for you; I don't mark slices ✅ until you confirm |
| Grading logic security bug | Slice A's grading module has enforced ≥95% branch coverage; code reviewed before Slice B starts |
| Plan drift during execution | Progress ledger above; update every commit |

---

## Ready-state signals

Before starting Slice A, verify:
- [x] Backend Phase 3 green (transcode-e2e + transcode-resilience tests pass).
- [x] `learn_api_test` migrations applied.
- [x] `docker compose up -d` running.
- [x] `accounting-postgres` + `accounting-redis` up.
- [x] No dev API on port 3011 (or acknowledge the `transcode-e2e.test.ts` EADDRINUSE quirk).
