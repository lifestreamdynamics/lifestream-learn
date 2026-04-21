import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/analytics/analytics_buffer.dart';
import 'package:lifestream_learn_app/core/crash/crash_consent_bloc.dart';
import 'package:lifestream_learn_app/core/crash/crash_reporter.dart';
import 'package:lifestream_learn_app/core/crash/secure_storage_backend.dart';
import 'package:lifestream_learn_app/core/settings/settings_cubit.dart';
import 'package:lifestream_learn_app/core/settings/settings_store.dart';
import 'package:lifestream_learn_app/data/repositories/events_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../test_support/fake_secure_storage.dart';

class _MockEventsRepo extends Mock implements EventsRepository {}

Future<Directory> _makeTempDir() => Directory.systemTemp.createTemp('lf-sc-');

void main() {
  late FakeSecureStoragePlatform platform;
  late SettingsStore store;
  late AnalyticsBuffer buffer;
  late CrashConsentBloc crashBloc;

  setUpAll(() {
    registerFallbackValue(<Object>[]);
  });

  setUp(() async {
    platform = FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = platform;
    store = SettingsStore(const FlutterSecureStorage());
    final tmp = await _makeTempDir();
    final repo = _MockEventsRepo();
    when(() => repo.submitBatch(any())).thenAnswer((_) async {});
    buffer = AnalyticsBuffer(
      repo: repo,
      docsDirResolver: () async => tmp,
    );
    crashBloc = CrashConsentBloc(
      reporter: CrashReporter.disabled(),
      storage: SecureStorageBackend(const FlutterSecureStorage()),
    );
  });

  tearDown(() async {
    await buffer.dispose();
    await crashBloc.close();
  });

  group('SettingsCubit.load', () {
    test('first-launch: emits defaults with loaded=true', () async {
      final cubit = SettingsCubit(store: store, analyticsBuffer: buffer);
      expect(cubit.state.loaded, false);
      await cubit.load();
      expect(cubit.state.themeMode, ThemeMode.system);
      expect(cubit.state.playbackSpeed, 1.0);
      expect(cubit.state.analyticsEnabled, true);
      expect(cubit.state.reduceMotion, false);
      expect(cubit.state.loaded, true);
      // Buffer gate set to enabled (matches default).
      expect(buffer.isEnabled, true);
      await cubit.close();
    });

    test('rehydrates persisted values', () async {
      await store.writeThemeMode(ThemeMode.dark);
      await store.writePlaybackSpeed(1.5);
      await store.writeAnalyticsEnabled(false);
      await store.writeReduceMotion(true);
      await store.writeTextScaleMultiplier(1.15);

      final cubit = SettingsCubit(store: store, analyticsBuffer: buffer);
      await cubit.load();

      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(cubit.state.playbackSpeed, 1.5);
      expect(cubit.state.analyticsEnabled, false);
      expect(cubit.state.reduceMotion, true);
      expect(cubit.state.textScaleMultiplier, 1.15);
      // Opt-out flipped the buffer gate.
      expect(buffer.isEnabled, false);
      await cubit.close();
    });

    test('reflects CrashConsentBloc granted state', () async {
      crashBloc.add(const CrashConsentGranted());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(crashBloc.state, CrashConsentStatus.granted);

      final cubit = SettingsCubit(
        store: store,
        analyticsBuffer: buffer,
        crashConsentBloc: crashBloc,
      );
      await cubit.load();
      expect(cubit.state.crashReportingEnabled, true);
      await cubit.close();
    });
  });

  group('SettingsCubit setters', () {
    test('setThemeMode persists and emits', () async {
      final cubit = SettingsCubit(store: store);
      await cubit.load();
      await cubit.setThemeMode(ThemeMode.dark);
      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(await store.readThemeMode(), ThemeMode.dark);
      await cubit.close();
    });

    test('setPlaybackSpeed persists and emits', () async {
      final cubit = SettingsCubit(store: store);
      await cubit.load();
      await cubit.setPlaybackSpeed(1.25);
      expect(cubit.state.playbackSpeed, 1.25);
      await cubit.close();
    });

    test('setAnalyticsEnabled flips buffer gate', () async {
      final cubit = SettingsCubit(store: store, analyticsBuffer: buffer);
      await cubit.load();
      expect(buffer.isEnabled, true);

      await cubit.setAnalyticsEnabled(false);
      expect(cubit.state.analyticsEnabled, false);
      expect(buffer.isEnabled, false);

      await cubit.setAnalyticsEnabled(true);
      expect(buffer.isEnabled, true);
      await cubit.close();
    });

    test('setCrashReporting dispatches on the CrashConsentBloc', () async {
      final cubit = SettingsCubit(
        store: store,
        crashConsentBloc: crashBloc,
      );
      await cubit.load();

      await cubit.setCrashReporting(true);
      // Let the bloc event loop settle.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(crashBloc.state, CrashConsentStatus.granted);
      expect(cubit.state.crashReportingEnabled, true);

      await cubit.setCrashReporting(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(crashBloc.state, CrashConsentStatus.denied);
      await cubit.close();
    });

    test('setReduceMotion persists', () async {
      final cubit = SettingsCubit(store: store);
      await cubit.load();
      await cubit.setReduceMotion(true);
      expect(cubit.state.reduceMotion, true);
      expect(await store.readReduceMotion(), true);
      await cubit.close();
    });

    test('setTextScaleMultiplier persists', () async {
      final cubit = SettingsCubit(store: store);
      await cubit.load();
      await cubit.setTextScaleMultiplier(1.3);
      expect(cubit.state.textScaleMultiplier, 1.3);
      await cubit.close();
    });

    test('setBiometricUnlock persists', () async {
      final cubit = SettingsCubit(store: store);
      await cubit.load();
      await cubit.setBiometricUnlock(true);
      expect(cubit.state.biometricUnlock, true);
      await cubit.close();
    });
  });

  group('SettingsCubit mirrors CrashConsentBloc changes', () {
    test('external grant updates state.crashReportingEnabled', () async {
      final cubit = SettingsCubit(
        store: store,
        crashConsentBloc: crashBloc,
      );
      await cubit.load();
      expect(cubit.state.crashReportingEnabled, false);

      crashBloc.add(const CrashConsentGranted());
      // Let both the bloc and the subscription propagate.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.crashReportingEnabled, true);
      await cubit.close();
    });
  });
}
