import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/repositories/feed_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

Map<String, dynamic> _videoJson(String id) => <String, dynamic>{
      'id': id,
      'courseId': 'c1',
      'title': 'video $id',
      'orderIndex': 0,
      'status': 'READY',
      'durationMs': 30000,
      'createdAt': '2026-01-01T00:00:00.000Z',
    };

Map<String, dynamic> _entryJson(String id) => <String, dynamic>{
      'video': _videoJson(id),
      'course': <String, dynamic>{
        'id': 'c1',
        'title': 'Course',
        'coverImageUrl': null,
      },
      'cueCount': 0,
      'hasAttempted': false,
    };

void main() {
  group('FeedRepository.page', () {
    test('passes limit and no cursor on first page', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = FeedRepository(dio);

      adapter.enqueueJson(<String, dynamic>{
        'items': [_entryJson('v1'), _entryJson('v2')],
        'nextCursor': 'cur-1',
        'hasMore': true,
      });

      final page = await repo.page(limit: 20);
      expect(page.items.length, 2);
      expect(page.nextCursor, 'cur-1');
      expect(page.hasMore, true);

      final req = adapter.requestLog.single;
      expect(req.path, '/api/feed');
      expect(req.queryParameters['limit'], 20);
      expect(req.queryParameters.containsKey('cursor'), false);
    });

    test('passes cursor through on subsequent pages', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = FeedRepository(dio);

      adapter.enqueueJson(<String, dynamic>{
        'items': [_entryJson('v3')],
        'hasMore': false,
      });

      await repo.page(cursor: 'cur-xyz', limit: 10);
      final req = adapter.requestLog.single;
      expect(req.queryParameters['cursor'], 'cur-xyz');
      expect(req.queryParameters['limit'], 10);
    });
  });
}
