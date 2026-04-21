import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/analytics/analytics_sinks.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/core/settings/settings_cubit.dart';
import 'package:lifestream_learn_app/core/settings/settings_store.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/data/repositories/enrollment_repository.dart';
import 'package:lifestream_learn_app/data/repositories/video_repository.dart';
import 'package:lifestream_learn_app/features/feed/video_controller_cache.dart';
import 'package:lifestream_learn_app/features/player/caption_loader.dart';
import 'package:lifestream_learn_app/features/player/learn_video_player.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../test_support/fake_secure_storage.dart';

// ---------------------------------------------------------------------------
// Caption test helpers
// ---------------------------------------------------------------------------

/// Returns a [CaptionLoader] whose Dio returns a minimal valid WebVTT file
/// without touching the network.
CaptionLoader fakeCaptionLoader() {
  final dio = Dio(BaseOptions(baseUrl: 'https://cdn.test'));
  dio.httpClientAdapter = _FakePlainTextAdapter(200, 'WEBVTT\n\n');
  return CaptionLoader(dio: dio);
}

/// Returns a [CaptionLoader] whose Dio always returns 404.
CaptionLoader notFoundCaptionLoader() {
  final dio = Dio(BaseOptions(baseUrl: 'https://cdn.test'));
  dio.httpClientAdapter = _Fake404Adapter();
  return CaptionLoader(dio: dio);
}

CaptionTrack captionTrack(String lang) => CaptionTrack(
      language: lang,
      url: 'https://cdn.test/$lang.vtt',
      expiresAt: DateTime.utc(2030, 1, 1),
    );

PlaybackInfo playbackWithCaptions({String defaultLang = 'en'}) => PlaybackInfo(
      masterPlaylistUrl: 'https://cdn.test/master.m3u8',
      expiresAt: DateTime.utc(2030, 1, 1),
      captions: [captionTrack(defaultLang)],
      defaultCaptionLanguage: defaultLang,
    );

/// Minimal Dio adapter that returns a plain-text body at a given status code.
class _FakePlainTextAdapter implements HttpClientAdapter {
  _FakePlainTextAdapter(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromBytes(
        body.codeUnits,
        statusCode,
        headers: {Headers.contentTypeHeader: ['text/vtt; charset=utf-8']},
      );

  @override
  void close({bool force = false}) {}
}

/// Adapter that returns a 404 JSON error envelope.
class _Fake404Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    const body = '{"error":"NOT_FOUND","message":"gone"}';
    return ResponseBody.fromBytes(
      body.codeUnits,
      404,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockVideoRepository extends Mock implements VideoRepository {}

class _MockEnrollmentRepository extends Mock implements EnrollmentRepository {}

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.results);
  final List<ConnectivityResult> results;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A fake controller that reports `isInitialized: false`. The player
/// treats this as "couldn't init" and renders the unknown-error state.
/// This keeps tests off the platform plugin entirely.
class _UninitializedController implements VideoPlayerController {
  @override
  Future<void> dispose() async {}

  @override
  VideoPlayerValue get value => VideoPlayerValue.uninitialized();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A fake controller that reports `isInitialized: true` so the player
/// renders its real playback surface. Records calls for assertion.
///
/// Note: the underlying `VideoPlayer` widget still hits the platform
/// channel and won't paint a real texture in tests — but the Semantics
/// tree, FocusableActionDetector shortcuts, and GestureDetector tap
/// targets all exist in the widget tree regardless, and that's what the
/// three a11y/keyboard tests exercise.
class _InitializedController implements VideoPlayerController {
  bool _playing = false;
  Duration? _lastSeek;
  double _volume = 1.0;
  bool _looping = false;
  int closedCaptionFileSetCount = 0;
  bool closedCaptionFileSetToNull = false;

  /// Reported as `kUninitializedPlayerId` (-1) so the real `VideoPlayer`
  /// widget renders an empty container instead of trying to attach a
  /// platform texture. Semantics + FocusableActionDetector still mount.
  @override
  int get playerId => VideoPlayerController.kUninitializedPlayerId;

  @override
  Future<void> play() async {
    _playing = true;
  }

  @override
  Future<void> pause() async {
    _playing = false;
  }

  @override
  Future<void> seekTo(Duration position) async {
    _lastSeek = position;
  }

  @override
  Future<void> setVolume(double v) async {
    _volume = v;
  }

  @override
  Future<void> setLooping(bool v) async {
    _looping = v;
  }

  @override
  Future<void> setClosedCaptionFile(
      Future<ClosedCaptionFile?>? closedCaptionFile) async {
    closedCaptionFileSetCount++;
    closedCaptionFileSetToNull = closedCaptionFile == null;
  }

  @override
  Future<void> dispose() async {}

  @override
  VideoPlayerValue get value => VideoPlayerValue.uninitialized().copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 30),
        position: const Duration(seconds: 10),
        size: const Size(640, 360),
        isPlaying: _playing,
        volume: _volume,
        isLooping: _looping,
      );

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Records [onCaptionLanguageSelected] calls for assertion.
class _RecordingVideoSink implements VideoAnalyticsSink {
  final List<(String, String?)> captionSelections = [];

  @override
  void onVideoView(String videoId) {}
  @override
  void onVideoComplete(String videoId, int durationMs) {}
  @override
  void onCaptionLanguageSelected(String videoId, String? language) =>
      captionSelections.add((videoId, language));
}

VideoSummary _sampleVideo() => VideoSummary(
      id: 'v1',
      courseId: 'c1',
      title: 'Intro',
      orderIndex: 0,
      status: VideoStatus.ready,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(
        path: '/feed',
        builder: (_, __) => const Scaffold(body: Text('feed')),
      ),
      GoRoute(
        path: '/courses',
        builder: (_, __) =>
            const Scaffold(body: Text('courses', key: Key('test.courses'))),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockVideoRepository videoRepo;
  late _MockEnrollmentRepository enrollmentRepo;

  setUpAll(() {
    // Disable VisibilityDetector's internal update throttle so its
    // pending timer doesn't leak into the next test. Zero means every
    // layout pass publishes synchronously — fine for tests.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    videoRepo = _MockVideoRepository();
    enrollmentRepo = _MockEnrollmentRepository();
    // Make the progress ping a no-op.
    when(() => enrollmentRepo.updateProgress(any(), any(), any()))
        .thenAnswer((_) async {});
  });

  testWidgets('409 CONFLICT → Processing + Refresh button', (tester) async {
    when(() => videoRepo.playback(any())).thenThrow(const ApiException(
      code: 'CONFLICT',
      statusCode: 409,
      message: 'not ready',
    ));
    when(() => videoRepo.invalidate(any())).thenReturn(null);

    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => _UninitializedController(),
    );

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Processing…'), findsOneWidget);
    expect(find.byKey(const Key('player.retry')), findsOneWidget);
  });

  testWidgets('403 FORBIDDEN → full-screen "Go home"', (tester) async {
    when(() => videoRepo.playback(any())).thenThrow(const ApiException(
      code: 'FORBIDDEN',
      statusCode: 403,
      message: 'nope',
    ));

    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => _UninitializedController(),
    );

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('player.forbidden')), findsOneWidget);
    expect(find.text('Go home'), findsOneWidget);
  });

  testWidgets('404 NOT_FOUND → "Video unavailable"', (tester) async {
    when(() => videoRepo.playback(any())).thenThrow(const ApiException(
      code: 'NOT_FOUND',
      statusCode: 404,
      message: 'gone',
    ));

    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => _UninitializedController(),
    );

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('player.unavailable')), findsOneWidget);
  });

  testWidgets('successful playback-info resolution → init error surfaces '
      'unknown state (platform channel stays untouched)', (tester) async {
    when(() => videoRepo.playback(any())).thenAnswer((_) async => PlaybackInfo(
          masterPlaylistUrl: 'http://cdn/master.m3u8',
          expiresAt: DateTime.utc(2030, 1, 1),
        ));

    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => _UninitializedController(),
    );

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
    )));
    await tester.pumpAndSettle();

    // The fake controller reports isInitialized=false → unknown-error path.
    expect(find.byKey(const Key('player.error')), findsOneWidget);
    // Back button MUST be rendered alongside Retry — earlier versions
    // only offered Retry, trapping the user on a failed video when the
    // feed has no appbar.
    expect(find.byKey(const Key('player.error.back')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Back on unknown-error deep-linked screen falls through '
      'to /courses (no parent route to pop)', (tester) async {
    when(() => videoRepo.playback(any())).thenAnswer((_) async => PlaybackInfo(
          masterPlaylistUrl: 'http://cdn/master.m3u8',
          expiresAt: DateTime.utc(2030, 1, 1),
        ));

    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => _UninitializedController(),
    );

    // The default _wrap() hosts the player at `/` with nothing beneath it,
    // so `Navigator.canPop()` is false and the Back handler must fall
    // through to GoRouter.go('/courses').
    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('player.error.back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test.courses')), findsOneWidget);
  });

  // ---------------------------------------------------------------
  // Slice V3: accessibility + keyboard / DPAD support
  // ---------------------------------------------------------------

  testWidgets('Play button exposes a "Play" Semantics label and toggles '
      'the controller when a screen reader activates it', (tester) async {
    when(() => videoRepo.playback(any())).thenAnswer((_) async => PlaybackInfo(
          masterPlaylistUrl: 'http://cdn/master.m3u8',
          expiresAt: DateTime.utc(2030, 1, 1),
        ));

    final controller = _InitializedController();
    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => controller,
    );

    // Enable the semantics tree for this test so `find.semantics` and
    // `tester.semantics.tap` resolve actual SemanticsNodes.
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
    )));
    await tester.pumpAndSettle();

    // Controller starts paused → screen readers see "Play".
    expect(find.bySemanticsLabel('Play'), findsOneWidget);

    // Invoke the semantic tap action (what TalkBack does on activation),
    // not a pointer tap — the play/pause semantics layer deliberately
    // sits behind an IgnorePointer so it never competes with the outer
    // GestureDetector for physical touches.
    tester.semantics.tap(find.semantics.byLabel('Play'));
    await tester.pumpAndSettle();

    expect(controller._playing, isTrue);
    semanticsHandle.dispose();
  });

  testWidgets('Space key toggles play/pause via FocusableActionDetector '
      'shortcut', (tester) async {
    when(() => videoRepo.playback(any())).thenAnswer((_) async => PlaybackInfo(
          masterPlaylistUrl: 'http://cdn/master.m3u8',
          expiresAt: DateTime.utc(2030, 1, 1),
        ));

    final controller = _InitializedController();
    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => controller,
    );

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
    )));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(controller._playing, isTrue);
  });

  testWidgets('Left arrow seeks backwards 10 seconds from the current '
      'position', (tester) async {
    when(() => videoRepo.playback(any())).thenAnswer((_) async => PlaybackInfo(
          masterPlaylistUrl: 'http://cdn/master.m3u8',
          expiresAt: DateTime.utc(2030, 1, 1),
        ));

    final controller = _InitializedController();
    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => controller,
    );

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
    )));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    // Fake starts at position 10s, so -10s clamps to 0.
    expect(controller._lastSeek, const Duration(seconds: 0));
  });

  testWidgets('off-screen player (visibleFraction=0) does not consume space '
      'keystrokes — focus follows visibility', (tester) async {
    // Regression for a plan-validation finding: prior code used
    // `FocusableActionDetector(autofocus: true)`, so every preloaded feed
    // player grabbed focus on mount and later siblings would steal focus
    // from the visible one. The fix replaced autofocus with an explicit
    // FocusNode that only requests focus when _onVisibilityChanged flips
    // `_isVisible` to true. This test wraps the player in a zero-sized
    // container so VisibilityDetector reports visibleFraction=0 and
    // confirms keystrokes sent while the player is off-screen do NOT
    // toggle playback.
    when(() => videoRepo.playback(any())).thenAnswer((_) async => PlaybackInfo(
          masterPlaylistUrl: 'http://cdn/master.m3u8',
          expiresAt: DateTime.utc(2030, 1, 1),
        ));

    final controller = _InitializedController();
    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => controller,
    );

    // Wrap the player in a zero-sized overflow box so the layout reports
    // the detector as not visible.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox.shrink(
          child: OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: 0,
            maxHeight: 0,
            child: LearnVideoPlayer(
              video: _sampleVideo(),
              courseId: 'c1',
              videoRepo: videoRepo,
              enrollmentRepo: enrollmentRepo,
              controllerCache: cache,
              autoPlayWhenVisible: false,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(controller._playing, isFalse,
        reason: 'an off-screen player must not hold keyboard focus');
  });

  // ---------- Slice-H follow-up — data-saver on cellular ----------

  testWidgets(
      'data-saver ON + cellular: player does not auto-play; snackbar surfaces',
      (tester) async {
    // Sidestep secure-storage platform channel for the SettingsStore
    // the cubit wraps.
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();

    when(() => videoRepo.playback(any())).thenAnswer(
      (_) async => PlaybackInfo(
        masterPlaylistUrl: 'https://example.test/hls/v1/master.m3u8',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final controller = _InitializedController();
    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => controller,
    );

    // Real SettingsCubit with data-saver persisted ON.
    final store = SettingsStore(const FlutterSecureStorage());
    await store.writeDataSaver(true);
    final cubit = SettingsCubit(store: store);
    await cubit.load();
    expect(cubit.state.dataSaver, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: Scaffold(
            body: LearnVideoPlayer(
              video: _sampleVideo(),
              courseId: 'c1',
              videoRepo: videoRepo,
              enrollmentRepo: enrollmentRepo,
              controllerCache: cache,
              connectivity: _FakeConnectivity(const [ConnectivityResult.mobile]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller._playing, isFalse,
        reason: 'data-saver must suppress auto-play on cellular');
    expect(
      find.byKey(const Key('player.dataSaver.cellularSnackbar')),
      findsOneWidget,
    );

    await cubit.close();
  });

  testWidgets(
      'data-saver ON + Wi-Fi: player auto-plays normally (no suppression)',
      (tester) async {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();

    when(() => videoRepo.playback(any())).thenAnswer(
      (_) async => PlaybackInfo(
        masterPlaylistUrl: 'https://example.test/hls/v1/master.m3u8',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final controller = _InitializedController();
    final cache = VideoControllerCache(
      capacity: 3,
      factory: (_) async => controller,
    );

    final store = SettingsStore(const FlutterSecureStorage());
    await store.writeDataSaver(true);
    final cubit = SettingsCubit(store: store);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: Scaffold(
            body: LearnVideoPlayer(
              video: _sampleVideo(),
              courseId: 'c1',
              videoRepo: videoRepo,
              enrollmentRepo: enrollmentRepo,
              controllerCache: cache,
              connectivity: _FakeConnectivity(const [ConnectivityResult.wifi]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller._playing, isTrue,
        reason: 'Wi-Fi transport should not trigger data-saver suppression');
    expect(
      find.byKey(const Key('player.dataSaver.cellularSnackbar')),
      findsNothing,
    );

    await cubit.close();
  });

  // ---------- Slice C — caption wiring ----------

  testWidgets('CC button is rendered when captions.isNotEmpty', (tester) async {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    when(() => videoRepo.playback(any()))
        .thenAnswer((_) async => playbackWithCaptions());

    final controller = _InitializedController();
    final cache =
        VideoControllerCache(capacity: 3, factory: (_) async => controller);

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
      captionLoader: fakeCaptionLoader(),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('player.cc')), findsOneWidget);
  });

  testWidgets('CC button is NOT rendered when captions.isEmpty', (tester) async {
    when(() => videoRepo.playback(any())).thenAnswer(
      (_) async => PlaybackInfo(
        masterPlaylistUrl: 'https://cdn.test/master.m3u8',
        expiresAt: DateTime.utc(2030, 1, 1),
      ),
    );

    final controller = _InitializedController();
    final cache =
        VideoControllerCache(capacity: 3, factory: (_) async => controller);

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('player.cc')), findsNothing);
  });

  testWidgets(
      'captionsDefault:true + matching captionLanguage → captions applied on load',
      (tester) async {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    when(() => videoRepo.playback(any()))
        .thenAnswer((_) async => playbackWithCaptions());

    final controller = _InitializedController();
    final cache =
        VideoControllerCache(capacity: 3, factory: (_) async => controller);

    final store = SettingsStore(const FlutterSecureStorage());
    await store.writeCaptionsDefault(true);
    await store.writeCaptionLanguage('en');
    final cubit = SettingsCubit(store: store);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: Scaffold(
            body: LearnVideoPlayer(
              video: _sampleVideo(),
              courseId: 'c1',
              videoRepo: videoRepo,
              enrollmentRepo: enrollmentRepo,
              controllerCache: cache,
              autoPlayWhenVisible: false,
              captionLoader: fakeCaptionLoader(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      controller.closedCaptionFileSetCount,
      greaterThan(0),
      reason: 'captions should be applied when captionsDefault + language match',
    );
    await cubit.close();
  });

  testWidgets(
      '404 on caption load does NOT crash the player AND invalidates playback cache',
      (tester) async {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    when(() => videoRepo.playback(any()))
        .thenAnswer((_) async => playbackWithCaptions());
    when(() => videoRepo.invalidate(any())).thenReturn(null);

    final controller = _InitializedController();
    final cache =
        VideoControllerCache(capacity: 3, factory: (_) async => controller);

    final store = SettingsStore(const FlutterSecureStorage());
    await store.writeCaptionsDefault(true);
    await store.writeCaptionLanguage('en');
    final cubit = SettingsCubit(store: store);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: Scaffold(
            body: LearnVideoPlayer(
              video: _sampleVideo(),
              courseId: 'c1',
              videoRepo: videoRepo,
              enrollmentRepo: enrollmentRepo,
              controllerCache: cache,
              autoPlayWhenVisible: false,
              captionLoader: notFoundCaptionLoader(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Player is still rendering (no error state) — 404 was swallowed.
    expect(find.byKey(const Key('player.error')), findsNothing);

    // videoRepo.invalidate() must have been called once for the 404 path.
    verify(() => videoRepo.invalidate(any())).called(1);
    await cubit.close();
  });

  testWidgets(
      'CC button tap → picker returns selected language → analyticsSink emits',
      (tester) async {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    when(() => videoRepo.playback(any()))
        .thenAnswer((_) async => playbackWithCaptions());
    when(() => videoRepo.invalidate(any())).thenReturn(null);

    final controller = _InitializedController();
    final cache =
        VideoControllerCache(capacity: 3, factory: (_) async => controller);

    final sink = _RecordingVideoSink();

    await tester.pumpWidget(_wrap(LearnVideoPlayer(
      video: _sampleVideo(),
      courseId: 'c1',
      videoRepo: videoRepo,
      enrollmentRepo: enrollmentRepo,
      controllerCache: cache,
      autoPlayWhenVisible: false,
      captionLoader: fakeCaptionLoader(),
      analyticsSink: sink,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('player.cc')), findsOneWidget);

    await tester.tap(find.byKey(const Key('player.cc')));
    await tester.pumpAndSettle();

    // The picker sheet should be showing — tap the 'en' language row.
    expect(find.byKey(const Key('captionPicker.lang.en')), findsOneWidget);
    await tester.tap(find.byKey(const Key('captionPicker.lang.en')));
    await tester.pumpAndSettle();

    // Analytics event must have been emitted.
    expect(sink.captionSelections, hasLength(1));
    expect(sink.captionSelections.first.$1, 'v1');
    expect(sink.captionSelections.first.$2, 'en');
  });
}

