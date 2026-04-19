import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

Map<String, dynamic> _courseJson(String id, {bool published = true}) =>
    <String, dynamic>{
      'id': id,
      'slug': 'c-$id',
      'title': 'Course $id',
      'description': 'Desc',
      'coverImageUrl': null,
      'ownerId': 'o1',
      'published': published,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    };

Map<String, dynamic> _enrollmentJson(String courseId, String id) =>
    <String, dynamic>{
      'id': id,
      'userId': 'u1',
      'courseId': courseId,
      'startedAt': '2026-01-05T00:00:00.000Z',
      'lastVideoId': null,
      'lastPosMs': null,
    };

void main() {
  group('CourseRepository.published', () {
    test('sends published=true and limit', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CourseRepository(dio);

      adapter.enqueueJson(<String, dynamic>{
        'items': [_courseJson('a'), _courseJson('b')],
        'nextCursor': 'cc',
        'hasMore': true,
      });
      final page = await repo.published(limit: 5);
      expect(page.items.length, 2);
      expect(page.hasMore, true);
      expect(page.nextCursor, 'cc');

      final req = adapter.requestLog.single;
      expect(req.path, '/api/courses');
      expect(req.queryParameters['published'], true);
      expect(req.queryParameters['limit'], 5);
    });
  });

  group('CourseRepository.enroll', () {
    test('201 new enrollment returns Enrollment', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CourseRepository(dio);

      adapter.enqueueJson(_enrollmentJson('c1', 'e1'), statusCode: 201);
      final e = await repo.enroll('c1');
      expect(e.id, 'e1');
      expect(e.courseId, 'c1');
    });

    test('200 existing enrollment also returns Enrollment (idempotent)',
        () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CourseRepository(dio);

      adapter.enqueueJson(_enrollmentJson('c1', 'e1'));
      final e = await repo.enroll('c1');
      expect(e.id, 'e1');
    });
  });

  group('CourseRepository.myEnrollments', () {
    test('parses a list response', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CourseRepository(dio);

      adapter.enqueueJson(<Map<String, dynamic>>[
        {
          'id': 'e1',
          'userId': 'u1',
          'courseId': 'c1',
          'startedAt': '2026-01-05T00:00:00.000Z',
          'lastVideoId': 'v1',
          'lastPosMs': 12345,
          'course': <String, dynamic>{
            'id': 'c1',
            'title': 'Course a',
            'slug': 'c-a',
            'coverImageUrl': null,
          },
        },
      ]);
      final rows = await repo.myEnrollments();
      expect(rows.length, 1);
      expect(rows.single.courseId, 'c1');
      expect(rows.single.lastPosMs, 12345);
      expect(rows.single.course.title, 'Course a');
    });

    test('empty list is tolerated', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CourseRepository(dio);

      adapter.enqueueJson(<dynamic>[]);
      final rows = await repo.myEnrollments();
      expect(rows, isEmpty);
    });
  });

  group('CourseRepository.getById', () {
    test('parses course + videos', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CourseRepository(dio);

      adapter.enqueueJson(<String, dynamic>{
        ..._courseJson('c1'),
        'videos': <Map<String, dynamic>>[
          {
            'id': 'v1',
            'title': 'Intro',
            'orderIndex': 0,
            'status': 'READY',
            'durationMs': 60000,
          },
          {
            'id': 'v2',
            'title': 'Next',
            'orderIndex': 1,
            'status': 'TRANSCODING',
            'durationMs': null,
          },
        ],
      });
      final c = await repo.getById('c1');
      expect(c.id, 'c1');
      expect(c.videos.length, 2);
      expect(c.videos.first.title, 'Intro');
    });
  });
}
