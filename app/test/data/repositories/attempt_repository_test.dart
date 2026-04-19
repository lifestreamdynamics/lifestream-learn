import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/repositories/attempt_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

void main() {
  group('AttemptRepository.submit', () {
    test('POSTs {cueId, response} and decodes the grading result', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = AttemptRepository(dio);

      adapter.enqueueJson(
        <String, dynamic>{
          'attempt': {
            'id': 'a1',
            'userId': 'u1',
            'videoId': 'v1',
            'cueId': 'c1',
            'correct': true,
            'scoreJson': {'selected': 2},
            'submittedAt': '2026-04-19T00:00:00.000Z',
          },
          'correct': true,
          'scoreJson': {'selected': 2},
          'explanation': 'Because reasons.',
        },
        statusCode: 201,
      );

      final result = await repo.submit(
        cueId: 'c1',
        response: <String, dynamic>{'choiceIndex': 2},
      );

      expect(result.correct, isTrue);
      expect(result.explanation, 'Because reasons.');
      expect(result.attempt.id, 'a1');
      expect(result.scoreJson?['selected'], 2);

      final req = adapter.requestLog.single;
      expect(req.path, '/api/attempts');
      expect(req.method, 'POST');
      final body = req.data as Map<String, dynamic>;
      expect(body['cueId'], 'c1');
      expect(body['response'], <String, dynamic>{'choiceIndex': 2});
    });

    test('400 VALIDATION_ERROR surfaces as ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = AttemptRepository(dio);

      adapter.enqueueError(400, <String, dynamic>{
        'error': 'VALIDATION_ERROR',
        'message': 'Invalid response payload',
      });

      await expectLater(
        repo.submit(cueId: 'c1', response: {'bogus': true}),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION_ERROR')),
      );
    });

    test('403 FORBIDDEN surfaces as ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = AttemptRepository(dio);

      adapter.enqueueError(403, <String, dynamic>{
        'error': 'FORBIDDEN',
        'message': 'You do not have access to this cue',
      });

      await expectLater(
        repo.submit(cueId: 'c1', response: {'choiceIndex': 0}),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });
  });
}
