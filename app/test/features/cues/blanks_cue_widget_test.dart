import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/cue.dart';
import 'package:lifestream_learn_app/data/repositories/attempt_repository.dart';
import 'package:lifestream_learn_app/features/cues/blanks_cue_widget.dart';
import 'package:mocktail/mocktail.dart';

class _MockAttemptRepository extends Mock implements AttemptRepository {}

Cue _blanksCue() => Cue(
      id: 'c1',
      videoId: 'v1',
      atMs: 0,
      pause: true,
      type: CueType.blanks,
      payload: const <String, dynamic>{
        'sentenceTemplate': 'The capital of France is {{0}}.',
        'blanks': [
          {
            'accept': ['Paris'],
          },
        ],
      },
      orderIndex: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

AttemptResult _result({
  required bool correct,
  required List<bool> perBlank,
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
      scoreJson: {'perBlank': perBlank},
    );

void main() {
  group('parseTemplate', () {
    test('interleaves text + blank segments', () {
      final segs = debugParseTemplate('Hello {{0}} and {{1}} goodbye');
      expect(segs.length, 5);
      expect(describeSegment(segs[0]).text, 'Hello ');
      expect(describeSegment(segs[1]).blankIndex, 0);
      expect(describeSegment(segs[2]).text, ' and ');
      expect(describeSegment(segs[3]).blankIndex, 1);
      expect(describeSegment(segs[4]).text, ' goodbye');
    });

    test('leading placeholder produces no leading text segment', () {
      final segs = debugParseTemplate('{{0}} trailing');
      expect(segs.length, 2);
      expect(describeSegment(segs[0]).blankIndex, 0);
    });
  });

  group('BlanksCueWidget', () {
    late _MockAttemptRepository repo;
    setUp(() => repo = _MockAttemptRepository());

    testWidgets('template parsing renders text + field', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BlanksCueWidget(
            cue: _blanksCue(),
            attemptRepo: repo,
            onDone: () {},
          ),
        ),
      ));
      expect(find.byKey(const Key('blanks.template')), findsOneWidget);
      expect(find.byKey(const Key('blanks.field.0')), findsOneWidget);
      expect(find.text('The capital of France is '), findsOneWidget);
    });

    testWidgets('submit POSTs {answers: [...]}', (tester) async {
      when(() => repo.submit(
            cueId: any(named: 'cueId'),
            response: any(named: 'response'),
          )).thenAnswer((_) async =>
          _result(correct: true, perBlank: [true]));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BlanksCueWidget(
            cue: _blanksCue(),
            attemptRepo: repo,
            onDone: () {},
          ),
        ),
      ));

      await tester.enterText(
        find.byKey(const Key('blanks.field.0')),
        'Paris',
      );
      await tester.tap(find.byKey(const Key('cue.overlay.submit')));
      await tester.pumpAndSettle();

      verify(() => repo.submit(
            cueId: 'c1',
            response: <String, dynamic>{
              'answers': ['Paris'],
            },
          )).called(1);
      expect(find.byKey(const Key('blanks.result')), findsOneWidget);
    });

    testWidgets('per-blank correctness diff renders on result', (tester) async {
      when(() => repo.submit(
            cueId: any(named: 'cueId'),
            response: any(named: 'response'),
          )).thenAnswer((_) async =>
          _result(correct: false, perBlank: [false]));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BlanksCueWidget(
            cue: _blanksCue(),
            attemptRepo: repo,
            onDone: () {},
          ),
        ),
      ));
      await tester.enterText(
        find.byKey(const Key('blanks.field.0')),
        'London',
      );
      await tester.tap(find.byKey(const Key('cue.overlay.submit')));
      await tester.pumpAndSettle();

      expect(find.text('Some blanks are wrong.'), findsOneWidget);
    });
  });
}
