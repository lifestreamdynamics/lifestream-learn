import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/cue.dart';
import 'package:lifestream_learn_app/features/designer/cue_form_sheet.dart';
import 'package:lifestream_learn_app/features/designer/video_editor_screen.dart';

Cue _cue({
  required String id,
  required int atMs,
  CueType type = CueType.mcq,
}) =>
    Cue(
      id: id,
      videoId: 'v1',
      atMs: atMs,
      pause: true,
      type: type,
      payload: const <String, dynamic>{},
      orderIndex: 0,
      createdAt: DateTime.utc(2026, 4, 19),
      updatedAt: DateTime.utc(2026, 4, 19),
    );

void main() {
  testWidgets('CueTimeline renders a marker per cue at proportional x',
      (tester) async {
    final cues = [
      _cue(id: 'a', atMs: 0),
      _cue(id: 'b', atMs: 15000),
      _cue(id: 'c', atMs: 30000),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: CueTimelineForTest(
            cues: cues,
            durationMs: 30000,
            onTapCue: (_) {},
          ),
        ),
      ),
    ));
    for (final c in cues) {
      expect(find.byKey(Key('video.marker.${c.id}')), findsOneWidget);
    }
  });

  testWidgets('CueTimeline does not render markers when duration is 0',
      (tester) async {
    final cues = [_cue(id: 'a', atMs: 0)];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CueTimelineForTest(
          cues: cues,
          durationMs: 0,
          onTapCue: (_) {},
        ),
      ),
    ));
    expect(find.byKey(const Key('video.marker.a')), findsNothing);
  });

  testWidgets('CueFormSheet: Add cue opens picker with MCQ/BLANKS/MATCHING '
      '(no VOICE)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: const CueFormSheet()),
    ));
    // Tap the dropdown to expand it.
    await tester.tap(find.byKey(const Key('cueform.type')));
    await tester.pumpAndSettle();
    // Must list the 3 types; NEVER 'Voice prompt'.
    expect(find.text('Multiple choice'), findsWidgets);
    expect(find.text('Fill in the blanks'), findsWidgets);
    expect(find.text('Matching'), findsWidgets);
    expect(find.text('Voice'), findsNothing);
    expect(find.text('Voice prompt'), findsNothing);
  });

  testWidgets('CueFormSheet: MCQ validation blocks submission', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: const CueFormSheet()),
    ));
    // Leave all fields blank, click Save cue — errors should render.
    await tester.tap(find.byKey(const Key('cueform.submit')));
    await tester.pump();
    expect(find.byKey(const Key('cueform.errors')), findsOneWidget);
  });

  testWidgets('CueFormSheet: filled MCQ returns valid CueFormResult',
      (tester) async {
    CueFormResult? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            key: const Key('launch'),
            onPressed: () async {
              captured = await showModalBottomSheet<CueFormResult>(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => const CueFormSheet(),
              );
            },
            child: const Text('launch'),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('launch')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('cueform.mcq.question')),
      'A or B?',
    );
    await tester.enterText(find.byKey(const Key('cueform.mcq.choice.0')), 'A');
    await tester.enterText(find.byKey(const Key('cueform.mcq.choice.1')), 'B');
    await tester.tap(find.byKey(const Key('cueform.mcq.answer.1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cueform.submit')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.type, CueType.mcq);
    final payload = captured!.payload;
    expect(payload['question'], 'A or B?');
    expect(payload['choices'], ['A', 'B']);
    expect(payload['answerIndex'], 1);
  });
}
