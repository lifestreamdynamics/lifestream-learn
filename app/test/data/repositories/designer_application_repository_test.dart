import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/designer_application.dart';
import 'package:lifestream_learn_app/data/repositories/designer_application_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

Map<String, dynamic> _appJson({String status = 'PENDING'}) => <String, dynamic>{
      'id': 'a1',
      'userId': 'u1',
      'status': status,
      'note': 'pls',
      'reviewerNote': null,
      'submittedAt': '2026-04-01T00:00:00.000Z',
      'reviewedAt': null,
      'reviewedBy': null,
    };

void main() {
  group('DesignerApplicationRepository.getMy', () {
    test('200 returns the application', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = DesignerApplicationRepository(dio);
      adapter.enqueueJson(_appJson());

      final app = await repo.getMy();
      expect(app, isNotNull);
      expect(app!.status, AppStatus.pending);
      expect(adapter.requestLog.single.path, '/api/designer-applications/me');
    });

    test('404 → null', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = DesignerApplicationRepository(dio);
      adapter.enqueueError(404, <String, dynamic>{
        'error': 'NOT_FOUND',
        'message': 'No application',
      });

      final app = await repo.getMy();
      expect(app, isNull);
    });

    test('500 → ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = DesignerApplicationRepository(dio);
      adapter.enqueueError(500, <String, dynamic>{
        'error': 'INTERNAL_ERROR',
        'message': 'boom',
      });

      expect(repo.getMy(), throwsA(isA<ApiException>()));
    });
  });

  group('DesignerApplicationRepository.submit', () {
    test('sends `note` when non-empty', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = DesignerApplicationRepository(dio);
      adapter.enqueueJson(_appJson(), statusCode: 201);

      await repo.submit(note: 'hello');
      final req = adapter.requestLog.single;
      expect(req.path, '/api/designer-applications');
      expect(req.method, 'POST');
      expect((req.data as Map)['note'], 'hello');
    });

    test('omits `note` when null/empty', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = DesignerApplicationRepository(dio);
      adapter.enqueueJson(_appJson(), statusCode: 201);

      await repo.submit();
      final req = adapter.requestLog.single;
      expect((req.data as Map).containsKey('note'), isFalse);
    });

    test('409 throws ApiException(statusCode=409)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = DesignerApplicationRepository(dio);
      adapter.enqueueError(409, <String, dynamic>{
        'error': 'CONFLICT',
        'message': 'A pending application already exists',
      });

      expect(
        repo.submit(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
    });
  });
}
