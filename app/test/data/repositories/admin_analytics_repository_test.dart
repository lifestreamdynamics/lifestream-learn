import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/repositories/admin_analytics_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

void main() {
  group('AdminAnalyticsRepository.course', () {
    test('GET /api/admin/analytics/courses/:id and decodes aggregate',
        () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = AdminAnalyticsRepository(dio);

      adapter.enqueueJson(<String, dynamic>{
        'totalViews': 12,
        'completionRate': 0.5,
        'perCueTypeAccuracy': <String, dynamic>{
          'MCQ': 0.8,
          'BLANKS': null,
          'MATCHING': 0.6,
        },
      });

      final result = await repo.course('c1');
      expect(result.totalViews, 12);
      expect(result.completionRate, 0.5);
      expect(result.perCueTypeAccuracy.mcq, 0.8);
      expect(result.perCueTypeAccuracy.blanks, isNull);
      expect(result.perCueTypeAccuracy.matching, 0.6);

      final req = adapter.requestLog.single;
      expect(req.path, '/api/admin/analytics/courses/c1');
      expect(req.method, 'GET');
    });
  });
}
