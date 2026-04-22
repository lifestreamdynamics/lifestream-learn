import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/analytics/analytics_buffer.dart';
import 'package:lifestream_learn_app/core/settings/settings_cubit.dart';
import 'package:lifestream_learn_app/core/settings/settings_store.dart';
import 'package:lifestream_learn_app/data/repositories/events_repository.dart';
import 'package:lifestream_learn_app/features/profile/settings/privacy_section.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../test_support/fake_secure_storage.dart';

class _MockEventsRepo extends Mock implements EventsRepository {}

void main() {
  // Shared tmp dir is created in the regular test zone via `setUp`
  // (not inside a `testWidgets` body). `testWidgets` wraps its body in
  // a FakeAsync-ish zone that doesn't service real filesystem I/O the
  // same way, so `Directory.systemTemp.createTemp()` called from
  // inside it hangs indefinitely. `setUp` runs in the host test zone
  // where real async I/O works as expected.
  late Directory tmp;

  setUpAll(() {
    registerFallbackValue(<Object>[]);
  });

  setUp(() async {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    tmp = await Directory.systemTemp.createTemp('lf-p-');
    // Handle the Clipboard platform channel so `Clipboard.setData` in
    // the fallback path completes instead of hanging on a missing
    // handler. Set/Get symmetric so subsequent tests can also use it.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData' ||
          call.method == 'Clipboard.getData') {
        return null;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  testWidgets(
      'flipping analytics OFF disables the buffer and updates the cubit',
      (tester) async {
    final store = SettingsStore(const FlutterSecureStorage());
    final repo = _MockEventsRepo();
    when(() => repo.submitBatch(any())).thenAnswer((_) async {});
    final buffer = AnalyticsBuffer(
      repo: repo,
      docsDirResolver: () async => tmp,
    );
    final cubit = SettingsCubit(store: store, analyticsBuffer: buffer);
    await cubit.load();
    expect(cubit.state.analyticsEnabled, true);
    expect(buffer.isEnabled, true);

    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: const MaterialApp(home: PrivacySection()),
      ),
    );
    // Avoid `pumpAndSettle` — the Material 3 Switch's ink/sparkle
    // animation can spin for longer than a unit test wants. Explicit
    // pumps are enough to process the cubit emission + SwitchListTile
    // rebuild here; the assertions below probe the cubit state and
    // the disk, not the rendered Switch.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('settings.privacy.analytics')));
    // Drain the cubit's async setter: write → setEnabled → emit.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(cubit.state.analyticsEnabled, false);
    expect(buffer.isEnabled, false,
        reason: 'toggle flips the buffer gate, not a parallel flag');
    expect(await store.readAnalyticsEnabled(), false);

    await cubit.close();
    await buffer.dispose();
  });

  testWidgets(
      'Slice P8 — "Export my data" tile navigates to /profile/export',
      (tester) async {
    final store = SettingsStore(const FlutterSecureStorage());
    final repo = _MockEventsRepo();
    when(() => repo.submitBatch(any())).thenAnswer((_) async {});
    final buffer = AnalyticsBuffer(
      repo: repo,
      docsDirResolver: () async => tmp,
    );
    final cubit = SettingsCubit(store: store, analyticsBuffer: buffer);
    await cubit.load();

    final router = GoRouter(
      initialLocation: '/profile/settings/privacy',
      routes: [
        GoRoute(
          path: '/profile/settings/privacy',
          builder: (_, __) => const PrivacySection(),
        ),
        GoRoute(
          path: '/profile/export',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('export-screen-placeholder')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Ensure the tile is present.
    expect(find.byKey(const Key('settings.privacy.exportData')), findsOneWidget);

    // Tap it — navigation should push /profile/export onto the stack.
    await tester.tap(find.byKey(const Key('settings.privacy.exportData')));
    await tester.pumpAndSettle();

    expect(find.text('export-screen-placeholder'), findsOneWidget);

    await cubit.close();
    await buffer.dispose();
  });

  testWidgets(
      'tapping Privacy Policy invokes launchUrl with externalApplication mode',
      (tester) async {
    final store = SettingsStore(const FlutterSecureStorage());
    final repo = _MockEventsRepo();
    when(() => repo.submitBatch(any())).thenAnswer((_) async {});
    final buffer = AnalyticsBuffer(
      repo: repo,
      docsDirResolver: () async => tmp,
    );
    final cubit = SettingsCubit(store: store, analyticsBuffer: buffer);
    await cubit.load();

    final launched = <(Uri, LaunchMode)>[];
    Future<bool> fakeLauncher(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
      launched.add((uri, mode));
      return true;
    }

    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: PrivacySection(launcher: fakeLauncher),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Scroll to Privacy Policy tile — the 800x600 test viewport may
    // render it below the fold behind the switches.
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.privacy.privacyPolicy')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings.privacy.privacyPolicy')));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.$1.toString(), 'https://learn.REDACTED-BRAND-DOMAIN/privacy');
    expect(launched.single.$2, LaunchMode.externalApplication);

    await cubit.close();
    await buffer.dispose();
  });

  testWidgets(
      'launchUrl failure falls back to clipboard + snackbar',
      (tester) async {
    final store = SettingsStore(const FlutterSecureStorage());
    final repo = _MockEventsRepo();
    when(() => repo.submitBatch(any())).thenAnswer((_) async {});
    final buffer = AnalyticsBuffer(
      repo: repo,
      docsDirResolver: () async => tmp,
    );
    final cubit = SettingsCubit(store: store, analyticsBuffer: buffer);
    await cubit.load();

    // Launcher that rejects every attempt — simulates a locked-down
    // device with no browser resolvable.
    Future<bool> rejectingLauncher(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
      return false;
    }

    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: PrivacySection(launcher: rejectingLauncher),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.privacy.terms')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings.privacy.terms')));
    // Let the async fallback (clipboard write, snackbar show) settle —
    // but cap the pump duration so the Material SnackBar animation
    // doesn't hang pumpAndSettle forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('Copied: https://learn.REDACTED-BRAND-DOMAIN/terms'),
      findsOneWidget,
    );

    await cubit.close();
    await buffer.dispose();
  });
}
