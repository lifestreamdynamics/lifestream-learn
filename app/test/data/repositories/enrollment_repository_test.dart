import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/repositories/enrollment_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

void main() {
  group('EnrollmentRepository.updateProgress', () {
    test('sends PATCH with body on success (204 tolerated)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = EnrollmentRepository(dio);

      adapter.enqueueEmpty204();
      await repo.updateProgress('c1', 'v1', 12345);

      final req = adapter.requestLog.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/enrollments/c1/progress');
      expect(req.data, <String, dynamic>{
        'lastVideoId': 'v1',
        'lastPosMs': 12345,
      });
    });

    test('silently swallows 4xx errors (does not throw)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = EnrollmentRepository(dio);

      adapter.enqueueError(400, <String, dynamic>{
        'error': 'VALIDATION_ERROR',
        'message': 'nope',
      });
      await expectLater(
        repo.updateProgress('c1', 'v1', 0),
        completes,
      );
    });

    test('silently swallows 5xx errors (does not throw)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = EnrollmentRepository(dio);

      adapter.enqueueError(500, <String, dynamic>{
        'error': 'INTERNAL_ERROR',
        'message': 'db down',
      });
      await expectLater(
        repo.updateProgress('c1', 'v1', 999),
        completes,
      );
    });
  });
}
