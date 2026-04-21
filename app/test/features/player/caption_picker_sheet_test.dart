import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/utils/bcp47_labels.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/features/player/caption_picker_sheet.dart';

/// Pumps a button that opens the picker when tapped, then returns the
/// result via a ValueNotifier so tests can assert the returned value.
Widget _harness({
  required List<CaptionTrack> tracks,
  required String? currentLanguage,
  required ValueNotifier<CaptionPickerResult?> resultNotifier,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => ElevatedButton(
          key: const Key('openPicker'),
          onPressed: () async {
            final result = await showCaptionPicker(
              context: ctx,
              tracks: tracks,
              currentLanguage: currentLanguage,
            );
            resultNotifier.value = result;
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

List<CaptionTrack> _tracks(List<String> langs) => langs
    .map(
      (lang) => CaptionTrack(
        language: lang,
        url: 'https://cdn.test/$lang.vtt',
        expiresAt: DateTime.utc(2030, 1, 1),
      ),
    )
    .toList();

void main() {
  group('CaptionPickerSheet', () {
    testWidgets('shows Off row and one row per track with correct labels',
        (tester) async {
      final resultNotifier = ValueNotifier<CaptionPickerResult?>(null);
      await tester.pumpWidget(_harness(
        tracks: _tracks(['en', 'fr']),
        currentLanguage: 'en',
        resultNotifier: resultNotifier,
      ));

      await tester.tap(find.byKey(const Key('openPicker')));
      await tester.pumpAndSettle();

      // "Off" row is present.
      expect(find.byKey(const Key('captionPicker.off')), findsOneWidget);

      // English row with correct label.
      expect(
        find.byKey(const Key('captionPicker.lang.en')),
        findsOneWidget,
      );
      expect(find.text(captionLanguageLabel('en')), findsOneWidget);

      // French row.
      expect(
        find.byKey(const Key('captionPicker.lang.fr')),
        findsOneWidget,
      );
      expect(find.text(captionLanguageLabel('fr')), findsOneWidget);
    });

    testWidgets('checkmark appears on the currently selected language',
        (tester) async {
      final resultNotifier = ValueNotifier<CaptionPickerResult?>(null);
      await tester.pumpWidget(_harness(
        tracks: _tracks(['en', 'fr']),
        currentLanguage: 'en',
        resultNotifier: resultNotifier,
      ));

      await tester.tap(find.byKey(const Key('openPicker')));
      await tester.pumpAndSettle();

      // 'en' is current — its check icon is visible.
      expect(
        find.byKey(const Key('captionPicker.lang.en.check')),
        findsOneWidget,
      );
      // 'fr' is NOT current — no check.
      expect(
        find.byKey(const Key('captionPicker.lang.fr.check')),
        findsNothing,
      );
      // Off is also not checked (something is selected).
      expect(
        find.byKey(const Key('captionPicker.off.check')),
        findsNothing,
      );
    });

    testWidgets('checkmark on Off when currentLanguage is null', (tester) async {
      final resultNotifier = ValueNotifier<CaptionPickerResult?>(null);
      await tester.pumpWidget(_harness(
        tracks: _tracks(['en']),
        currentLanguage: null,
        resultNotifier: resultNotifier,
      ));

      await tester.tap(find.byKey(const Key('openPicker')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('captionPicker.off.check')),
        findsOneWidget,
      );
    });

    testWidgets('tapping Off returns result.off == true', (tester) async {
      final resultNotifier = ValueNotifier<CaptionPickerResult?>(null);
      await tester.pumpWidget(_harness(
        tracks: _tracks(['en']),
        currentLanguage: 'en',
        resultNotifier: resultNotifier,
      ));

      await tester.tap(find.byKey(const Key('openPicker')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('captionPicker.off')));
      await tester.pumpAndSettle();

      expect(resultNotifier.value, isNotNull);
      expect(resultNotifier.value!.off, isTrue);
      expect(resultNotifier.value!.cancelled, isFalse);
      expect(resultNotifier.value!.language, isNull);
    });

    testWidgets('tapping a language row returns result.language == that code',
        (tester) async {
      final resultNotifier = ValueNotifier<CaptionPickerResult?>(null);
      await tester.pumpWidget(_harness(
        tracks: _tracks(['en', 'fr']),
        currentLanguage: null,
        resultNotifier: resultNotifier,
      ));

      await tester.tap(find.byKey(const Key('openPicker')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('captionPicker.lang.fr')));
      await tester.pumpAndSettle();

      expect(resultNotifier.value, isNotNull);
      expect(resultNotifier.value!.language, 'fr');
      expect(resultNotifier.value!.off, isFalse);
      expect(resultNotifier.value!.cancelled, isFalse);
    });

    testWidgets('dismissing the sheet returns result.cancelled == true',
        (tester) async {
      final resultNotifier = ValueNotifier<CaptionPickerResult?>(null);
      await tester.pumpWidget(_harness(
        tracks: _tracks(['en']),
        currentLanguage: 'en',
        resultNotifier: resultNotifier,
      ));

      await tester.tap(find.byKey(const Key('openPicker')));
      await tester.pumpAndSettle();

      // Dismiss by tapping the scrim (the area outside the sheet).
      await tester.tapAt(const Offset(200, 50));
      await tester.pumpAndSettle();

      expect(resultNotifier.value, isNotNull);
      expect(resultNotifier.value!.cancelled, isTrue);
      expect(resultNotifier.value!.off, isFalse);
      expect(resultNotifier.value!.language, isNull);
    });
  });
}
