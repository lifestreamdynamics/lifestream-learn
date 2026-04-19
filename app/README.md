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

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
