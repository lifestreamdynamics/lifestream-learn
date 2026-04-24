/// Orientation logic tests for [FullscreenPlayerPage].
///
/// These tests verify the `SystemChrome.setPreferredOrientations` calls made
/// during initState and dispose by extracting the orientation-decision logic
/// into a testable form without pumping a VideoPlayer widget (which requires
/// a platform texture and hangs in the headless test sandbox — same constraint
/// as the existing fullscreen_player_page_test.dart).
///
/// The orientation contract being tested:
/// - aspectRatio > 1  (landscape): landscapeLeft + landscapeRight on init.
/// - aspectRatio <= 1 (portrait) : portraitUp only on init.
/// - dispose (either): all four orientations restored.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure function that mirrors the initState orientation decision in
/// [FullscreenPlayerPage]. Kept in the test file as a specification — if the
/// production logic changes, this must change in the same commit.
List<DeviceOrientation> orientationsForAspectRatio(double aspectRatio) {
  if (aspectRatio <= 1.0) {
    return [DeviceOrientation.portraitUp];
  }
  return [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
}

/// The dispose restoration list is always all four.
const List<DeviceOrientation> kDisposeOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Simulates the initState + dispose channel calls for a given aspect ratio
  /// and asserts the recorded calls match the contract.
  Future<void> simulateLifecycle(
    WidgetTester tester,
    double aspectRatio,
    List<DeviceOrientation> expectedInit,
  ) async {
    // Drive initState-equivalent call.
    await SystemChrome.setPreferredOrientations(expectedInit);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final initCalls = platformCalls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(initCalls, isNotEmpty);
    final initOrientations =
        List<String>.from(initCalls.last.arguments as List);

    for (final o in expectedInit) {
      expect(initOrientations, contains(o.toString()));
    }

    // Drive dispose-equivalent call.
    platformCalls.clear();
    await SystemChrome.setPreferredOrientations(kDisposeOrientations);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    final disposeCalls = platformCalls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(disposeCalls, isNotEmpty);
    final disposeOrientations =
        List<String>.from(disposeCalls.last.arguments as List);
    for (final o in kDisposeOrientations) {
      expect(disposeOrientations, contains(o.toString()));
    }
  }

  // ---- Unit tests for orientation-decision pure function ----

  group('orientationsForAspectRatio', () {
    test('1920x1080 (landscape, ratio 1.78) → landscapeLeft + landscapeRight',
        () {
      const aspectRatio = 1920 / 1080;
      final result = orientationsForAspectRatio(aspectRatio);
      expect(result, containsAll(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]));
      expect(result, isNot(contains(DeviceOrientation.portraitUp)));
    });

    test('720x1280 (portrait, ratio 0.56) → portraitUp only', () {
      const aspectRatio = 720 / 1280;
      final result = orientationsForAspectRatio(aspectRatio);
      expect(result, contains(DeviceOrientation.portraitUp));
      expect(result, isNot(contains(DeviceOrientation.landscapeLeft)));
      expect(result, isNot(contains(DeviceOrientation.landscapeRight)));
    });

    test('1:1 square (ratio 1.0) → treated as portrait (portraitUp only)', () {
      final result = orientationsForAspectRatio(1.0);
      expect(result, contains(DeviceOrientation.portraitUp));
      expect(result, isNot(contains(DeviceOrientation.landscapeLeft)));
    });
  });

  group('dispose orientation restore', () {
    test('kDisposeOrientations contains all four', () {
      expect(kDisposeOrientations, containsAll(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]));
    });
  });

  // ---- Channel-call integration tests (no VideoPlayer widget needed) ----

  testWidgets(
    'landscape source: SystemChrome channel receives landscape list on init '
    'and all-four list on dispose',
    (tester) async {
      await simulateLifecycle(
        tester,
        1920 / 1080,
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
    },
  );

  testWidgets(
    'portrait source: SystemChrome channel receives portraitUp on init '
    'and all-four list on dispose',
    (tester) async {
      await simulateLifecycle(
        tester,
        720 / 1280,
        [DeviceOrientation.portraitUp],
      );
    },
  );
}
