import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/utils/duration_formatters.dart';

void main() {
  group('formatDurationMs', () {
    test('zero → 00:00', () {
      expect(formatDurationMs(0), '00:00');
    });

    test('under one second → 00:00', () {
      expect(formatDurationMs(500), '00:00');
    });

    test('exactly one minute → 01:00', () {
      expect(formatDurationMs(60_000), '01:00');
    });

    test('one minute thirty-four seconds → 01:34', () {
      expect(formatDurationMs(94_000), '01:34');
    });

    test('nine minutes → pads minutes, 09:00', () {
      expect(formatDurationMs(540_000), '09:00');
    });

    test('ten minutes → 10:00 (no hour overflow yet)', () {
      expect(formatDurationMs(600_000), '10:00');
    });

    test('negative value clamped to zero', () {
      // VideoPlayer.position briefly reports negative during seeks; we
      // render that as 00:00 instead of a leaking minus sign.
      expect(formatDurationMs(-1_000), '00:00');
    });
  });
}
