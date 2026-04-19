import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/designer_application.dart';
import 'package:lifestream_learn_app/data/repositories/admin_designer_application_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

Map<String, dynamic> _appJson(String id, {String status = 'PENDING'}) =>
    <String, dynamic>{
      'id': id,
      'userId': 'u$id',
      'status': status,
      'note': null,
      'reviewerNote': null,
      'submittedAt': '2026-04-01T00:00:00.000Z',
      'reviewedAt': null,
      'reviewedBy': null,
    };

void main() {
  group('AdminDesignerApplicationRepository.list', () {
    test('passes status + cursor + limit as query', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = AdminDesignerApplicationRepository(dio);
      adapter.enqueueJson(<String, dynamic>{
        'items': [_appJson('a1'), _appJson('a2')],
        'nextCursor': 'abc',
        'hasMore': true,
      });

      final page = await repo.list(status: 'PENDING', cursor: 'c1', limit: 10);
      expect(page.items, hasLength(2));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'abc');

      final req = adapter.requestLog.single;
      expect(req.path, '/api/admin/designer-applications');
      expect(req.queryParameters['status'], 'PENDING');
      expect(req.queryParameters['cursor'], 'c1');
      expect(req.queryParameters['limit'], 10);
    });
  });

  group('AdminDesignerApplicationRepository.review', () {
    test('PATCH with APPROVED + reviewerNote', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = AdminDesignerApplicationRepository(dio);
      adapter.enqueueJson(_appJson('a1', status: 'APPROVED'));

      final result = await repo.review(
        'a1',
        status: AppStatus.approved,
        reviewerNote: 'welcome',
      );
      expect(result.status, AppStatus.approved);

      final req = adapter.requestLog.single;
      expect(req.path, '/api/admin/designer-applications/a1');
      expect(req.method, 'PATCH');
      final body = req.data as Map<String, dynamic>;
      expect(body['status'], 'APPROVED');
      expect(body['reviewerNote'], 'welcome');
    });

    test('PATCH with REJECTED omits empty reviewerNote', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = AdminDesignerApplicationRepository(dio);
      adapter.enqueueJson(_appJson('a1', status: 'REJECTED'));
      await repo.review('a1', status: AppStatus.rejected);

      final req = adapter.requestLog.single;
      final body = req.data as Map<String, dynamic>;
      expect(body['status'], 'REJECTED');
      expect(body.containsKey('reviewerNote'), isFalse);
    });

    test('review(PENDING) is a programming error', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = AdminDesignerApplicationRepository(dio);
      expect(
        () => repo.review('a1', status: AppStatus.pending),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
