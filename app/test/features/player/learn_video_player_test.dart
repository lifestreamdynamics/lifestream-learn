import 'package:flutter/material.dart';
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
  });
}
