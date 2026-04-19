import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/cue.dart';
import 'package:lifestream_learn_app/data/repositories/attempt_repository.dart';
import 'package:lifestream_learn_app/features/cues/matching_cue_widget.dart';
import 'package:mocktail/mocktail.dart';

class _MockAttemptRepository extends Mock implements AttemptRepository {}

Cue _matchingCue() => Cue(
      id: 'c1',
      videoId: 'v1',
      atMs: 0,
      pause: true,
      type: CueType.matching,
      payload: const <String, dynamic>{
        'prompt': 'Match countries to capitals',
        'left': ['France', 'Germany'],
        'right': ['Paris', 'Berlin'],
        'pairs': [
          [0, 0],
          [1, 1],
        ],
      },
      orderIndex: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

AttemptResult _result({
  required bool correct,
  int correctPairs = 0,
  int totalPairs = 2,
}) =>
    AttemptResult(
      attempt: Attempt(
        id: 'a1',
        userId: 'u1',
        videoId: 'v1',
        cueId: 'c1',
        correct: correct,
        submittedAt: DateTime.utc(2026, 1, 1),
      ),
      correct: correct,
      scoreJson: {
        'correctPairs': correctPairs,
        'totalPairs': totalPairs,
      },
    );

void main() {
  late _MockAttemptRepository repo;
  setUp(() => repo = _MockAttemptRepository());

  testWidgets('tap-left then tap-right creates a pair', (tester) async {
    when(() => repo.submit(
          cueId: any(named: 'cueId'),
          response: any(named: 'response'),
        )).thenAnswer((_) async =>
        _result(correct: true, correctPairs: 2, totalPairs: 2));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MatchingCueWidget(
          cue: _matchingCue(),
          attemptRepo: repo,
          onDone: () {},
        ),
      ),
    ));

    // Initially: submit disabled (no pairs).
    final submit = find.byKey(const Key('cue.overlay.submit'));
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);

    await tester.tap(find.byKey(const Key('matching.left.0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('matching.right.0')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('matching.left.1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('matching.right.1')));
    await tester.pump();

    // Submit button should now be enabled.
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    final captured = verify(() => repo.submit(
          cueId: 'c1',
          response: captureAny(named: 'response'),
        )).captured.single as Map<String, dynamic>;
    final userPairs = captured['userPairs'] as List;
    expect(userPairs.length, 2);
    // Pairs should be [[0,0],[1,1]] (order not guaranteed by Map iteration).
    expect(userPairs, containsAll([
      [0, 0],
      [1, 1],
    ]));
    expect(find.byKey(const Key('matching.result')), findsOneWidget);
  });

  testWidgets('tapping a paired right unpairs it (1:1 invariant)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MatchingCueWidget(
          cue: _matchingCue(),
          attemptRepo: repo,
          onDone: () {},
        ),
      ),
    ));

    // Pair (0,0).
    await tester.tap(find.byKey(const Key('matching.left.0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('matching.right.0')));
    await tester.pump();

    // Submit must be enabled.
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('cue.overlay.submit')))
          .onPressed,
      isNotNull,
    );

    // Unpair by tapping the same right.
    await tester.tap(find.byKey(const Key('matching.right.0')));
    await tester.pump();
    // Submit disabled again.
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('cue.overlay.submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('tap-right without left selection is a no-op', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MatchingCueWidget(
          cue: _matchingCue(),
          attemptRepo: repo,
          onDone: () {},
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('matching.right.0')));
    await tester.pump();

    // Submit still disabled (no pair formed).
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('cue.overlay.submit')))
          .onPressed,
      isNull,
    );
  });
}
