import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/auth/auth_bloc.dart';
import 'package:lifestream_learn_app/core/auth/auth_event.dart';
import 'package:lifestream_learn_app/core/auth/auth_state.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/models/enrollment.dart';
import 'package:lifestream_learn_app/data/models/user.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';
import 'package:lifestream_learn_app/features/courses/course_detail_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockCourseRepository extends Mock implements CourseRepository {}

class _MockAuthBloc extends Mock implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

const _ownerUser = User(
  id: 'owner-1',
  email: 'owner@x.com',
  displayName: 'Owner',
  role: UserRole.courseDesigner,
);

const _otherDesigner = User(
  id: 'other-designer',
  email: 'other@x.com',
  displayName: 'Other',
  role: UserRole.courseDesigner,
);

const _adminUser = User(
  id: 'admin-1',
  email: 'admin@x.com',
  displayName: 'Admin',
  role: UserRole.admin,
);

const _learnerUser = User(
  id: 'learner-1',
  email: 'l@x.com',
  displayName: 'Learner',
  role: UserRole.learner,
);

CourseDetail _detail(
  String id, {
  List<CourseVideoSummary>? videos,
  String ownerId = 'owner-1',
}) =>
    CourseDetail(
      id: id,
      slug: 's',
      title: 'Course $id',
      description: 'desc',
      ownerId: ownerId,
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

/// Assembles the screen with a GoRouter (so `GoRouter.of(context)` works)
/// AND an AuthBloc above it (so `ctx.watch<AuthBloc>()` resolves). The
/// AuthBloc's state decides whether the owner-or-admin `detail.edit`
/// button is rendered.
Widget _wrap(
  CourseRepository repo, {
  AuthState authState = const Unauthenticated(),
  String courseId = 'c1',
  List<String>? visitedEditorIds,
}) {
  final authBloc = _MockAuthBloc();
  when(() => authBloc.state).thenReturn(authState);
  when(() => authBloc.stream).thenAnswer((_) => const Stream<AuthState>.empty());
  when(() => authBloc.close()).thenAnswer((_) async {});

  final router = GoRouter(
    initialLocation: '/courses/$courseId',
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
      GoRoute(
        path: '/designer/courses/:id',
        builder: (_, state) {
          visitedEditorIds?.add(state.pathParameters['id']!);
          return Scaffold(
            body: Text(
              'editor-${state.pathParameters['id']}',
              key: const Key('test.editor'),
            ),
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

  group('detail.edit (owner-or-admin only)', () {
    testWidgets('owner-designer sees the Edit button', (tester) async {
      when(() => repo.getById(any()))
          .thenAnswer((_) async => _detail('c1', ownerId: _ownerUser.id));
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_ownerUser)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail.edit')), findsOneWidget);
    });

    testWidgets('admin (not owner) still sees the Edit button',
        (tester) async {
      when(() => repo.getById(any()))
          .thenAnswer((_) async => _detail('c1', ownerId: _ownerUser.id));
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_adminUser)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail.edit')), findsOneWidget);
    });

    testWidgets('non-owner designer does NOT see the Edit button',
        (tester) async {
      // Another COURSE_DESIGNER — the role alone is not enough, they must
      // actually own the course row.
      when(() => repo.getById(any()))
          .thenAnswer((_) async => _detail('c1', ownerId: _ownerUser.id));
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_otherDesigner)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail.edit')), findsNothing);
    });

    testWidgets('non-owner learner does NOT see the Edit button',
        (tester) async {
      when(() => repo.getById(any()))
          .thenAnswer((_) async => _detail('c1', ownerId: _ownerUser.id));
      await tester.pumpWidget(
        _wrap(repo, authState: const Authenticated(_learnerUser)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail.edit')), findsNothing);
    });

    testWidgets('unauthenticated context renders no Edit button',
        (tester) async {
      when(() => repo.getById(any()))
          .thenAnswer((_) async => _detail('c1', ownerId: _ownerUser.id));
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail.edit')), findsNothing);
    });

    testWidgets('tapping Edit pushes /designer/courses/:id', (tester) async {
      when(() => repo.getById(any()))
          .thenAnswer((_) async => _detail('c1', ownerId: _ownerUser.id));
      final visited = <String>[];
      await tester.pumpWidget(_wrap(
        repo,
        authState: const Authenticated(_ownerUser),
        visitedEditorIds: visited,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('detail.edit')));
      await tester.pumpAndSettle();

      // The editor stub writes the :id it was invoked with into `visited`
      // and renders a keyed scaffold we can assert on.
      expect(visited, ['c1']);
      expect(find.byKey(const Key('test.editor')), findsOneWidget);
      expect(find.text('editor-c1'), findsOneWidget);
    });
  });
}
