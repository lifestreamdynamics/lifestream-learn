import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/models/feed_entry.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/data/repositories/feed_repository.dart';
import 'package:lifestream_learn_app/features/feed/feed_bloc.dart';
import 'package:lifestream_learn_app/features/feed/feed_event.dart';
import 'package:lifestream_learn_app/features/feed/feed_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockFeedRepository extends Mock implements FeedRepository {}

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

void main() {
  late _MockFeedRepository repo;

  setUp(() {
    repo = _MockFeedRepository();
  });

  group('FeedLoadRequested', () {
    test('initial load: Loading → Loaded(items)', () async {
      when(() => repo.page(limit: any(named: 'limit'))).thenAnswer(
        (_) async => FeedPage(
          items: [_entry('v1'), _entry('v2')],
          nextCursor: 'c1',
          hasMore: true,
        ),
      );

      final bloc = FeedBloc(feedRepo: repo);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          const FeedLoading(),
          predicate<FeedState>((s) =>
              s is FeedLoaded && s.items.length == 2 && s.hasMore),
        ]),
      );
      bloc.add(const FeedLoadRequested());
      await expectation;
      await bloc.close();
    });

    test('API failure → FeedError', () async {
      when(() => repo.page(limit: any(named: 'limit'))).thenThrow(
          const ApiException(
              code: 'NETWORK_ERROR', statusCode: 0, message: 'oops'));

      final bloc = FeedBloc(feedRepo: repo);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          const FeedLoading(),
          predicate<FeedState>((s) => s is FeedError),
        ]),
      );
      bloc.add(const FeedLoadRequested());
      await expectation;
      await bloc.close();
    });
  });

  group('FeedLoadMoreRequested', () {
    test('appends new items and updates cursor', () async {
      when(() => repo.page(
            cursor: null,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => FeedPage(
            items: [_entry('v1')],
            nextCursor: 'cursor-1',
            hasMore: true,
          ));
      when(() => repo.page(
            cursor: 'cursor-1',
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => FeedPage(
            items: [_entry('v2'), _entry('v3')],
            nextCursor: null,
            hasMore: false,
          ));

      final bloc = FeedBloc(feedRepo: repo);
      bloc.add(const FeedLoadRequested());
      // Let initial load settle.
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>(
            (s) => s is FeedLoaded && s.items.length == 1)),
      );

      bloc.add(const FeedLoadMoreRequested());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>((s) =>
            s is FeedLoaded &&
            s.items.length == 3 &&
            !s.hasMore &&
            s.nextCursor == null)),
      );
      await bloc.close();
    });

    test('no-op when hasMore is false', () async {
      when(() => repo.page(
            cursor: null,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => FeedPage(
            items: [_entry('v1')],
            nextCursor: null,
            hasMore: false,
          ));

      final bloc = FeedBloc(feedRepo: repo);
      bloc.add(const FeedLoadRequested());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>(
            (s) => s is FeedLoaded && s.items.length == 1)),
      );

      bloc.add(const FeedLoadMoreRequested());
      // Give the bloc a tick to process; no new emission expected.
      await Future<void>.delayed(Duration.zero);
      expect((bloc.state as FeedLoaded).items.length, 1);
      verify(() => repo.page(limit: any(named: 'limit'))).called(1);
      verifyNoMoreInteractions(repo);
      await bloc.close();
    });

    test('error during load-more preserves existing items + banner error',
        () async {
      when(() => repo.page(
            cursor: null,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => FeedPage(
            items: [_entry('v1')],
            nextCursor: 'c2',
            hasMore: true,
          ));
      when(() => repo.page(
            cursor: 'c2',
            limit: any(named: 'limit'),
          )).thenThrow(const ApiException(
        code: 'NETWORK_ERROR',
        statusCode: 0,
        message: 'no wifi',
      ));

      final bloc = FeedBloc(feedRepo: repo);
      bloc.add(const FeedLoadRequested());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>(
            (s) => s is FeedLoaded && s.items.length == 1)),
      );

      bloc.add(const FeedLoadMoreRequested());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>((s) =>
            s is FeedLoaded &&
            s.items.length == 1 &&
            s.isLoadingMore == false &&
            s.loadMoreError != null &&
            s.loadMoreError!.code == 'NETWORK_ERROR')),
      );
      await bloc.close();
    });
  });

  group('FeedRefreshRequested', () {
    test('replaces items on success', () async {
      when(() => repo.page(
            cursor: null,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => FeedPage(
            items: [_entry('v1')],
            nextCursor: 'c1',
            hasMore: true,
          ));

      final bloc = FeedBloc(feedRepo: repo);
      bloc.add(const FeedLoadRequested());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>(
            (s) => s is FeedLoaded && s.items.length == 1)),
      );

      when(() => repo.page(
            cursor: null,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => FeedPage(
            items: [_entry('v2'), _entry('v3')],
            nextCursor: null,
            hasMore: false,
          ));

      bloc.add(const FeedRefreshRequested());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>((s) =>
            s is FeedLoaded &&
            s.items.length == 2 &&
            s.items.first.video.id == 'v2' &&
            !s.hasMore)),
      );
      await bloc.close();
    });
  });

  group('FeedErrorClearRequested', () {
    test('clears loadMoreError banner', () async {
      when(() => repo.page(
            cursor: null,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => FeedPage(
            items: [_entry('v1')],
            nextCursor: 'c2',
            hasMore: true,
          ));
      when(() => repo.page(
            cursor: 'c2',
            limit: any(named: 'limit'),
          )).thenThrow(const ApiException(
        code: 'NETWORK_ERROR',
        statusCode: 0,
        message: 'blip',
      ));

      final bloc = FeedBloc(feedRepo: repo);
      bloc.add(const FeedLoadRequested());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>(
            (s) => s is FeedLoaded && s.items.length == 1)),
      );
      bloc.add(const FeedLoadMoreRequested());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>(
            (s) => s is FeedLoaded && s.loadMoreError != null)),
      );
      bloc.add(const FeedErrorClearRequested());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<FeedState>(
            (s) => s is FeedLoaded && s.loadMoreError == null)),
      );
      await bloc.close();
    });
  });
}
