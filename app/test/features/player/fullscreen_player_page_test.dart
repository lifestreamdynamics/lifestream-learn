import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/features/player/fullscreen_player_page.dart';
import 'package:video_player/video_player.dart';

/// Minimal fake controller — reports initialized with a landscape size
/// so the page renders the video area correctly. Uses the uninitialized
/// player ID so no platform texture is requested.
class _FakeController implements VideoPlayerController {
  @override
  int get playerId => VideoPlayerController.kUninitializedPlayerId;

  @override
  VideoPlayerValue get value => VideoPlayerValue.uninitialized().copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 60),
        size: const Size(1280, 720),
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
}

class _PopObserver extends NavigatorObserver {
  _PopObserver({required this.onDidPop});
  final VoidCallback onDidPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onDidPop();
  }
}
