import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/data/models/progress.dart';
import 'package:lifestream_learn_app/data/repositories/progress_repository.dart';
import 'package:lifestream_learn_app/features/profile/progress/course_progress_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockProgressRepo extends Mock implements ProgressRepository {}

CourseProgressDetail _detail() => CourseProgressDetail(
      course: const CourseTile(id: 'c1', title: 'My Course', slug: 'my'),
      videosTotal: 2,
      videosCompleted: 1,
      completionPct: 0.5,
      cuesAttempted: 4,
      cuesCorrect: 3,
      accuracy: 0.75,
      grade: Grade.c,
      lastVideoId: 'v2',
      lastPosMs: 30000,
      lessons: const [
        LessonProgressSummary(
          videoId: 'v1',
          title: 'Lesson 1',
          orderIndex: 0,
          cueCount: 2,
          cuesAttempted: 2,
          cuesCorrect: 2,
          accuracy: 1.0,
          grade: Grade.a,
          completed: true,
        ),
        LessonProgressSummary(
          videoId: 'v2',
          title: 'Lesson 2',
          orderIndex: 1,
          cueCount: 2,
          cuesAttempted: 2,
          cuesCorrect: 1,
          accuracy: 0.5,
          grade: Grade.f,
          completed: false,
        ),
      ],
    );

Widget _wrap(ProgressRepository repo) {
  final router = GoRouter(
    initialLocation: '/courses/c1/progress',
    routes: [
      GoRoute(
        path: '/courses/:id/progress',
        builder: (_, state) => CourseProgressScreen(
          courseId: state.pathParameters['id']!,
          progressRepo: repo,
        ),
      ),
      GoRoute(
        path: '/courses/:id/lessons/:videoId/review',
        builder: (_, __) => const Scaffold(body: Text('review')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockProgressRepo repo;
  setUp(() {
    repo = _MockProgressRepo();
  });

  testWidgets('renders header + per-lesson rows', (tester) async {
    when(() => repo.fetchCourse('c1')).thenAnswer((_) async => _detail());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('courseProgress.header')), findsOneWidget);
    expect(
      find.byKey(const Key('courseProgress.header.grade')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('courseProgress.lesson.v1')), findsOneWidget);
    expect(find.byKey(const Key('courseProgress.lesson.v2')), findsOneWidget);
    // Lesson 1 sub-title shows score + grade.
    expect(find.text('2/2 correct · A'), findsOneWidget);
  });
}
