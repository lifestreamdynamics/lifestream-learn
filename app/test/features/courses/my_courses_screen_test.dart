import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/enrollment.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';
import 'package:lifestream_learn_app/features/courses/my_courses_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockCourseRepository extends Mock implements CourseRepository {}

EnrollmentWithCourse _row(String courseId, {int? posMs}) =>
    EnrollmentWithCourse(
      id: 'e-$courseId',
      userId: 'u1',
      courseId: courseId,
      startedAt: DateTime.utc(2026, 1, 1),
      lastPosMs: posMs,
      lastVideoId: posMs != null ? 'v1' : null,
      course: EnrolledCourseSummary(
        id: courseId,
        title: 'Course $courseId',
        slug: 'c-$courseId',
      ),
    );

Widget _wrap(CourseRepository repo) {
  final router = GoRouter(
    initialLocation: '/my-courses',
    routes: [
      GoRoute(
        path: '/my-courses',
        builder: (_, __) => MyCoursesScreen(courseRepo: repo),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, __) => const Scaffold(body: Text('feed-page')),
      ),
      GoRoute(
        path: '/courses',
        builder: (_, __) => const Scaffold(body: Text('courses-page')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockCourseRepository repo;
  setUp(() => repo = _MockCourseRepository());

  testWidgets('renders a row per enrollment', (tester) async {
    when(() => repo.myEnrollments()).thenAnswer((_) async => [
          _row('a', posMs: 65000),
          _row('b'),
        ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('myCourses.row.a')), findsOneWidget);
    expect(find.byKey(const Key('myCourses.row.b')), findsOneWidget);
    expect(find.text('Last watched at 01:05'), findsOneWidget);
    expect(find.text('Not started'), findsOneWidget);
  });

  testWidgets('empty state renders CTA', (tester) async {
    when(() => repo.myEnrollments()).thenAnswer((_) async => []);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('myCourses.empty')), findsOneWidget);
  });

  testWidgets('error shows retry button', (tester) async {
    when(() => repo.myEnrollments()).thenThrow(const ApiException(
      code: 'NETWORK_ERROR',
      statusCode: 0,
      message: 'down',
    ));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.text('down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
