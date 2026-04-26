import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/core/utils/bcp47_labels.dart';
import 'package:lifestream_learn_app/data/models/caption.dart';
import 'package:lifestream_learn_app/data/repositories/caption_repository.dart';
import 'package:lifestream_learn_app/features/designer/captions_section.dart';
import 'package:mocktail/mocktail.dart';

class _MockCaptionRepository extends Mock implements CaptionRepository {}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void _registerFallbacks() {
  registerFallbackValue(Uint8List(0));
}

CaptionSummary _summary({String language = 'en', int bytes = 1024}) =>
    CaptionSummary(
      language: language,
      bytes: bytes,
      uploadedAt: DateTime.utc(2026, 4, 21),
    );

CaptionUploadResult _uploadResult({String language = 'en', int bytes = 512}) =>
    CaptionUploadResult(
      language: language,
      bytes: bytes,
      uploadedAt: DateTime.utc(2026, 4, 21),
    );

void main() {
  setUpAll(_registerFallbacks);

  late _MockCaptionRepository repo;

  setUp(() {
    repo = _MockCaptionRepository();
  });

  testWidgets('shows empty state when list returns empty', (tester) async {
    when(() => repo.list('v1')).thenAnswer((_) async => const []);

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
    )));
    await tester.pumpAndSettle();

    expect(find.text('No captions yet — add a language to let learners follow along.'),
        findsOneWidget);
  });

  testWidgets('renders a row for each uploaded language', (tester) async {
    when(() => repo.list('v1')).thenAnswer(
      (_) async => [_summary(language: 'en'), _summary(language: 'fr')],
    );

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('captions.row.en')), findsOneWidget);
    expect(find.byKey(const Key('captions.row.fr')), findsOneWidget);
    expect(find.text(captionLanguageLabel('en')), findsOneWidget);
    expect(find.text(captionLanguageLabel('fr')), findsOneWidget);
  });

  testWidgets(
      'renders Default chip on the row matching defaultCaptionLanguage',
      (tester) async {
    when(() => repo.list('v1')).thenAnswer(
      (_) async => [_summary(language: 'en'), _summary(language: 'fr')],
    );

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
      defaultCaptionLanguage: 'fr',
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('captions.default.fr')), findsOneWidget);
    expect(find.byKey(const Key('captions.default.en')), findsNothing);
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets(
      'no Default chip when defaultCaptionLanguage is null',
      (tester) async {
    when(() => repo.list('v1')).thenAnswer(
      (_) async => [_summary(language: 'en'), _summary(language: 'fr')],
    );

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsNothing);
  });

  testWidgets('tapping Add language opens bottom sheet', (tester) async {
    when(() => repo.list('v1')).thenAnswer((_) async => const []);

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('captions.addLanguage')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('captions.upload')), findsOneWidget);
    expect(find.byKey(const Key('captions.cancel')), findsOneWidget);
  });

  testWidgets('tapping delete icon shows confirmation dialog; confirming calls delete',
      (tester) async {
    when(() => repo.list('v1'))
        .thenAnswer((_) async => [_summary(language: 'en')]);
    when(() => repo.delete(videoId: 'v1', language: 'en'))
        .thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('captions.delete.en')));
    await tester.pumpAndSettle();

    // Confirmation dialog should appear.
    expect(find.text('Delete caption?'), findsOneWidget);

    // Confirm deletion.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => repo.delete(videoId: 'v1', language: 'en')).called(1);
    // Row is removed after successful delete.
    expect(find.byKey(const Key('captions.row.en')), findsNothing);
  });

  testWidgets('cancelling delete dialog does NOT call delete', (tester) async {
    when(() => repo.list('v1'))
        .thenAnswer((_) async => [_summary(language: 'en')]);

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('captions.delete.en')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.delete(videoId: any(named: 'videoId'), language: any(named: 'language')));
    expect(find.byKey(const Key('captions.row.en')), findsOneWidget);
  });

  testWidgets('list error shows error message and retry button', (tester) async {
    when(() => repo.list('v1')).thenThrow(const ApiException(
      code: 'NETWORK_ERROR',
      statusCode: 0,
      message: 'Connection refused',
    ));

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Connection refused'), findsOneWidget);
    expect(find.byKey(const Key('captions.retry')), findsOneWidget);
  });

  testWidgets('retry button re-calls list and shows rows on success',
      (tester) async {
    var callCount = 0;
    when(() => repo.list('v1')).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Connection refused',
        );
      }
      return [_summary(language: 'de')];
    });

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('captions.retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('captions.row.de')), findsOneWidget);
  });

  testWidgets('upload via bottom sheet with injected file picker calls repo.upload',
      (tester) async {
    when(() => repo.list('v1')).thenAnswer((_) async => const []);
    when(
      () => repo.upload(
        videoId: 'v1',
        language: any(named: 'language'),
        bytes: any(named: 'bytes'),
        contentType: any(named: 'contentType'),
        setDefault: any(named: 'setDefault'),
      ),
    ).thenAnswer((_) async => _uploadResult(language: 'en'));

    // Inject a fake file picker that returns a small VTT file.
    final fakeBytes = Uint8List.fromList('WEBVTT\n\n'.codeUnits);
    Future<FilePickerResult?> fakePicker() async => FilePickerResult([
          PlatformFile(
            name: 'subs.vtt',
            size: fakeBytes.length,
            bytes: fakeBytes,
          ),
        ]);

    await tester.pumpWidget(_wrap(CaptionsSection(
      videoId: 'v1',
      captionRepo: repo,
      filePicker: fakePicker,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('captions.addLanguage')));
    await tester.pumpAndSettle();

    // Pick a file.
    await tester.tap(find.byKey(const Key('captions.chooseFile')));
    await tester.pumpAndSettle();

    // Upload.
    await tester.tap(find.byKey(const Key('captions.upload')));
    await tester.pumpAndSettle();

    verify(
      () => repo.upload(
        videoId: 'v1',
        language: any(named: 'language'),
        bytes: any(named: 'bytes'),
        contentType: 'text/vtt',
        setDefault: false,
      ),
    ).called(1);

    // Sheet dismissed; new row visible.
    expect(find.byKey(const Key('captions.row.en')), findsOneWidget);
  });
}
