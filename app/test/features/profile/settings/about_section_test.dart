import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/features/profile/settings/about_section.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('renders pubspec-sourced version via PackageInfo', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Lifestream Learn',
      packageName: 'ca.digitalartifacts.lifestream_learn',
      version: '9.9.9',
      buildNumber: '42',
      buildSignature: '',
    );

    await tester.pumpWidget(const MaterialApp(home: AboutSection()));
    await tester.pumpAndSettle();

    // Version tile shows the combined `<version>+<buildNumber>` string.
    final versionTile = find.byKey(const Key('settings.about.version'));
    expect(versionTile, findsOneWidget);
    expect(find.descendant(of: versionTile, matching: find.text('9.9.9+42')),
        findsOneWidget);
  });

  testWidgets('omits "+buildNumber" suffix when buildNumber is empty',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Lifestream Learn',
      packageName: 'ca.digitalartifacts.lifestream_learn',
      version: '1.2.3',
      buildNumber: '',
      buildSignature: '',
    );

    await tester.pumpWidget(const MaterialApp(home: AboutSection()));
    await tester.pumpAndSettle();

    final versionTile = find.byKey(const Key('settings.about.version'));
    expect(find.descendant(of: versionTile, matching: find.text('1.2.3')),
        findsOneWidget);
  });

  testWidgets('falls back to pinned default while the future is resolving',
      (tester) async {
    // A future that never completes — the builder must render the fallback
    // in snapshot-loading state rather than leaving the subtitle blank.
    final neverResolves = Completer<PackageInfo>().future;

    await tester.pumpWidget(
      MaterialApp(home: AboutSection(packageInfo: neverResolves)),
    );
    await tester.pump();

    final versionTile = find.byKey(const Key('settings.about.version'));
    expect(find.descendant(of: versionTile, matching: find.text('0.1.0-dev')),
        findsOneWidget);
  });
}
