import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/cue.dart';
import 'package:lifestream_learn_app/data/repositories/attempt_repository.dart';
import 'package:lifestream_learn_app/features/cues/mcq_cue_widget.dart';
import 'package:mocktail/mocktail.dart';

class _MockAttemptRepository extends Mock implements AttemptRepository {}

Cue _mcqCue({int answer = 1}) => Cue(
      id: 'c1',
      videoId: 'v1',
      atMs: 0,
      pause: true,
      type: CueType.mcq,
      payload: <String, dynamic>{
        'question': 'Which is a planet?',
        'choices': ['Sun', 'Earth', 'Moon'],
        'answerIndex': answer,
      },
      orderIndex: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

AttemptResult _result({required bool correct, String? explanation}) =>
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
      explanation: explanation,
    );

void main() {
  late _MockAttemptRepository repo;
  setUp(() {
    repo = _MockAttemptRepository();
  });

  testWidgets('renders choices + question', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: McqCueWidget(
          cue: _mcqCue(),
          attemptRepo: repo,
          onDone: () {},
        ),
      ),
    ));
    expect(find.byKey(const Key('mcq.question')), findsOneWidget);
    expect(find.byKey(const Key('mcq.choice.0')), findsOneWidget);
    expect(find.byKey(const Key('mcq.choice.1')), findsOneWidget);
    expect(find.byKey(const Key('mcq.choice.2')), findsOneWidget);
    // Submit button exists but is disabled initially.
    final submit = find.byKey(const Key('cue.overlay.submit'));
    expect(submit, findsOneWidget);
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
  });

  testWidgets('submit POSTs {choiceIndex} + renders result banner',
      (tester) async {
    when(() => repo.submit(
          cueId: any(named: 'cueId'),
          response: any(named: 'response'),
        )).thenAnswer((inv) async => _result(
          correct: true,
          explanation: 'Because it orbits the sun.',
        ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: McqCueWidget(
          cue: _mcqCue(),
          attemptRepo: repo,
          onDone: () {},
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('mcq.choice.1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cue.overlay.submit')));
    await tester.pump(); // submit call + setState
    await tester.pumpAndSettle();

    verify(() => repo.submit(
          cueId: 'c1',
          response: <String, dynamic>{'choiceIndex': 1},
        )).called(1);

    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('Because it orbits the sun.'), findsOneWidget);
    expect(find.byKey(const Key('cue.overlay.continue')), findsOneWidget);
  });

  testWidgets('wrong answer renders "Incorrect." + explanation',
      (tester) async {
    when(() => repo.submit(
          cueId: any(named: 'cueId'),
          response: any(named: 'response'),
        )).thenAnswer((_) async => _result(
          correct: false,
          explanation: 'Think about what orbits the sun.',
        ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: McqCueWidget(
          cue: _mcqCue(),
          attemptRepo: repo,
          onDone: () {},
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('mcq.choice.0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cue.overlay.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect.'), findsOneWidget);
    expect(find.text('Think about what orbits the sun.'), findsOneWidget);
  });

  testWidgets('continue invokes onDone', (tester) async {
    var done = false;
    when(() => repo.submit(
          cueId: any(named: 'cueId'),
          response: any(named: 'response'),
        )).thenAnswer((_) async => _result(correct: true));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: McqCueWidget(
          cue: _mcqCue(),
          attemptRepo: repo,
          onDone: () => done = true,
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('mcq.choice.1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cue.overlay.submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cue.overlay.continue')));
    await tester.pump();
    expect(done, isTrue);
  });
}
