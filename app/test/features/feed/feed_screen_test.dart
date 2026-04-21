import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/models/feed_entry.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/data/repositories/enrollment_repository.dart';
import 'package:lifestream_learn_app/data/repositories/video_repository.dart';
import 'package:lifestream_learn_app/features/feed/feed_bloc.dart';
import 'package:lifestream_learn_app/features/feed/feed_event.dart';
import 'package:lifestream_learn_app/features/feed/feed_screen.dart';
import 'package:lifestream_learn_app/features/feed/feed_state.dart';
import 'package:lifestream_learn_app/features/feed/video_controller_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

class _MockVideoRepository extends Mock implements VideoRepository {}

class _MockEnrollmentRepository extends Mock implements EnrollmentRepository {}

class _MockFeedBloc extends Mock implements FeedBloc {}

class _FakeFeedEvent extends Fake implements FeedEvent {}

class _FakeController implements VideoPlayerController {
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

FeedEntry _entry(String id) => FeedEntry(
      video: VideoSummary(
        id: id,
        courseId: 'c1',
        title: 'video $id',
        orderIndex: 0,
        status: VideoStatus.ready,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      course: const CourseSummary(id: 'c1', title: 'Course'),
      cueCount: 0,
      hasAttempted: false,
    );

Widget _wrap(FeedBloc bloc, FeedScreen screen) {
  final router = GoRouter(
    initialLocation: '/feed',
    routes: [
      GoRoute(
        path: '/feed',
        builder: (_, __) =>
            BlocProvider<FeedBloc>.value(value: bloc, child: screen),
      ),
      GoRoute(
        path: '/courses',
        builder: (_, __) => const Scaffold(body: Text('courses page')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

FeedScreen _screen({FeedItemBuilder? itemBuilder}) {
  final cache = VideoControllerCache(
    capacity: 3,
    factory: (_) async => _FakeController(),
  );
  return FeedScreen(
    videoRepo: _MockVideoRepository(),
    enrollmentRepo: _MockEnrollmentRepository(),
    controllerCache: cache,
    itemBuilder: itemBuilder ??
        (context, entry) => Container(
              key: ValueKey('stub.${entry.video.id}'),
              color: Colors.blueGrey,
              child: Center(child: Text('stub ${entry.video.id}')),
            ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFeedEvent());
  });

  late _MockFeedBloc bloc;

  setUp(() {
    bloc = _MockFeedBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream<FeedState>.empty());
    when(() => bloc.close()).thenAnswer((_) async {});
  });

  testWidgets('renders items using the itemBuilder stub', (tester) async {
    when(() => bloc.state).thenReturn(FeedLoaded(
      items: [_entry('v1'), _entry('v2'), _entry('v3')],
      hasMore: false,
    ));

    await tester.pumpWidget(_wrap(bloc, _screen()));
    await tester.pump();

    expect(find.byKey(const Key('feed.pageview')), findsOneWidget);
    // PageView lazily builds — pump to let the first page mount.
    expect(find.text('stub v1'), findsOneWidget);
  });

  testWidgets('empty state renders the "Browse courses" CTA',
      (tester) async {
    when(() => bloc.state).thenReturn(const FeedLoaded(
      items: [],
      hasMore: false,
    ));

    await tester.pumpWidget(_wrap(bloc, _screen()));
    expect(find.byKey(const Key('feed.empty')), findsOneWidget);
    expect(find.byKey(const Key('feed.empty.browse')), findsOneWidget);
  });

  testWidgets('error state shows retry', (tester) async {
    when(() => bloc.state).thenReturn(const FeedError(ApiException(
      code: 'NETWORK_ERROR',
      statusCode: 0,
      message: 'oops',
    )));

    await tester.pumpWidget(_wrap(bloc, _screen()));
    expect(find.byKey(const Key('feed.error')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('appbar Courses action navigates to /courses', (tester) async {
    when(() => bloc.state).thenReturn(FeedLoaded(
      items: [_entry('v1')],
      hasMore: false,
    ));

    await tester.pumpWidget(_wrap(bloc, _screen()));
    await tester.pump();

    final coursesButton = find.byKey(const Key('feed.appbar.courses'));
    expect(coursesButton, findsOneWidget);

    await tester.tap(coursesButton);
    await tester.pumpAndSettle();

    expect(find.text('courses page'), findsOneWidget);
  });

  testWidgets('loadMoreError renders inline banner', (tester) async {
    when(() => bloc.state).thenReturn(FeedLoaded(
      items: [_entry('v1')],
      hasMore: true,
      loadMoreError: const ApiException(
        code: 'NETWORK_ERROR',
        statusCode: 0,
        message: 'offline',
      ),
    ));

    await tester.pumpWidget(_wrap(bloc, _screen()));
    await tester.pump();
    expect(find.byKey(const Key('feed.loadMoreError')), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
  });
}
