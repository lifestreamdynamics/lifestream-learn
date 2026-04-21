import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/analytics/analytics_event.dart';

/// These tests protect the JSON wire shape agreed with the backend's
/// `/api/events` Zod schema (`api/src/validators/analytics.validators.ts`).
/// That schema is `.strict()` — unknown keys are rejected — and its
/// optional fields use `.string().uuid().optional()` which accepts
/// "key missing" but NOT an explicit `null`. Null-valued keys in the
/// serialized JSON cause a 400 VALIDATION_ERROR on the server, which
/// the buffer drops. A regression here is silent data loss on every
/// `session_start` / `session_end`.
void main() {
  group('AnalyticsEvent.toJson omits null optional fields', () {
    test('event with no videoId/cueId/payload serializes to just the two required fields', () {
      const event = AnalyticsEvent(
        eventType: 'session_start',
        occurredAt: '2026-04-20T00:00:00.000Z',
      );

      final json = event.toJson();

      expect(json.keys, unorderedEquals(<String>['eventType', 'occurredAt']));
      expect(json['eventType'], 'session_start');
      expect(json['occurredAt'], '2026-04-20T00:00:00.000Z');
      expect(json.containsKey('videoId'), isFalse);
      expect(json.containsKey('cueId'), isFalse);
      expect(json.containsKey('payload'), isFalse);
    });

    test('event with only videoId includes videoId but still omits cueId/payload', () {
      const event = AnalyticsEvent(
        eventType: 'video_view',
        occurredAt: '2026-04-20T00:00:01.000Z',
        videoId: '11111111-1111-4111-8111-111111111111',
      );

      final json = event.toJson();

      expect(
        json.keys,
        unorderedEquals(<String>['eventType', 'occurredAt', 'videoId']),
      );
      expect(json['videoId'], '11111111-1111-4111-8111-111111111111');
    });

    test('event with payload keeps the map even when other optionals are null', () {
      const event = AnalyticsEvent(
        eventType: 'cue_shown',
        occurredAt: '2026-04-20T00:00:02.000Z',
        payload: <String, dynamic>{'cueType': 'MCQ'},
      );

      final json = event.toJson();

      expect(
        json.keys,
        unorderedEquals(<String>['eventType', 'occurredAt', 'payload']),
      );
      expect(json['payload'], const <String, dynamic>{'cueType': 'MCQ'});
    });

    test('round-trip fromJson(toJson(e)) preserves all fields', () {
      const original = AnalyticsEvent(
        eventType: 'cue_answered',
        occurredAt: '2026-04-20T00:00:03.000Z',
        videoId: '22222222-2222-4222-8222-222222222222',
        cueId: '33333333-3333-4333-8333-333333333333',
        payload: <String, dynamic>{'correct': true},
      );

      final restored = AnalyticsEvent.fromJson(original.toJson());

      expect(restored, original);
    });
  });
}
