# lifestream-learn-app

Flutter Android app for Lifestream Learn — learner feed and course-designer authoring UI in one binary, gated by role.

## Status

Slices C–F are code-complete and compiled-and-analyzed-only per project CLAUDE.md: Flutter scaffold + auth (C), vertical feed + player (D), cue engine + designer authoring (E), and admin + analytics + polish (F). Operator device verification is pending; see the per-slice manual-test checklists below.

Per project CLAUDE.md, these slices are `compiled-and-analyzed-only (device test needed)` until the operator drives on-device verification.

## Stack

- Flutter 3.41.5 / Dart 3.11.3 (pinned via `.fvmrc`)
- Android-only (no iOS / web / desktop)
- `flutter_bloc` for state
- `dio` for HTTP, `flutter_secure_storage` for token persistence
- `go_router` (incl. `StatefulShellRoute.indexedStack`) for role-gated routing
- `freezed` + `json_serializable` for models
- `video_player` + `fvp` (ffmpeg backend) for HLS playback
- `visibility_detector` for pause-when-offscreen in the feed

## Layout

```
app/
├── android/                  # Flutter-generated Android project
├── lib/
│   ├── main.dart             # DI wiring + fvp registration + App root
│   ├── config/api_config.dart
│   ├── core/
│   │   ├── auth/             # TokenStore, AuthBloc, AuthTokens
│   │   ├── http/             # createDio, AuthInterceptor, ErrorEnvelopeInterceptor
│   │   ├── routing/          # go_router + StatefulShellRoute
│   │   └── theme/            # Material 3 light + dark
│   ├── data/
│   │   ├── models/           # User, Course, VideoSummary, FeedEntry, Enrollment, ...
│   │   └── repositories/     # Auth / Course / Feed / Video / Enrollment
│   └── features/
│       ├── auth/             # LoginScreen, SignupScreen
│       ├── feed/             # FeedBloc, FeedScreen, VideoControllerCache
│       ├── player/           # LearnVideoPlayer
│       ├── courses/          # CoursesBloc, browse / detail / my-courses screens
│       ├── profile/          # ProfileScreen + designer-application stub
│       └── home/             # HomeShell (BottomNavigationBar + stubs for designer / admin)
├── test/                     # Unit + widget tests, mirrors lib/ layout
│   └── test_support/         # Shared fake Dio adapter for repository tests
├── pubspec.yaml
├── .fvmrc                    # 3.41.5
└── analysis_options.yaml
```

## Run

The simplest path is the top-level `Makefile`, which handles emulator launch + dart-defines for you:

```bash
# from the repo root, with `make up` already done in another shell:
make app-deps    # one-time: pub get + build_runner codegen
make app         # launches AVD if needed, then flutter run --flavor dev
```

`make app` points the app at `http://10.0.2.2:$NGINX_HOST_PORT` (nginx-fronted, see `infra/nginx/local.conf`) — that's `:8090` in the checked-in `infra/.env`. Three dev users are pre-seeded — see the root [`README.md`](../README.md#local-development-quickstart) for credentials.

### Manual run (for finer control)

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --flavor dev --dart-define=API_BASE_URL=http://10.0.2.2:8090
# or on a physical device (adb over USB / Wi-Fi):
# flutter run --flavor dev --dart-define=API_BASE_URL=http://<dev-machine-ip>:8090
```

`flutter` / `dart` are expected on `PATH`. The SDK version is pinned in `.fvmrc` (3.41.5); use [fvm](https://fvm.app/) or asdf to keep a matching toolchain, or install Flutter directly and symlink it into `PATH` — never bake an operator-specific absolute path into scripts or docs.

`10.0.2.2` is the Android emulator's alias for the host machine. On a physical device, point `API_BASE_URL` at the host's LAN IP. The `dev` flavor allows cleartext HTTP (required because local nginx is plain HTTP); the `prod` flavor blocks it.

## Test + analyze + build

```bash
flutter analyze
flutter test --coverage
flutter build apk --debug --flavor dev
```

## Production build

The `prod` flavor points at the real API URL (`https://learn-api.REDACTED-BRAND-DOMAIN`) and blocks cleartext HTTP. Use either the Makefile target or the explicit invocation below; do not hard-code the URL into Dart sources — it's threaded in at build time via `--dart-define`.

```bash
# From the repo root (preferred):
make app-prod

# Or directly from app/:
flutter build apk --flavor prod --release \
  --dart-define=API_BASE_URL=https://learn-api.REDACTED-BRAND-DOMAIN
```

The resulting APK lands at `app/build/app/outputs/flutter-apk/app-prod-release.apk`. It signs with the debug keystore until a production signing config is wired — that's a separate Play Store slice, out of scope for the current deploy prep.

`flutter test --coverage` writes `coverage/lcov.info`. Slice D line coverage sits at ~68% across hand-written Dart (excluding `*.g.dart` / `*.freezed.dart`); the player (`learn_video_player.dart`) drags this down because the `video_player` platform plugin can't be fully exercised from unit tests.

## Slice D

### New routes

- `/feed` — TikTok-style vertical `PageView` of videos from enrolled courses. Pull-to-refresh; loads more on approach.
- `/courses` — browse grid of published courses (all roles).
- `/courses/:id` — course detail + video list + Enroll CTA.
- `/my-courses` — learner's enrollments with last-watched position.
- `/profile` — identity, role, log-out, "apply to become a designer" link.
- `/designer`, `/admin` — stubs until Slice E / F.
- `/designer-application` — stub until Slice F.

### Environment

Pass the API base URL via `--dart-define=API_BASE_URL=...`:

- Emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8090`
- Physical device: `--dart-define=API_BASE_URL=http://<dev-machine-ip>:8090`

> `8090` is the locally-checked-in `NGINX_HOST_PORT` (see `infra/.env` — shifted off `:80` to avoid colliding with accounting-nginx). The Makefile reads that value and passes it through to `make app`; if you change `NGINX_HOST_PORT`, substitute the same value here.

### Dep pins

- `video_player: ^2.9.2` (resolved at `2.11.1`).
- `fvp: ^0.25.0` (registers the ffmpeg-backed video_player backend on Android).
- `visibility_detector: ^0.4.0+2`.

### Manual-test checklist (operator runs this on a device / emulator)

Auth regression (Slice C):

- [ ] `flutter run` boots; lands on `/login`.
- [ ] Signup with `test@example.com / CorrectHorseBattery1 / Test User` → lands on feed.
- [ ] Kill app, reopen → still on feed (token persisted).
- [ ] Log out returns to `/login`.

Slice D (new):

- [ ] Browse → tap a course → Enroll → snackbar + "Watch in feed" CTA.
- [ ] Feed shows your enrolled course's READY videos.
- [ ] Swipe up → next video plays without visible buffer gap (good network).
- [ ] Swipe down → previous video resumes from ~start (preload warm).
- [ ] Tap → play/pause overlay fades in then out.
- [ ] Double-tap left / right → seeks −10s / +10s.
- [ ] Long-press → scrubber appears; drag to seek; release hides it.
- [ ] Set network shaper to 3G → ABR adapts within ~10s, no stalls >3s (Android Studio's network shaper).
- [ ] Kill app mid-video → reopen → My Courses shows last-watched hint around the same position.
- [ ] `adb logcat | grep -E 'masterPlaylist|accessToken'` → no matches.
- [ ] With `API_BASE_URL` pointing at a backend where transcode is still running, navigate to a video whose `status != READY` → "Processing…" overlay + Refresh button.
- [ ] Tab switches (Feed → Browse → Feed) preserve scroll position.

## Slice E

### What lands

- **Cue engine** (`lib/features/player/cue_scheduler.dart`) — a 50ms-polling scheduler that fires the overlay at `cue.atMs - 200ms` and (if `pause=true`) pauses + seeks the controller. Handles rapid-scrub skip-ahead, pause=false "annotation" cues, and app-lifecycle checkpoint persistence.
- **Cue widgets** (`lib/features/cues/`) — `CueOverlay` chrome + `McqCueWidget`, `BlanksCueWidget`, `MatchingCueWidget`. All three submit to `/api/attempts` and render the server's graded result. Client never computes `correct` locally.
- **Designer authoring** (`lib/features/designer/`) — `DesignerHomeScreen` (owned courses), `CreateCourseScreen`, `CourseEditorScreen` (video upload via `tus_client_dart`), `VideoEditorScreen` (cue timeline + form), `CueFormSheet` (per-type cue authoring with client-side validators mirroring `api/src/validators/cue-payloads.ts`).
- **Repositories** — `CueRepository` (CRUD) and `AttemptRepository` (submit). `CourseRepository.published(owned: true)` filters to the caller's own courses; `CourseRepository.create/update/publish`; `VideoRepository.createVideo` returns the tusd upload ticket.

### New routes

- `/designer` — designer home (owned-courses list + Create CTA).
- `/designer/courses/new` — create course form.
- `/designer/courses/:id` — course editor (title/description, videos, upload, publish).
- `/designer/videos/:id/edit` — per-video cue editor (timeline + cue forms).
- `/videos/:id/watch` — full-screen "watch with cues" experience used by the feed's tap-to-open path.

### Design notes

- **50ms poll + 200ms lead** is load-bearing; worst-case jitter is ±50ms on low-end devices. See the comment block at the top of `cue_scheduler.dart`.
- **VOICE is not exposed in the UI.** The cue-type dropdown shows only MCQ, BLANKS, MATCHING. The backend 501s on VOICE anyway (ADR 0004).
- **Client never grades.** Every attempt round-trips `/api/attempts`; the server's `{correct, scoreJson, explanation}` drives result rendering. MCQ `answerIndex`, MATCHING `pairs`, and BLANKS `accept` lists ARE present in the cue payload (the backend needs them for grading) — the client just must not build UI that leans on them. See the security comment on `activeCueNotifier`.
- **tus_client_dart padding.** The library's `base64.encode` pads; tusd's decoder is permissive, so we pass the videoId via the library's `metadata:` map and let it rebuild the `Upload-Metadata` header. See `test/features/designer/tus_uploader_test.dart` for the verification.
- **MediaCodec budget.** Designer authoring uses a dedicated `VideoControllerCache(capacity: 1)` so the feed's 3-slot cache + the editor preview don't exceed the decoder budget on cheap hardware.

### Dep pins

- `tus_client_dart: ^2.5.0` (the roadmap asked for ^5.0.0; 2.5.0 is the highest version on pub.dev).
- `file_picker: ^8.0.0` (resolved 8.3.7).
- `cross_file: ^0.3.4+1` (transitive; declared to satisfy `depend_on_referenced_packages`).
- `fake_async: ^1.3.1` (dev_dependencies; deterministic virtual clock for cue-scheduler timing tests).

### Manual-test checklist (operator runs this on a device / emulator)

Verbatim from the roadmap:

- [ ] As designer: create course → upload `sample-30s.mp4` → wait for READY → author 1 MCQ + 1 BLANKS + 1 MATCHING cue → publish course.
- [ ] As learner: enroll → play → cue triggers at correct timestamp (±100ms) → answer each → grading matches expectation → video resumes.
- [ ] Rapid-scrub past a cue during playback → cue is skipped (not replayed out of order).
- [ ] Background app mid-cue → resume → overlay restored at correct position.
- [ ] Attempting to write cues as LEARNER → 403 (impossible in the UI; verify by hitting the API directly with a LEARNER token).

Extra smoke tests added by this slice:

- [ ] Designer edits an existing cue (tap the edit icon on the cue list) → form pre-fills → Save updates → timeline marker redraws.
- [ ] Delete cue (trash icon on cue list) → confirmation dialog → cue disappears from list + timeline.
- [ ] `adb logcat` during upload → no `uploadUrl`, `masterPlaylistUrl`, or bearer token lines.
- [ ] Cue-type dropdown in the form never shows a "Voice" option.

### Status

Per project CLAUDE.md, this slice is **✎ compiled-and-analyzed-only (device test needed)** until the operator drives on-device verification. `flutter analyze` clean (0 issues), `flutter test` green (175 tests), `flutter build apk --debug` succeeds (~204 MB).

## Slice F

### What lands

- **Designer application flow** (`lib/features/designer/designer_application_screen.dart`) — four-state screen (form / PENDING / APPROVED / REJECTED) driven by `GET /api/designer-applications/me` (new endpoint added in this slice) and `POST /api/designer-applications`.
- **Admin review** (`lib/features/admin/`) — `AdminHomeScreen` (Applications / Analytics tabs), `DesignerApplicationsScreen` (paginated PENDING list with Approve / Reject + reviewer-note dialog), `CourseAnalyticsScreen` (picker + `totalViews` + `completionRate` + per-cue-type accuracy `DataTable`).
- **Analytics batching** (`lib/core/analytics/`) — offline-survivable `AnalyticsBuffer` that persists to `${applicationDocumentsDirectory}/analytics_buffer.json`, flushes every 30s, on app-paused, and when it crosses 50 events. 5xx / network errors schedule exponential backoff capped at 5 minutes; 4xx drops the batch with a `debugPrint`. A compile-time privacy guard rejects any event whose `payload` contains one of `{answer, response, input, text, content}` or any String value longer than 128 chars.
- **Polish** — FLAG_SECURE on cue overlays + admin screens via a Kotlin `MethodChannel`, Material 3 theme rooted at Indigo-600 (`#4F46E5`), `flutter_launcher_icons` + `flutter_native_splash` generated from a placeholder `assets/icon/app_icon.png`, friendly error screens (`FriendlyErrorScreen` / `FriendlyErrorBody`) that never expose stack traces, Skeletonizer loading placeholders on list screens, and `dev` / `prod` build flavors.

### New routes

- `/admin` — admin landing (tab bar: Applications + Analytics). Gated to `UserRole.admin` by the router.
- `/designer-application` — real designer-application screen (replaces the Slice D stub).

### Build flavors

Two flavors:

| Flavor | Cleartext HTTP | R8/minify | `applicationId` suffix |
|---|---|---|---|
| `dev` | **yes** (via `android/app/src/dev/AndroidManifest.xml` overlay) | off on debug | `.dev` |
| `prod` | no | on (release) | (none) |

Run / build examples:

```bash
# Dev, emulator
flutter run --flavor dev --dart-define=API_BASE_URL=http://10.0.2.2:8090

# Prod release APK (universal — the one the Phase 6 exit criteria ask for)
flutter build apk --flavor prod --release --dart-define=API_BASE_URL=https://learn.example.com

# Prod release, split per ABI (each APK lands under 50 MB)
flutter build apk --flavor prod --release --split-per-abi
```

The release build signs with the debug keystore for now (TODO: production signing). Both flavors share the same Dart tree; the only difference at the platform level is the cleartext-HTTP allowance.

### FLAG_SECURE

Android's `WindowManager.LayoutParams.FLAG_SECURE` blocks screenshot, screen-recording, and Recents thumbnails. We enable it in two places:

- **Cue overlays** — `CueOverlayHost` flips it on when `activeCueNotifier` goes non-null and off when it goes null again. Prevents a learner from screenshotting the MCQ/BLANKS/MATCHING answer screen.
- **Admin screens** — `DesignerApplicationsScreen` and `CourseAnalyticsScreen` enable it in `initState` and disable in `dispose`. Both surfaces contain PII (user ids, aggregate analytics).

The Dart surface is `core/platform/flag_secure.dart`; the Kotlin bridge is `android/app/src/main/kotlin/.../FlagSecureBridge.kt` registered from `MainActivity.configureFlutterEngine`. Tests substitute the method channel via `FlagSecure.testChannel = ...`.

### Analytics events

| `eventType` | Emit site | Payload |
|---|---|---|
| `session_start` | `main.dart` after `hydrate()`+`startPeriodic()` | `{}` |
| `session_end` | `AppLifecycleState.detached` (best-effort) | `{durationMs}` |
| `video_view` | First `_onControllerTick` where `isPlaying == true` | `{}` |
| `video_complete` | Position reaches 90% of duration (once per mount) | `{durationMs}` |
| `cue_shown` | `CueScheduler.activeCueNotifier` flips non-null | `{cueType}` |
| `cue_answered` | Cue widget receives a graded `AttemptResult` | `{cueType, correct}` |

**Privacy guard**: events with a `payload` containing any of `answer`, `response`, `input`, `text`, `content`, or any string value longer than 128 chars are silently dropped with a `debugPrint` warning. The guard is a seatbelt — the emit sites must never hand those keys over in the first place.

### Dep pins (Slice F)

- `path_provider: ^2.1.4` (resolves 2.1.5) — persists the analytics buffer under the app's private documents directory. Never uses external storage (would leak on shared SD cards).
- `skeletonizer: ^2.1.3` — Skeletonizer-style list-loading placeholders. **Must be 2.x**: the 1.4 series doesn't implement `Canvas.drawRSuperellipse` which Flutter 3.41's `ui.Canvas` adds, so 1.4.3 fails to compile under this SDK.
- `flutter_launcher_icons: ^0.14.1` (dev) — launcher-icon generation.
- `flutter_native_splash: ^2.4.1` (dev) — splash screen generation.

### Placeholder assets

`assets/icon/app_icon.png` is a **placeholder** 1024×1024 gradient generated by a small Python script at slice time. Replace with a designer-provided PNG and re-run:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Manual-test checklist (operator runs this on a device / emulator)

Verbatim from the roadmap's Phase 6 exit criteria:

- [ ] User A signs up → applies to be designer.
- [ ] User B (admin, seeded) approves A.
- [ ] A (now designer) creates course "Spanish 101" → uploads fixture → authors 3 cues → publishes.
- [ ] User C enrolls → watches → answers all cues → completes.
- [ ] B views admin analytics for the course → sees 1 view, 100% completion, correct accuracy.
- [ ] Analytics batching: disconnect device from Wi-Fi → watch a video → swipe up 3 times → reconnect → events are POSTed on next flush (watch `adb logcat | grep /api/events`).
- [ ] `flutter build apk --flavor prod --release` then install on a clean Android 10+ device → full journey works.

Extra smoke tests added by this slice:

- [ ] Screenshot during a cue overlay → OS shows "screenshots are disabled by the app" (or Recents shows a grey tile).
- [ ] Admin screens present the same screenshot block.
- [ ] Airplane-mode during a cue-heavy session → analytics buffer keeps growing (check `/data/data/.../files/analytics_buffer.json` via `adb shell run-as`) → reconnect → buffer drains on next periodic tick.
- [ ] Install prod + dev APKs simultaneously (`.dev` applicationId suffix keeps them coexisting).
- [ ] Rejected applicant re-submits → server resurrects the row back to PENDING (not a new row).

### Status

Per project CLAUDE.md, this slice is **✎ compiled-and-analyzed-only (device test needed)** until the operator drives on-device verification.

- `flutter analyze` → 0 issues.
- `flutter test` → **222 passed** (175 from previous slices + 47 new).
- `flutter build apk --debug --flavor dev` → succeeds.
- `flutter build apk --flavor prod --release` → succeeds (universal APK 90.8 MB; `--split-per-abi` drops each ABI slice under the 50 MB target — arm64-v8a: 31.7 MB, armeabi-v7a: 26.1 MB, x86_64: 34.3 MB).
- Backend added `GET /api/designer-applications/me` with 4 new integration tests (all green).

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
