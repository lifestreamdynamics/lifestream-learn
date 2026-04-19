import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';
import 'package:lifestream_learn_app/features/designer/create_course_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockCourseRepository extends Mock implements CourseRepository {}

Course _course({String id = 'c1'}) => Course(
      id: id,
      slug: 'c',
      title: 'Title',
      description: 'Desc',
      ownerId: 'u1',
      published: false,
      createdAt: DateTime.utc(2026, 4, 19),
      updatedAt: DateTime.utc(2026, 4, 19),
    );

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/designer/courses/new',
    routes: [
      GoRoute(
        path: '/designer/courses/new',
        builder: (_, __) => child,
      ),
      GoRoute(
        path: '/designer/courses/:id',
        builder: (_, state) => Scaffold(
          body: Text('Editor ${state.pathParameters['id']}'),
        ),
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

  testWidgets('blocks submit on empty title', (tester) async {
    await tester.pumpWidget(_wrap(CreateCourseScreen(courseRepo: repo)));
    await tester.tap(find.byKey(const Key('create.submit')));
    await tester.pump();
    expect(find.text('Title is required'), findsOneWidget);
    verifyNever(() => repo.create(
          title: any(named: 'title'),
          description: any(named: 'description'),
          coverImageUrl: any(named: 'coverImageUrl'),
        ));
  });

  testWidgets('blocks submit on empty description', (tester) async {
    await tester.pumpWidget(_wrap(CreateCourseScreen(courseRepo: repo)));
    await tester.enterText(find.byKey(const Key('create.title')), 'T');
    await tester.tap(find.byKey(const Key('create.submit')));
    await tester.pump();
    expect(find.text('Description is required'), findsOneWidget);
  });

  testWidgets('valid submit calls repo.create with trimmed values',
      (tester) async {
    when(() => repo.create(
          title: any(named: 'title'),
          description: any(named: 'description'),
          coverImageUrl: any(named: 'coverImageUrl'),
        )).thenAnswer((_) async => _course());

    await tester.pumpWidget(_wrap(CreateCourseScreen(courseRepo: repo)));
    await tester.enterText(
      find.byKey(const Key('create.title')),
      '  My course  ',
    );
    await tester.enterText(
      find.byKey(const Key('create.description')),
      '  Some description.  ',
    );
    await tester.tap(find.byKey(const Key('create.submit')));
    await tester.pumpAndSettle();

    verify(() => repo.create(
          title: 'My course',
          description: 'Some description.',
          coverImageUrl: null,
        )).called(1);
  });

  testWidgets('shows server error when create throws', (tester) async {
    when(() => repo.create(
          title: any(named: 'title'),
          description: any(named: 'description'),
          coverImageUrl: any(named: 'coverImageUrl'),
        )).thenThrow(Exception('boom'));

    await tester.pumpWidget(_wrap(CreateCourseScreen(courseRepo: repo)));
    await tester.enterText(find.byKey(const Key('create.title')), 'T');
    await tester.enterText(
      find.byKey(const Key('create.description')),
      'D',
    );
    await tester.tap(find.byKey(const Key('create.submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create.error')), findsOneWidget);
  });
}
