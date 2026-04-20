import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/widgets/cue_submission_mixin.dart';
import 'package:lifestream_learn_app/data/models/cue.dart';

/// A thin StatefulWidget whose only job is to expose [CueSubmissionMixin]
/// to the test. It renders a submit button + a result line + an error
/// line driven by the mixin's public getters.
class _Harness extends StatefulWidget {
  const _Harness({required this.onSubmit, this.onAnswered});

  final Future<AttemptResult> Function() onSubmit;
  final void Function(bool correct)? onAnswered;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with CueSubmissionMixin<_Harness> {
  Future<void> _tap() => runSubmission(widget.onSubmit, onAnswered: widget.onAnswered);

  @override
  Widget build(BuildContext context) {
    final res = result;
    return Column(
      children: [
        TextButton(
          key: const Key('harness.submit'),
          onPressed: submitting ? null : _tap,
          child: Text(submitting ? 'submitting' : 'submit'),
        ),
        if (res != null)
          buildResultBanner(
            result: res,
            correctText: 'YES',
            incorrectText: 'NO',
            key: const Key('harness.result'),
          ),
        if (submitError != null)
          Text(submitError!, key: const Key('harness.error')),
      ],
    );
  }
}

AttemptResult _result({required bool correct}) => AttemptResult(
      attempt: Attempt(
        id: 'a1',
        userId: 'u1',
        videoId: 'v1',
        cueId: 'c1',
        correct: correct,
        submittedAt: DateTime.utc(2026, 1, 1),
      ),
      correct: correct,
    );

void main() {
  testWidgets('successful submit flips result and fires onAnswered',
      (tester) async {
    var firedCorrect = false;
    var firedOnce = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _Harness(
          onSubmit: () async => _result(correct: true),
          onAnswered: (c) {
            firedCorrect = c;
            firedOnce++;
          },
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('harness.submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('harness.result')), findsOneWidget);
    expect(find.text('YES'), findsOneWidget);
    expect(firedCorrect, isTrue);
    expect(firedOnce, 1);
  });

  testWidgets('failing submit captures error and skips onAnswered',
      (tester) async {
    var fired = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _Harness(
          onSubmit: () async => throw Exception('nope'),
          onAnswered: (_) => fired++,
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('harness.submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('harness.error')), findsOneWidget);
    expect(find.byKey(const Key('harness.result')), findsNothing);
    expect(fired, 0);
  });

  testWidgets('submit button disables while in flight', (tester) async {
    final done = Completer<AttemptResult>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _Harness(onSubmit: () => done.future),
      ),
    ));

    await tester.tap(find.byKey(const Key('harness.submit')));
    await tester.pump(); // process runSubmission setState

    final btn = tester.widget<TextButton>(find.byKey(const Key('harness.submit')));
    expect(btn.onPressed, isNull);
    expect(find.text('submitting'), findsOneWidget);

    done.complete(_result(correct: false));
    await tester.pumpAndSettle();
    expect(find.text('NO'), findsOneWidget);
  });

  testWidgets('incorrect result renders incorrectText', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _Harness(onSubmit: () async => _result(correct: false)),
      ),
    ));

    await tester.tap(find.byKey(const Key('harness.submit')));
    await tester.pumpAndSettle();

    expect(find.text('NO'), findsOneWidget);
    expect(find.text('YES'), findsNothing);
  });
}
