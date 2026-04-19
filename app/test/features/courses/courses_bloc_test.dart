import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';
import 'package:lifestream_learn_app/features/courses/courses_bloc.dart';
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

void main() {
  late _MockCourseRepository repo;

  setUp(() {
    repo = _MockCourseRepository();
  });

  test('initial load emits Loading → Loaded', () async {
    when(() => repo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => CoursePage(
          items: [_course('a'), _course('b')],
          nextCursor: 'c1',
          hasMore: true,
        ));

    final bloc = CoursesBloc(repo: repo);
    final expectation = expectLater(
      bloc.stream,
      emitsInOrder(<dynamic>[
        isA<CoursesLoading>(),
        predicate<CoursesState>(
            (s) => s is CoursesLoaded && s.items.length == 2 && s.hasMore),
      ]),
    );
    bloc.add(const CoursesLoadRequested());
    await expectation;
    await bloc.close();
  });

  test('load-more appends + updates cursor', () async {
    when(() => repo.published(
          cursor: null,
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => CoursePage(
          items: [_course('a')],
          nextCursor: 'c1',
          hasMore: true,
        ));
    when(() => repo.published(
          cursor: 'c1',
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => CoursePage(
          items: [_course('b')],
          hasMore: false,
        ));

    final bloc = CoursesBloc(repo: repo);
    bloc.add(const CoursesLoadRequested());
    await expectLater(
      bloc.stream,
      emitsThrough(predicate<CoursesState>(
          (s) => s is CoursesLoaded && s.items.length == 1)),
    );
    bloc.add(const CoursesLoadMoreRequested());
    await expectLater(
      bloc.stream,
      emitsThrough(predicate<CoursesState>((s) =>
          s is CoursesLoaded && s.items.length == 2 && !s.hasMore)),
    );
    await bloc.close();
  });

  test('initial load failure → CoursesError', () async {
    when(() => repo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenThrow(const ApiException(
      code: 'NETWORK_ERROR',
      statusCode: 0,
      message: 'no wifi',
    ));

    final bloc = CoursesBloc(repo: repo);
    final expectation = expectLater(
      bloc.stream,
      emitsInOrder(<dynamic>[
        isA<CoursesLoading>(),
        isA<CoursesError>(),
      ]),
    );
    bloc.add(const CoursesLoadRequested());
    await expectation;
    await bloc.close();
  });
}
