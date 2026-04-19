# lifestream-learn-app

Flutter Android app for Lifestream Learn — learner feed and course-designer authoring UI in one binary, gated by role.

## Status

Slice C complete (auth plumbing + Dio HTTP + secure token storage + role-gated go_router + minimal Login/Signup/HomeShell). No feed, no video yet — that lands in Slice D.

Per project CLAUDE.md, this slice is `compiled-and-analyzed-only (device test needed)` until the operator drives on-device verification.

## Stack

- Flutter 3.41.5 / Dart 3.11.3 (pinned via `.fvmrc`)
- Android-only (no iOS / web / desktop)
- `flutter_bloc` for state
- `dio` for HTTP, `flutter_secure_storage` for token persistence
- `go_router` for role-gated routing
- `freezed` + `json_serializable` for models

## Layout

```
app/
├── android/                  # Flutter-generated Android project
├── lib/
│   ├── main.dart             # DI wiring + App root
│   ├── config/api_config.dart
│   ├── core/
│   │   ├── auth/             # TokenStore, AuthBloc, AuthTokens
│   │   ├── http/             # createDio, AuthInterceptor, ErrorEnvelopeInterceptor
│   │   ├── routing/          # go_router + role-based redirect
│   │   └── theme/            # Material 3 light + dark
│   ├── data/
│   │   ├── models/           # User (freezed)
│   │   └── repositories/     # AuthRepository
│   └── features/
│       ├── auth/             # LoginScreen, SignupScreen
│       └── home/             # HomeShell (placeholder; Slice D replaces)
├── test/                     # Unit + widget tests, mirrors lib/ layout
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

`flutter test --coverage` writes `coverage/lcov.info`. Target ≥80% line coverage on `lib/core/`; Slice C currently sits at ~92%.

## Manual-test checklist (operator runs this on a device / emulator)

- [ ] `flutter run` boots on emulator; lands on `/login`.
- [ ] Signup with `test@example.com / CorrectHorseBattery1 / Test User` → lands on `HomeShell` showing "Welcome, Test User (LEARNER)".
- [ ] Kill app, reopen → still on `HomeShell` (token persisted).
- [ ] With `JWT_ACCESS_TTL=30s` in `api/.env.local` (restart API), log out + log back in, wait 30s, hit the API a few times quickly → interceptor refresh fires exactly once (watch API logs for `/api/auth/refresh`).
- [ ] `adb logcat | grep -i token` → no token values in output.
- [ ] Log out button → returns to `/login`.

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
