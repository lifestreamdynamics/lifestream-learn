import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/data/models/progress.dart';
import 'package:lifestream_learn_app/data/repositories/progress_repository.dart';
import 'package:lifestream_learn_app/features/profile/widgets/enrolled_course_card.dart';
import 'package:mocktail/mocktail.dart';

class _MockProgressRepo extends Mock implements ProgressRepository {}

CourseProgressSummary _summary({
  String id = 'c1',
  String? lastVideoId,
  int? lastPosMs,
  Grade? grade = Grade.b,
  double? accuracy = 0.85,
  int videosTotal = 4,
  int videosCompleted = 2,
}) =>
    CourseProgressSummary(
      course: CourseTile(id: id, title: 'My Course', slug: id),
      videosTotal: videosTotal,
      videosCompleted: videosCompleted,
      completionPct: videosTotal == 0 ? 0.0 : videosCompleted / videosTotal,
      cuesAttempted: 10,
      cuesCorrect: (10 * (accuracy ?? 0)).round(),
      accuracy: accuracy,
      grade: grade,
      lastVideoId: lastVideoId,
      lastPosMs: lastPosMs,
    );

Widget _wrap({
  required CourseProgressSummary summary,
  required ProgressRepository repo,
  ValueChanged<String>? onNavigate,
}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (_, __) => Scaffold(
          body: EnrolledCourseCard(summary: summary, progressRepo: repo),
        ),
      ),
      GoRoute(
        path: '/videos/:id/watch',
        builder: (_, state) {
          onNavigate?.call(
            '/videos/${state.pathParameters['id']}/watch?t=${state.uri.queryParameters['t'] ?? ''}',
          );
          return const Scaffold(body: Text('watch'));
        },
      ),
      GoRoute(
        path: '/courses/:id',
        builder: (_, state) {
          onNavigate?.call('/courses/${state.pathParameters['id']}');
          return const Scaffold(body: Text('course-detail'));
        },
      ),
      GoRoute(
        path: '/courses/:id/progress',
        builder: (_, state) {
          onNavigate?.call('/courses/${state.pathParameters['id']}/progress');
          return const Scaffold(body: Text('course-progress'));
        },
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

  testWidgets('renders title, progress bar, grade chip with letter + percentage',
      (tester) async {
    await tester.pumpWidget(_wrap(
      summary: _summary(
        lastVideoId: 'v1',
        lastPosMs: 12345,
        grade: Grade.b,
        accuracy: 0.85,
      ),
      repo: repo,
    ));
    await tester.pump();

    expect(find.text('My Course'), findsOneWidget);
    expect(find.byKey(const Key('profile.course.c1.progress')), findsOneWidget);
    // Grade chip pairs letter + percentage — colour is not the only signal.
    final chip = tester.widget<Chip>(
      find.byKey(const Key('profile.course.c1.gradeChip')),
    );
    expect((chip.label as Text).data, 'B · 85%');
  });

  testWidgets('grade chip shows "No attempts yet" when accuracy is null',
      (tester) async {
    await tester.pumpWidget(_wrap(
      summary: _summary(grade: null, accuracy: null),
      repo: repo,
    ));
    await tester.pump();
    final chip = tester.widget<Chip>(
      find.byKey(const Key('profile.course.c1.gradeChip')),
    );
    expect((chip.label as Text).data, 'No attempts yet');
  });

  testWidgets('Resume button deep-links to /videos/:id/watch?t=<lastPosMs>',
      (tester) async {
    final targets = <String>[];
    await tester.pumpWidget(_wrap(
      summary: _summary(lastVideoId: 'v42', lastPosMs: 9999),
      repo: repo,
      onNavigate: targets.add,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('profile.course.c1.resume')));
    await tester.pumpAndSettle();
    expect(targets.single, '/videos/v42/watch?t=9999');
  });

  testWidgets(
      'Start button (null lastVideoId) routes to course detail as fallback',
      (tester) async {
    final targets = <String>[];
    await tester.pumpWidget(_wrap(
      summary: _summary(lastVideoId: null, lastPosMs: null),
      repo: repo,
      onNavigate: targets.add,
    ));
    await tester.pump();

    // Button label is "Start" when lastVideoId is null.
    expect(find.widgetWithText(ElevatedButton, 'Start'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile.course.c1.resume')));
    await tester.pumpAndSettle();
    // No detail preloaded + no lastVideoId -> routes to course detail.
    expect(targets.single, '/courses/c1');
  });

  testWidgets('Details button navigates to course progress screen',
      (tester) async {
    final targets = <String>[];
    await tester.pumpWidget(_wrap(
      summary: _summary(lastVideoId: 'v1', lastPosMs: 0),
      repo: repo,
      onNavigate: targets.add,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('profile.course.c1.details')));
    await tester.pumpAndSettle();
    expect(targets.single, '/courses/c1/progress');
  });
}
