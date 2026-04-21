import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/security/export_data_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:share_plus/share_plus.dart';

class _MockMeRepo extends Mock implements MeRepository {}

class _FakeXFile extends Fake implements XFile {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeXFile());
  });

  late _MockMeRepo repo;
  late Directory tmpDir;

  setUp(() async {
    repo = _MockMeRepo();
    tmpDir = await Directory.systemTemp.createTemp('lf-export-test-');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  /// Wraps the screen with injectable repo + test doubles for docs-dir,
  /// file write, and share-sheet invocation. The injected doubles
  /// bypass real dart:io so the test stays in the fake-async zone
  /// testWidgets uses.
  Widget wrap({
    required List<XFile> Function(List<XFile> files) captureShare,
    Map<String, String>? capturedWrites,
  }) {
    return MaterialApp(
      home: ExportDataScreen(
        meRepo: repo,
        docsDirResolver: () async => tmpDir,
        fileWriter: (path, contents) async {
          capturedWrites?[path] = contents;
        },
        shareFn: (files, {subject}) async {
          captureShare(files);
          return ShareResult('captured', ShareResultStatus.success);
        },
      ),
    );
  }

  testWidgets('renders explanation and export button', (tester) async {
    await tester.pumpWidget(
      wrap(captureShare: (_) => <XFile>[]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Export my data'), findsOneWidget);
    expect(find.text('What\'s in the export'), findsOneWidget);
    expect(find.text('What\'s NOT included'), findsOneWidget);
    expect(find.byKey(const Key('exportData.export')), findsOneWidget);
  });

  testWidgets(
      'happy path: tapping Export calls repo, writes a JSON file, triggers share, shows success',
      (tester) async {
    List<XFile>? sharedFiles;
    final writes = <String, String>{};
    when(() => repo.exportMyData()).thenAnswer((_) async => <String, dynamic>{
          'schemaVersion': 1,
          'exportedAt': '2026-04-20T00:00:00.000Z',
          'user': <String, dynamic>{
            'id': 'u1',
            'email': 'u@example.local',
          },
          'enrollments': <dynamic>[],
          'attempts': <dynamic>[],
          'analyticsEvents': <dynamic>[],
          'analyticsEventsTruncated': false,
          'achievements': <dynamic>[],
          'sessions': <dynamic>[],
          'ownedCoursesCount': 0,
          'collaboratorCoursesCount': 0,
        });

    await tester.pumpWidget(
      wrap(
        captureShare: (files) => sharedFiles = files,
        capturedWrites: writes,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exportData.export')));
    // All awaited work inside `_export()` runs on the fake-async zone
    // because the injected doubles replace real dart:io — so a handful
    // of pumps is enough to drain the chain. Can't use `pumpAndSettle`
    // because the CircularProgressIndicator shown during loading would
    // animate forever and time out.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (sharedFiles != null) break;
    }

    verify(() => repo.exportMyData()).called(1);
    expect(sharedFiles, isNotNull);
    expect(sharedFiles!, hasLength(1));
    expect(sharedFiles!.first.path, contains('lifestream-learn-export-'));
    expect(sharedFiles!.first.path, endsWith('.json'));

    // The fileWriter was invoked with the export JSON.
    expect(writes, hasLength(1));
    final writtenContents = writes.values.first;
    expect(writtenContents, contains('"schemaVersion"'));
    expect(writtenContents, contains('"u@example.local"'));

    // Success card is visible.
    await tester.pump();
    expect(find.byKey(const Key('exportData.successCard')), findsOneWidget);
  });

  testWidgets(
      'rate limit: ExportRateLimitException shows friendly hours message',
      (tester) async {
    when(() => repo.exportMyData()).thenThrow(
      const ExportRateLimitException(retryAfterSeconds: 7200),
    );

    await tester.pumpWidget(
      wrap(captureShare: (_) => <XFile>[]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exportData.export')));
    // Drain the async throw + setState without settling (the progress
    // spinner animates forever under Flutter's test clock).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('exportData.errorCard')), findsOneWidget);
    // 7200s → 2 hours.
    expect(find.textContaining('Try again in 2 hours'), findsOneWidget);
  });

  testWidgets(
      'rate limit: ExportRateLimitException with no retry-after still renders a message',
      (tester) async {
    when(() => repo.exportMyData()).thenThrow(
      const ExportRateLimitException(),
    );

    await tester.pumpWidget(
      wrap(captureShare: (_) => <XFile>[]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exportData.export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('exportData.errorCard')), findsOneWidget);
    expect(find.textContaining('once per day'), findsOneWidget);
  });

  testWidgets('403 (account deleted) shows a deletion-specific message',
      (tester) async {
    when(() => repo.exportMyData()).thenThrow(
      const ApiException(
        code: 'ACCOUNT_DELETED',
        statusCode: 403,
        message: 'Account is pending deletion',
      ),
    );

    await tester.pumpWidget(
      wrap(captureShare: (_) => <XFile>[]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exportData.export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('exportData.errorCard')), findsOneWidget);
    expect(
      find.textContaining('account is pending deletion'),
      findsOneWidget,
    );
  });
}
