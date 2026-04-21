import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/progress.dart';
import 'package:lifestream_learn_app/data/repositories/progress_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

Map<String, dynamic> _overallJson() => <String, dynamic>{
      'summary': {
        'coursesEnrolled': 1,
        'lessonsCompleted': 0,
        'totalCuesAttempted': 0,
        'totalCuesCorrect': 0,
        'overallAccuracy': null,
        'overallGrade': null,
        'totalWatchTimeMs': 0,
      },
      'perCourse': <Map<String, dynamic>>[
        {
          'course': {
            'id': 'c1',
            'title': 'Course 1',
            'slug': 'c1',
            'coverImageUrl': null,
          },
          'videosTotal': 2,
          'videosCompleted': 1,
          'completionPct': 0.5,
          'cuesAttempted': 4,
          'cuesCorrect': 3,
          'accuracy': 0.75,
          'grade': 'C',
          'lastVideoId': 'v1',
          'lastPosMs': 12345,
        },
      ],
    };

Map<String, dynamic> _courseJson() => <String, dynamic>{
      'course': {
        'id': 'c1',
        'title': 'Course 1',
        'slug': 'c1',
        'coverImageUrl': null,
      },
      'videosTotal': 1,
      'videosCompleted': 0,
      'completionPct': 0.0,
      'cuesAttempted': 0,
      'cuesCorrect': 0,
      'accuracy': null,
      'grade': null,
      'lastVideoId': null,
      'lastPosMs': null,
      'lessons': <Map<String, dynamic>>[
        {
          'videoId': 'v1',
          'title': 'Lesson 1',
          'orderIndex': 0,
          'durationMs': 60000,
          'cueCount': 2,
          'cuesAttempted': 0,
          'cuesCorrect': 0,
          'accuracy': null,
          'grade': null,
          'completed': false,
        },
      ],
    };

Map<String, dynamic> _lessonJson({bool attempted = false}) => <String, dynamic>{
      'video': {
        'id': 'v1',
        'title': 'Lesson 1',
        'orderIndex': 0,
        'durationMs': 60000,
        'courseId': 'c1',
      },
      'course': {'id': 'c1', 'title': 'Course 1', 'slug': 'c1'},
      'score': {
        'cuesAttempted': attempted ? 1 : 0,
        'cuesCorrect': attempted ? 1 : 0,
        'accuracy': attempted ? 1.0 : null,
        'grade': attempted ? 'A' : null,
      },
      'cues': <Map<String, dynamic>>[
        {
          'cueId': 'cue1',
          'atMs': 1000,
          'type': 'MCQ',
          'prompt': 'Capital of France?',
          'attempted': attempted,
          'correct': attempted ? true : null,
          'scoreJson': attempted ? {'selected': 1} : null,
          'submittedAt': attempted ? '2026-04-10T00:00:00.000Z' : null,
          'explanation': attempted ? 'France -> Paris' : null,
          'yourAnswerSummary': attempted ? 'Choice 2' : null,
          'correctAnswerSummary': attempted ? 'Paris' : null,
        },
      ],
    };

void main() {
  group('ProgressRepository.fetchOverall', () {
    test('parses full shape', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = ProgressRepository(dio);
      adapter.enqueueJson(_overallJson());

      final result = await repo.fetchOverall();
      expect(result.summary.coursesEnrolled, 1);
      expect(result.perCourse, hasLength(1));
      expect(result.perCourse.first.grade, Grade.c);
      expect(result.perCourse.first.lastVideoId, 'v1');
      expect(adapter.requestLog.single.path, '/api/me/progress');
    });

    test('401 surfaces as ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = ProgressRepository(dio);
      adapter.enqueueError(401, <String, dynamic>{
        'error': 'UNAUTHORIZED',
        'message': 'Not authenticated',
      });

      expect(
        repo.fetchOverall(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 401)
            .having((e) => e.code, 'code', 'UNAUTHORIZED')),
      );
    });
  });

  group('ProgressRepository.fetchCourse', () {
    test('parses detail shape', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = ProgressRepository(dio);
      adapter.enqueueJson(_courseJson());

      final result = await repo.fetchCourse('c1');
      expect(result.lessons, hasLength(1));
      expect(result.lessons.first.videoId, 'v1');
      expect(adapter.requestLog.single.path, '/api/me/progress/courses/c1');
    });

    test('404 surfaces as ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = ProgressRepository(dio);
      adapter.enqueueError(404, <String, dynamic>{
        'error': 'NOT_FOUND',
        'message': 'You are not enrolled in this course',
      });
      expect(
        repo.fetchCourse('c1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('ProgressRepository.fetchAchievements', () {
    test('parses unlocked + locked partition', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = ProgressRepository(dio);
      adapter.enqueueJson(<String, dynamic>{
        'unlocked': <Map<String, dynamic>>[
          {
            'id': 'first_lesson',
            'title': 'First Lesson',
            'description': 'Complete your first lesson',
            'iconKey': 'school',
            'criteriaJson': {'type': 'lessons_completed', 'count': 1},
          },
        ],
        'locked': <Map<String, dynamic>>[
          {
            'id': 'streak_7',
            'title': 'Week-Long Streak',
            'description': 'Learn 7 days in a row',
            'iconKey': 'whatshot',
            'criteriaJson': {'type': 'streak', 'days': 7},
          },
        ],
        'unlockedAtByAchievementId': {
          'first_lesson': '2026-04-15T10:00:00.000Z',
        },
      });

      final result = await repo.fetchAchievements();
      expect(result.unlocked, hasLength(1));
      expect(result.unlocked.first.id, 'first_lesson');
      expect(result.unlocked.first.criteriaJson['type'], 'lessons_completed');
      expect(result.locked, hasLength(1));
      expect(result.locked.first.iconKey, 'whatshot');
      expect(
        result.unlockedAtByAchievementId['first_lesson'],
        DateTime.utc(2026, 4, 15, 10),
      );
      expect(adapter.requestLog.single.path, '/api/me/achievements');
    });

    test('401 surfaces as ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = ProgressRepository(dio);
      adapter.enqueueError(401, <String, dynamic>{
        'error': 'UNAUTHORIZED',
        'message': 'Not authenticated',
      });
      expect(
        repo.fetchAchievements(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });
  });

  group('ProgressRepository.fetchLesson', () {
    test('parses lesson review', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = ProgressRepository(dio);
      adapter.enqueueJson(_lessonJson(attempted: true));

      final result = await repo.fetchLesson('v1');
      expect(result.cues, hasLength(1));
      expect(result.cues.first.attempted, true);
      expect(result.cues.first.correctAnswerSummary, 'Paris');
      expect(adapter.requestLog.single.path, '/api/me/progress/lessons/v1');
    });

    test(
        'SECURITY: unattempted cue has null correctAnswerSummary after deserialisation',
        () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = ProgressRepository(dio);
      adapter.enqueueJson(_lessonJson(attempted: false));

      final result = await repo.fetchLesson('v1');
      expect(result.cues.first.attempted, false);
      expect(result.cues.first.correctAnswerSummary, isNull);
      expect(result.cues.first.yourAnswerSummary, isNull);
      expect(result.cues.first.explanation, isNull);
    });
  });
}
