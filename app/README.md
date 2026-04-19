# lifestream-learn-app

Flutter Android app for Lifestream Learn — learner feed and course-designer authoring UI in one binary, gated by role.

## Status

Slice D in-review: vertical feed + video player (no cues; Slice E wires those in). Learners can browse published courses, enroll, and scroll a TikTok-style PageView of videos from their enrolled courses. The player handles tap/double-tap/long-press gestures, signs playback URLs via a short-lived HMAC, and caches controllers in a 3-slot LRU so swipes don't stutter.

Per project CLAUDE.md, this slice is `compiled-and-analyzed-only (device test needed)` until the operator drives on-device verification.

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

```bash
cd app
/home/eric/flutter/bin/flutter pub get
/home/eric/flutter/bin/dart run build_runner build --delete-conflicting-outputs
/home/eric/flutter/bin/flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8090
# or on a physical device (adb over USB / Wi-Fi):
# /home/eric/flutter/bin/flutter run --dart-define=API_BASE_URL=http://<dev-machine-ip>:8090
```

`10.0.2.2` is the Android emulator's alias for the host machine. On a physical device, point `API_BASE_URL` at the host's LAN IP.

## Test + analyze + build

```bash
/home/eric/flutter/bin/flutter analyze
/home/eric/flutter/bin/flutter test --coverage
/home/eric/flutter/bin/flutter build apk --debug
```

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

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
