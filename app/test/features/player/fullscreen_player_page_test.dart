import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/features/player/fullscreen_player_page.dart';
import 'package:video_player/video_player.dart';

/// Minimal fake controller. Defaults to a portrait source so the
/// `FullscreenPlayerPage`'s landscape-only `OrientationBuilder` branch
/// (which schedules post-frame callbacks chasing the orientation
/// signal) is skipped in tests. Pass [size] explicitly to exercise the
/// landscape branch. Uses the uninitialized player ID so no platform
/// texture is requested.
class _FakeController implements VideoPlayerController {
  _FakeController({this.size = const Size(720, 1280)});
  final Size size;

  @override
  int get playerId => VideoPlayerController.kUninitializedPlayerId;

  @override
  VideoPlayerValue get value => VideoPlayerValue.uninitialized().copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 60),
        size: size,
      );

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setVolume(double v) async {}

  @override
  Future<void> setLooping(bool v) async {}

  @override
  Future<void> setClosedCaptionFile(
      Future<ClosedCaptionFile?>? f) async {}

  @override
  Future<void> dispose() async {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  // SystemChrome.setPreferredOrientations / setEnabledSystemUIMode invoke
  // 'flutter/platform' via the platform channel. In the test environment
  // these are ignored (MissingPluginException is caught internally by
  // SystemChrome), so no mock setup is required.
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders PopScope in the widget tree', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenPlayerPage(
          controller: _FakeController(),
          title: 'Test Video',
        ),
      ),
    );
    // PopScope is present — look for the canPop: false key indicator.
    expect(find.byWidgetPredicate((w) => w is PopScope), findsWidgets);
  });

  testWidgets('renders VideoPlayer widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenPlayerPage(
          controller: _FakeController(),
          title: 'Test Video',
        ),
      ),
    );
    expect(find.byType(VideoPlayer), findsOneWidget);
  });

  testWidgets('renders exit IconButton with key fullscreen.exit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenPlayerPage(
          controller: _FakeController(),
          title: 'Test Video',
        ),
      ),
    );
    expect(find.byKey(const Key('fullscreen.exit')), findsOneWidget);
  });

  testWidgets('tapping exit button pops the route', (tester) async {
    bool popped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => FullscreenPlayerPage(
                    controller: _FakeController(),
                    title: 'Test Video',
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
        navigatorObservers: [
          _PopObserver(onDidPop: () => popped = true),
        ],
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fullscreen.exit')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fullscreen.exit')));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
  });

  testWidgets('landscape source path renders without infinite-loop',
      (tester) async {
    // The landscape branch wraps the page in an OrientationBuilder that
    // schedules post-frame callbacks. Use bounded pump() so we don't chase
    // those callbacks forever, and assert the static parts render.
    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenPlayerPage(
          controller: _FakeController(size: const Size(1280, 720)),
          title: 'Landscape Video',
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('fullscreen.exit')), findsOneWidget);
    expect(find.byType(VideoPlayer), findsOneWidget);
  });
}

class _PopObserver extends NavigatorObserver {
  _PopObserver({required this.onDidPop});
  final VoidCallback onDidPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onDidPop();
  }
}
