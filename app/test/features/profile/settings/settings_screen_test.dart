import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/settings/settings_cubit.dart';
import 'package:lifestream_learn_app/core/settings/settings_store.dart';
import 'package:lifestream_learn_app/features/profile/settings/about_section.dart';
import 'package:lifestream_learn_app/features/profile/settings/accessibility_section.dart';
import 'package:lifestream_learn_app/features/profile/settings/appearance_section.dart';
import 'package:lifestream_learn_app/features/profile/settings/playback_section.dart';
import 'package:lifestream_learn_app/features/profile/settings/privacy_section.dart';
import 'package:lifestream_learn_app/features/profile/settings/settings_screen.dart';

import '../../../test_support/fake_secure_storage.dart';

Widget _wrap(SettingsCubit cubit) {
  final router = GoRouter(
    initialLocation: '/profile/settings',
    routes: [
      GoRoute(
        path: '/profile/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/settings/appearance',
        builder: (_, __) => const AppearanceSection(),
      ),
      GoRoute(
        path: '/profile/settings/playback',
        builder: (_, __) => const PlaybackSection(),
      ),
      GoRoute(
        path: '/profile/settings/privacy',
        builder: (_, __) => const PrivacySection(),
      ),
      GoRoute(
        path: '/profile/settings/accessibility',
        builder: (_, __) => const AccessibilitySection(),
      ),
      GoRoute(
        path: '/profile/settings/about',
        builder: (_, __) => const AboutSection(),
      ),
    ],
  );
  return BlocProvider<SettingsCubit>.value(
    value: cubit,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  SettingsCubit buildCubit() {
    final store = SettingsStore(const FlutterSecureStorage());
    return SettingsCubit(store: store);
  }

  testWidgets('hub renders five category tiles', (tester) async {
    final cubit = buildCubit();
    await cubit.load();
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings.entry.appearance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings.entry.playback')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings.entry.privacy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings.entry.accessibility')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings.entry.about')), findsOneWidget);

    await cubit.close();
  });

  testWidgets('tapping Appearance navigates to the appearance screen',
      (tester) async {
    final cubit = buildCubit();
    await cubit.load();
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings.entry.appearance')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings.appearance.themeMode')),
      findsOneWidget,
    );
    await cubit.close();
  });

  testWidgets('tapping Privacy navigates to the privacy screen',
      (tester) async {
    final cubit = buildCubit();
    await cubit.load();
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings.entry.privacy')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings.privacy.analytics')),
      findsOneWidget,
    );
    await cubit.close();
  });
}
