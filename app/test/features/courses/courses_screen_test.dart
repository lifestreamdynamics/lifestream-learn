import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/auth/auth_bloc.dart';
import 'package:lifestream_learn_app/core/auth/auth_event.dart';
import 'package:lifestream_learn_app/core/auth/auth_state.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/models/user.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';
import 'package:lifestream_learn_app/features/courses/courses_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockCourseRepository extends Mock implements CourseRepository {}

class _MockAuthBloc extends Mock implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

const _learnerUser = User(
  id: 'learner-1',
  email: 'l@x.com',
  displayName: 'Learner',
  role: UserRole.learner,
);

const _designerUser = User(
  id: 'designer-1',
  email: 'd@x.com',
  displayName: 'Designer',
  role: UserRole.courseDesigner,
);

const _adminUser = User(
  id: 'admin-1',
  email: 'admin@x.com',
  displayName: 'Admin',
  role: UserRole.admin,
);

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

/// Wraps the CoursesScreen inside `BlocProvider<AuthBloc>` + GoRouter so
/// the role-aware empty-state copy, the Edit/Create FAB (via the AuthBloc
/// state) and the Create navigation (via GoRouter) all resolve.
Widget _wrap(
  CourseRepository repo, {
  required AuthState authState,
  List<String>? createPushes,
}) {
  final authBloc = _MockAuthBloc();
  when(() => authBloc.state).thenReturn(authState);
  when(() => authBloc.stream).thenAnswer((_) => const Stream<AuthState>.empty());
  when(() => authBloc.close()).thenAnswer((_) async {});

  final router = GoRouter(
    initialLocation: '/courses',
    routes: [
      GoRoute(
        path: '/courses',
        builder: (_, __) => CoursesScreen(courseRepo: repo),
      ),
      GoRoute(
        path: '/courses/:id',
        builder: (_, state) => Scaffold(
          body: Text(
            'detail-${state.pathParameters['id']}',
            key: const Key('test.detail'),
          ),
        ),
      ),
      GoRoute(
        path: '/designer/courses/new',
        builder: (_, __) {
          createPushes?.add('/designer/courses/new');
          return const Scaffold(
            body: Text('create', key: Key('test.create')),
          );
        },
      ),
    ],
  );
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late _MockCourseRepository repo;

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  setUp(() {
    repo = _MockCourseRepository();
    // Sensible defaults for both tabs. Individual tests override these.
    when(() => repo.myEnrollments()).thenAnswer((_) async => []);
    when(() => repo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer(
      (_) async => const CoursePage(items: [], hasMore: false),
    );
  });

  testWidgets('renders both tabs with the expected keys', (tester) async {
    await tester.pumpWidget(
      _wrap(repo, authState: const Authenticated(_learnerUser)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('courses.tabs')), findsOneWidget);
    expect(find.byKey(const Key('courses.tab.enrolled')), findsOneWidget);
    expect(find.byKey(const Key('courses.tab.available')), findsOneWidget);
  });

  testWidgets('defaults to the Enrolled tab (index 0)', (tester) async {
    await tester.pumpWidget(
      _wrap(repo, authState: const Authenticated(_learnerUser)),
    );
    await tester.pumpAndSettle();

    // Enrolled is the active tab → its empty-state key is mounted; the
    // Available body (CoursesBloc-driven) is lazy-built inside TabBarView
    // but its grid/empty keys aren't visible yet.
    expect(find.byKey(const Key('myCourses.empty')), findsOneWidget);
  });

  group('empty-state copy by role', () {
    testWidgets(
        'learner sees myCourses.empty text AND myCourses.empty.browse button',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_learnerUser)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('myCourses.empty')), findsOneWidget);
      expect(find.byKey(const Key('myCourses.empty.browse')), findsOneWidget);
      // The learner-specific copy is the short enrollment message.
      expect(find.text('No enrollments yet.'), findsOneWidget);
    });

    testWidgets('designer sees myCourses.empty text but NO browse button',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_designerUser)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('myCourses.empty')), findsOneWidget);
      expect(find.byKey(const Key('myCourses.empty.browse')), findsNothing);
    });

    testWidgets('admin sees myCourses.empty text but NO browse button',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_adminUser)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('myCourses.empty')), findsOneWidget);
      expect(find.byKey(const Key('myCourses.empty.browse')), findsNothing);
    });
  });

  testWidgets('learner tapping myCourses.empty.browse switches to Available',
      (tester) async {
    // Published call returns one course so we can assert the grid appears.
    when(() => repo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer(
      (_) async => CoursePage(items: [_course('a')], hasMore: false),
    );

    await tester.pumpWidget(
      _wrap(repo, authState: const Authenticated(_learnerUser)),
    );
    await tester.pumpAndSettle();

    // Pre-condition: Enrolled tab active, Available grid not visible.
    expect(find.byKey(const Key('courses.grid')), findsNothing);

    await tester.tap(find.byKey(const Key('myCourses.empty.browse')));
    await tester.pumpAndSettle();

    // Post-condition: Available tab active, grid rendered.
    expect(find.byKey(const Key('courses.grid')), findsOneWidget);
    expect(find.byKey(const Key('courses.tile.a')), findsOneWidget);
  });

  group('courses.create FAB visibility', () {
    testWidgets('learner: FAB never renders (Enrolled or Available)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_learnerUser)),
      );
      await tester.pumpAndSettle();

      // Enrolled tab: no FAB.
      expect(find.byKey(const Key('courses.create')), findsNothing);

      // Switch to Available — still no FAB for learners.
      await tester.tap(find.byKey(const Key('courses.tab.available')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('courses.create')), findsNothing);
    });

    testWidgets('designer: FAB appears only on Available tab',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_designerUser)),
      );
      await tester.pumpAndSettle();

      // Enrolled tab active → FAB hidden.
      expect(find.byKey(const Key('courses.create')), findsNothing);

      // Switch to Available → FAB appears.
      await tester.tap(find.byKey(const Key('courses.tab.available')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('courses.create')), findsOneWidget);

      // Switch back to Enrolled → FAB disappears again.
      await tester.tap(find.byKey(const Key('courses.tab.enrolled')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('courses.create')), findsNothing);
    });

    testWidgets('admin: FAB appears only on Available tab', (tester) async {
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_adminUser)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('courses.create')), findsNothing);

      await tester.tap(find.byKey(const Key('courses.tab.available')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('courses.create')), findsOneWidget);

      await tester.tap(find.byKey(const Key('courses.tab.enrolled')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('courses.create')), findsNothing);
    });
  });

  testWidgets('tapping courses.create pushes /designer/courses/new',
      (tester) async {
    final pushes = <String>[];
    await tester.pumpWidget(_wrap(
      repo,
      authState: const Authenticated(_designerUser),
      createPushes: pushes,
    ));
    await tester.pumpAndSettle();

    // Switch to Available to reveal the FAB.
    await tester.tap(find.byKey(const Key('courses.tab.available')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('courses.create')));
    await tester.pumpAndSettle();

    expect(pushes, ['/designer/courses/new']);
    expect(find.byKey(const Key('test.create')), findsOneWidget);
  });
}
