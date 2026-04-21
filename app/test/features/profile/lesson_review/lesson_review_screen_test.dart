import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/cue.dart';
import 'package:lifestream_learn_app/data/models/progress.dart';
import 'package:lifestream_learn_app/data/repositories/progress_repository.dart';
import 'package:lifestream_learn_app/features/profile/lesson_review/lesson_review_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockProgressRepo extends Mock implements ProgressRepository {}

LessonReview _review() => LessonReview(
      video: const LessonVideoRef(
        id: 'v1',
        title: 'Lesson 1',
        orderIndex: 0,
        durationMs: 60000,
        courseId: 'c1',
      ),
      course: const CourseTile(id: 'c1', title: 'Course', slug: 'c'),
      score: const LessonScore(
        cuesAttempted: 1,
        cuesCorrect: 1,
        accuracy: 1.0,
        grade: Grade.a,
      ),
      cues: const [
        CueOutcome(
          cueId: 'cue-attempted',
          atMs: 1000,
          type: CueType.mcq,
          prompt: 'Capital of France?',
          attempted: true,
          correct: true,
          scoreJson: {'selected': 1},
          explanation: 'France -> Paris',
          yourAnswerSummary: 'Choice 2',
          correctAnswerSummary: 'Paris',
        ),
        // SECURITY invariant: unattempted cue — `correctAnswerSummary`
        // MUST be null and the widget must not render a "Correct: ..."
        // line. The server already enforces null here; this test is the
        // client-side belt-and-braces.
        CueOutcome(
          cueId: 'cue-unattempted',
          atMs: 2000,
          type: CueType.mcq,
          prompt: 'Capital of Germany?',
          attempted: false,
        ),
      ],
    );

Widget _wrap(ProgressRepository repo) {
  final router = GoRouter(
    initialLocation: '/review',
    routes: [
      GoRoute(
        path: '/review',
        builder: (_, __) =>
            LessonReviewScreen(videoId: 'v1', progressRepo: repo),
      ),
      GoRoute(
        path: '/videos/:id/watch',
        builder: (_, __) => const Scaffold(body: Text('watch')),
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

  testWidgets('renders attempted + unattempted cues; honours security invariant',
      (tester) async {
    when(() => repo.fetchLesson('v1')).thenAnswer((_) async => _review());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review.appBar')), findsOneWidget);
    expect(find.byKey(const Key('review.header.score')), findsOneWidget);
    expect(find.byKey(const Key('review.cue.cue-attempted')), findsOneWidget);
    expect(find.byKey(const Key('review.cue.cue-unattempted')), findsOneWidget);

    // Attempted cue DOES show "Correct: Paris".
    expect(
      find.byKey(const Key('review.cue.cue-attempted.correctAnswer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('review.cue.cue-attempted.yourAnswer')),
      findsOneWidget,
    );

    // SECURITY: unattempted cue MUST NOT show the correct-answer or
    // your-answer text — only the "Not attempted yet" marker.
    expect(
      find.byKey(const Key('review.cue.cue-unattempted.correctAnswer')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('review.cue.cue-unattempted.yourAnswer')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('review.cue.cue-unattempted.unattempted')),
      findsOneWidget,
    );
  });

  testWidgets('shows error with retry on ApiException', (tester) async {
    when(() => repo.fetchLesson('v1')).thenThrow(
      const ApiException(
        code: 'UNAUTHORIZED',
        statusCode: 401,
        message: 'Not authenticated',
      ),
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.text('Not authenticated'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });
}
