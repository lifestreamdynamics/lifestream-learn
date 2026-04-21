import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/settings/settings_cubit.dart';
import 'package:lifestream_learn_app/core/settings/settings_store.dart';
import 'package:lifestream_learn_app/features/profile/settings/appearance_section.dart';

import '../../../test_support/fake_secure_storage.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  testWidgets('selecting Dark dispatches setThemeMode and persists',
      (tester) async {
    final store = SettingsStore(const FlutterSecureStorage());
    final cubit = SettingsCubit(store: store);
    await cubit.load();

    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: const MaterialApp(home: AppearanceSection()),
      ),
    );
    await tester.pumpAndSettle();

    // Initial state is System.
    expect(cubit.state.themeMode, ThemeMode.system);

    // Tap the Dark segment.
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(cubit.state.themeMode, ThemeMode.dark);
    expect(await store.readThemeMode(), ThemeMode.dark);

    await cubit.close();
  });
}
