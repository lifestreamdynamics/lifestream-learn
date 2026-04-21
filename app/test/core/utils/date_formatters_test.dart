import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/utils/date_formatters.dart';

void main() {
  group('DateTimeX.toUtcIso8601', () {
    test('UTC instant round-trips to ISO-8601 with Z suffix', () {
      final dt = DateTime.utc(2026, 4, 19, 12, 34, 56, 789);
      expect(dt.toUtcIso8601(), '2026-04-19T12:34:56.789Z');
    });

    test('local time is converted to UTC before formatting', () {
      final local = DateTime(2026, 4, 19, 12, 34, 56, 789);
      expect(local.toUtcIso8601(), local.toUtc().toIso8601String());
    });

    test('matches `toUtc().toIso8601String()` exactly', () {
      final samples = <DateTime>[
        DateTime.utc(1970, 1, 1),
        DateTime.utc(2026, 4, 19, 23, 59, 59, 999),
        DateTime(2026, 4, 19),
      ];
      for (final dt in samples) {
        expect(dt.toUtcIso8601(), dt.toUtc().toIso8601String());
      }
    });
  });

  group('formatMemberSinceMonthYear', () {
    test('null -> empty string (caller renders unconditionally)', () {
      expect(formatMemberSinceMonthYear(null), '');
    });

    test('renders "<Month> <year>" in local time', () {
      // Pick a UTC date that stays in the same month when converted to
      // any plausible local timezone (mid-April, well away from
      // month boundaries).
      final dt = DateTime.utc(2026, 4, 15, 12);
      expect(formatMemberSinceMonthYear(dt), 'April 2026');
    });

    test('handles all 12 months', () {
      for (int m = 1; m <= 12; m++) {
        // Day 15 avoids TZ-rollover flakiness on month boundaries.
        final dt = DateTime.utc(2026, m, 15, 12);
        expect(formatMemberSinceMonthYear(dt), isNotEmpty);
      }
    });
  });
}
