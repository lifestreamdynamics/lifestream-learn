import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/data/repositories/enrollment_repository.dart';
import 'package:lifestream_learn_app/data/repositories/video_repository.dart';
import 'package:lifestream_learn_app/features/feed/video_controller_cache.dart';
import 'package:lifestream_learn_app/features/player/learn_video_player.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _MockVideoRepository extends Mock implements VideoRepository {}

class _MockEnrollmentRepository extends Mock implements EnrollmentRepository {}

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
}
