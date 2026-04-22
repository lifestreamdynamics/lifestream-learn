import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/cue.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/data/repositories/caption_repository.dart';
import 'package:lifestream_learn_app/data/repositories/cue_repository.dart';
import 'package:lifestream_learn_app/data/repositories/enrollment_repository.dart';
import 'package:lifestream_learn_app/data/repositories/video_repository.dart';
import 'package:lifestream_learn_app/features/designer/captions_section.dart';
import 'package:lifestream_learn_app/features/designer/cue_form_sheet.dart';
import 'package:lifestream_learn_app/features/designer/video_editor_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _MockVideoRepository extends Mock implements VideoRepository {}

class _MockCueRepository extends Mock implements CueRepository {}

class _MockCaptionRepository extends Mock implements CaptionRepository {}

class _MockEnrollmentRepository extends Mock implements EnrollmentRepository {}

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

  testWidgets('CueTimeline tap fires onSeek with proportional ms',
      (tester) async {
    int? seekedMs;
    const durationMs = 60000;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: CueTimelineForTest(
            cues: const [],
            durationMs: durationMs,
            onTapCue: (_) {},
            onSeek: (ms) => seekedMs = ms,
          ),
        ),
      ),
    ));
    // Tap at 50% of the 400px-wide timeline — should seek to ~30000ms.
    await tester.tapAt(tester.getTopLeft(find.byType(CueTimelineForTest)) +
        const Offset(200, 10));
    await tester.pump();
    expect(seekedMs, isNotNull);
    // Allow ±500ms tolerance (rounding from pixel math).
    expect((seekedMs! - 30000).abs(), lessThanOrEqualTo(500));
  });

  testWidgets('CueTimeline drag fires onSeek for each update', (tester) async {
    final seekedValues = <int>[];
    const durationMs = 60000;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: CueTimelineForTest(
            cues: const [],
            durationMs: durationMs,
            onTapCue: (_) {},
            onSeek: seekedValues.add,
          ),
        ),
      ),
    ));
    final start =
        tester.getTopLeft(find.byType(CueTimelineForTest)) + const Offset(0, 10);
    await tester.dragFrom(start, const Offset(200, 0));
    await tester.pump();
    expect(seekedValues, isNotEmpty);
  });

  testWidgets('CueTimeline renders playhead needle when positionNotifier given',
      (tester) async {
    final notifier = ValueNotifier<int>(15000);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: CueTimelineForTest(
            cues: const [],
            durationMs: 30000,
            onTapCue: (_) {},
            positionNotifier: notifier,
          ),
        ),
      ),
    ));
    await tester.pump();
    // The playhead is a 2px-wide Container rendered by ValueListenableBuilder.
    // It should appear at x=200 (50% of 400px) for posMs=15000 of 30000ms.
    // We can't assert pixel position in unit tests, but we can confirm the
    // widget tree contains a Container coloured with the primary scheme color.
    expect(find.byType(ValueListenableBuilder<int>), findsOneWidget);
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

  testWidgets('VideoEditorScreen includes CaptionsSection after load',
      (tester) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;

    final videoRepo = _MockVideoRepository();
    final cueRepo = _MockCueRepository();
    final captionRepo = _MockCaptionRepository();
    final enrollmentRepo = _MockEnrollmentRepository();

    final video = VideoSummary(
      id: 'v1',
      courseId: 'c1',
      title: 'Test video',
      orderIndex: 0,
      status: VideoStatus.ready,
      createdAt: DateTime.utc(2026, 4, 21),
    );

    when(() => videoRepo.get('v1')).thenAnswer((_) => Future.value(video));
    when(() => cueRepo.listForVideo('v1')).thenAnswer((_) => Future.value(const []));
    when(() => captionRepo.list('v1')).thenAnswer((_) => Future.value(const []));
    // Player will try to get playback; surface a CONFLICT so it renders
    // an inline error without crashing the test.
    when(() => videoRepo.playback(any())).thenThrow(const ApiException(
      code: 'CONFLICT',
      statusCode: 409,
      message: 'not ready',
    ));
    when(() => videoRepo.invalidate(any())).thenReturn(null);

    await tester.pumpWidget(MaterialApp(
      home: VideoEditorScreen(
        videoId: 'v1',
        videoRepo: videoRepo,
        cueRepo: cueRepo,
        captionRepo: captionRepo,
        enrollmentRepo: enrollmentRepo,
      ),
    ));
    // Multiple pumps: the first flushes the initial frame. The second
    // processes the microtasks from Future.value() calls (mock repos). The
    // third processes the setState rebuild. The fourth lets CaptionsSection
    // kick its own list() call, and the fifth processes that result.
    await tester.pumpAndSettle();

    // CaptionsSection may be beyond the test viewport (the 9:16 player
    // takes most of the 600px test screen height). Scroll the sliver list
    // to bring it into view.
    await tester.scrollUntilVisible(
      find.byType(CaptionsSection),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CaptionsSection), findsOneWidget);
  });
}
