# lifestream-learn-app

Flutter Android app for Lifestream Learn — learner feed and course-designer authoring UI in one binary, gated by role.

## Status

Placeholder. The Flutter project itself is initialised in Phase 4 when we fork [`FlutterWiz/flutter_video_feed`](https://github.com/FlutterWiz/flutter_video_feed) (MIT) as the starting point.

## Planned stack

- Flutter 3.x, Android-first
- State: BLoC (carried over from the feed fork)
- Video: `video_player` + ExoPlayer (Android HLS native), `fvp` as backend registrar
- Upload: `tus_client_dart` (resumable)
- HTTP: `dio` with JWT interceptor and refresh rotation

## Layout (planned)

```
app/
├── android/
├── ios/              # deferred; empty for now
├── lib/
│   ├── main.dart
│   ├── core/              # http, auth, routing, theme
│   ├── features/
│   │   ├── auth/
│   │   ├── feed/          # learner feed
│   │   ├── player/        # video + cue engine
│   │   ├── cues/          # widgets per cue type
│   │   ├── courses/       # learner course browse/enroll
│   │   ├── designer/      # COURSE_DESIGNER role UI
│   │   └── admin/         # ADMIN role UI
│   └── data/              # API client, models
├── test/
├── integration_test/
├── pubspec.yaml
├── analysis_options.yaml
└── .nvmrc-equivalent via fvm config in .fvm/
```

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
