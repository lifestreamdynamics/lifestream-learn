import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Haptics', () {
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      // Intercept the HapticFeedback platform channel calls.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          log.add(call);
          return null;
        },
      );
    });

    tearDown(() {
      // Restore default handler and reset Haptics state.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      Haptics.enabled = true;
    });

    group('when enabled = true', () {
      setUp(() => Haptics.enabled = true);

      test('selection() sends HapticFeedback.selectionClick', () async {
        await Haptics.selection();
        expect(
          log.where((c) => c.method == 'HapticFeedback.vibrate' ||
              c.method == 'HapticFeedback.selectionClick'),
          isNotEmpty,
        );
      });

      test('light() fires a platform channel call', () async {
        await Haptics.light();
        expect(log, isNotEmpty);
      });

      test('medium() fires a platform channel call', () async {
        await Haptics.medium();
        expect(log, isNotEmpty);
      });
    });

    group('when enabled = false', () {
      setUp(() => Haptics.enabled = false);

      test('selection() does NOT call the platform channel', () async {
        await Haptics.selection();
        expect(log, isEmpty);
      });

      test('light() does NOT call the platform channel', () async {
        await Haptics.light();
        expect(log, isEmpty);
      });

      test('medium() does NOT call the platform channel', () async {
        await Haptics.medium();
        expect(log, isEmpty);
      });
    });
  });
}
