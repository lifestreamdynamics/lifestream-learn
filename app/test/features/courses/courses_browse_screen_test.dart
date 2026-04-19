import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';
import 'package:lifestream_learn_app/features/courses/courses_browse_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockCourseRepository extends Mock implements CourseRepository {}

Course _course(String id) => Course(
      id: id,
      slug: 'c-$id',
      title: 'Course $id',
      description: 'd',
      ownerId: 'o1',
      published: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

Widget _wrap(CourseRepository repo) {
  final router = GoRouter(
    initialLocation: '/browse',
    routes: [
      GoRoute(
        path: '/browse',
        builder: (_, __) => CoursesBrowseScreen(courseRepo: repo),
      ),
      GoRoute(
        path: '/courses/:id',
        builder: (_, state) =>
            Scaffold(body: Text('detail ${state.pathParameters['id']}')),
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

  testWidgets('renders tiles for each published course', (tester) async {
    when(() => repo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => CoursePage(
          items: [_course('a'), _course('b'), _course('c')],
          hasMore: false,
        ));

    await tester.pumpWidget(_wrap(repo));
    // Wait for the initial load to settle.
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('courses.grid')), findsOneWidget);
    expect(find.byKey(const Key('courses.tile.a')), findsOneWidget);
    expect(find.byKey(const Key('courses.tile.b')), findsOneWidget);
    expect(find.byKey(const Key('courses.tile.c')), findsOneWidget);
  });

  testWidgets('tapping a tile navigates to course detail', (tester) async {
    when(() => repo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => CoursePage(
          items: [_course('a')],
          hasMore: false,
        ));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('courses.tile.a')));
    await tester.pumpAndSettle();
    expect(find.text('detail a'), findsOneWidget);
  });

  testWidgets('empty list renders the empty state', (tester) async {
    when(() => repo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const CoursePage(
          items: [],
          hasMore: false,
        ));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('courses.empty')), findsOneWidget);
  });
}
