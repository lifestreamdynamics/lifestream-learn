import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/analytics/analytics_event.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/repositories/events_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

void main() {
  group('EventsRepository.submitBatch', () {
    test('POSTs JSON array to /api/events', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = EventsRepository(dio);
      adapter.enqueueJson(<String, dynamic>{'ingested': 2}, statusCode: 202);

      await repo.submitBatch([
        const AnalyticsEvent(
          eventType: 'video_view',
          occurredAt: '2026-04-19T00:00:00Z',
        ),
        const AnalyticsEvent(
          eventType: 'cue_shown',
          occurredAt: '2026-04-19T00:00:01Z',
          payload: <String, dynamic>{'cueType': 'MCQ'},
        ),
      ]);

      final req = adapter.requestLog.single;
      expect(req.path, '/api/events');
      expect(req.method, 'POST');
      expect(req.data, isA<List<dynamic>>());
      expect((req.data as List).length, 2);
    });

    test('empty batch → no HTTP call', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = EventsRepository(dio);
      await repo.submitBatch(const []);
      expect(adapter.requestLog, isEmpty);
    });

    test('400 → ApiException(400)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = EventsRepository(dio);
      adapter.enqueueError(400, <String, dynamic>{
        'error': 'VALIDATION_ERROR',
        'message': 'bad event',
      });

      expect(
        repo.submitBatch([
          const AnalyticsEvent(
            eventType: 'x',
            occurredAt: '2026-04-19T00:00:00Z',
          ),
        ]),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
      );
    });

    test('500 → ApiException(500)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = EventsRepository(dio);
      adapter.enqueueError(500, <String, dynamic>{
        'error': 'INTERNAL_ERROR',
        'message': 'boom',
      });

      expect(
        repo.submitBatch([
          const AnalyticsEvent(
            eventType: 'x',
            occurredAt: '2026-04-19T00:00:00Z',
          ),
        ]),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)),
      );
    });
  });
}
