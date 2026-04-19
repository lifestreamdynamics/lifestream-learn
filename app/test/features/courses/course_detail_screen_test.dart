import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/models/enrollment.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';
import 'package:lifestream_learn_app/features/courses/course_detail_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockCourseRepository extends Mock implements CourseRepository {}

CourseDetail _detail(String id, {List<CourseVideoSummary>? videos}) =>
    CourseDetail(
      id: id,
      slug: 's',
      title: 'Course $id',
      description: 'desc',
      ownerId: 'o',
      published: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      videos: videos ??
          [
            const CourseVideoSummary(
              id: 'v1',
              title: 'Intro',
              orderIndex: 0,
              status: VideoStatus.ready,
              durationMs: 120000,
            ),
            const CourseVideoSummary(
              id: 'v2',
              title: 'Hidden',
              orderIndex: 1,
              status: VideoStatus.transcoding,
            ),
          ],
    );

Widget _wrap(CourseRepository repo) {
  final router = GoRouter(
    initialLocation: '/courses/c1',
    routes: [
      GoRoute(
        path: '/courses/:id',
        builder: (_, state) => CourseDetailScreen(
          courseId: state.pathParameters['id']!,
          courseRepo: repo,
        ),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, __) => const Scaffold(body: Text('feed')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockCourseRepository repo;

  setUp(() {
    repo = _MockCourseRepository();
  });

  testWidgets('renders title + READY videos only', (tester) async {
    when(() => repo.getById(any())).thenAnswer((_) async => _detail('c1'));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail.title')), findsOneWidget);
    expect(find.byKey(const Key('detail.video.v1')), findsOneWidget);
    // v2 is TRANSCODING → filtered out for learners.
    expect(find.byKey(const Key('detail.video.v2')), findsNothing);
  });

  testWidgets('Enroll tap hits the repo and swaps to Enrolled state',
      (tester) async {
    when(() => repo.getById(any())).thenAnswer((_) async => _detail('c1'));
    when(() => repo.enroll(any())).thenAnswer((_) async => Enrollment(
          id: 'e1',
          userId: 'u1',
          courseId: 'c1',
          startedAt: DateTime.utc(2026, 1, 1),
        ));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail.enroll')), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail.enroll')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail.enrolled')), findsOneWidget);
    expect(find.byKey(const Key('detail.watch')), findsOneWidget);
    verify(() => repo.enroll('c1')).called(1);
  });

  testWidgets('getById error shows retry', (tester) async {
    when(() => repo.getById(any())).thenThrow(const ApiException(
      code: 'NOT_FOUND',
      statusCode: 404,
      message: 'gone',
    ));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.text('gone'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
