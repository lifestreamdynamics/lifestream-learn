import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/settings/settings_store.dart';

import '../../test_support/fake_secure_storage.dart';

void main() {
  late FakeSecureStoragePlatform fake;
  late SettingsStore store;

  setUp(() {
    fake = FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = fake;
    store = SettingsStore(const FlutterSecureStorage());
  });

  group('SettingsStore defaults (first-launch, no keys stored)', () {
    test('themeMode -> system', () async {
      expect(await store.readThemeMode(), ThemeMode.system);
    });
    test('playbackSpeed -> 1.0', () async {
      expect(await store.readPlaybackSpeed(), 1.0);
    });
    test('captionsDefault -> false', () async {
      expect(await store.readCaptionsDefault(), false);
    });
    test('dataSaver -> false', () async {
      expect(await store.readDataSaver(), false);
    });
    test('analyticsEnabled -> true (matches existing default)', () async {
      expect(await store.readAnalyticsEnabled(), true);
    });
    test('crashReportingEnabled -> false (do not opt users in)', () async {
      expect(await store.readCrashReportingEnabled(), false);
    });
    test('textScaleMultiplier -> 1.0', () async {
      expect(await store.readTextScaleMultiplier(), 1.0);
    });
    test('reduceMotion -> false', () async {
      expect(await store.readReduceMotion(), false);
    });
    test('biometricUnlock -> false', () async {
      expect(await store.readBiometricUnlock(), false);
    });
  });

  group('SettingsStore round-trips', () {
    test('themeMode', () async {
      await store.writeThemeMode(ThemeMode.dark);
      expect(await store.readThemeMode(), ThemeMode.dark);
      await store.writeThemeMode(ThemeMode.light);
      expect(await store.readThemeMode(), ThemeMode.light);
      await store.writeThemeMode(ThemeMode.system);
      expect(await store.readThemeMode(), ThemeMode.system);
    });

    test('playbackSpeed', () async {
      for (final speed in SettingsStore.allowedPlaybackSpeeds) {
        await store.writePlaybackSpeed(speed);
        expect(await store.readPlaybackSpeed(), speed);
      }
    });

    test('playbackSpeed rejects values outside the allowed list', () async {
      expect(
        () => store.writePlaybackSpeed(3.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('captionsDefault', () async {
      await store.writeCaptionsDefault(true);
      expect(await store.readCaptionsDefault(), true);
      await store.writeCaptionsDefault(false);
      expect(await store.readCaptionsDefault(), false);
    });

    test('dataSaver', () async {
      await store.writeDataSaver(true);
      expect(await store.readDataSaver(), true);
    });

    test('analyticsEnabled', () async {
      await store.writeAnalyticsEnabled(false);
      expect(await store.readAnalyticsEnabled(), false);
      await store.writeAnalyticsEnabled(true);
      expect(await store.readAnalyticsEnabled(), true);
    });

    test('crashReportingEnabled', () async {
      await store.writeCrashReportingEnabled(true);
      expect(await store.readCrashReportingEnabled(), true);
    });

    test('textScaleMultiplier', () async {
      for (final scale in SettingsStore.allowedTextScales) {
        await store.writeTextScaleMultiplier(scale);
        expect(await store.readTextScaleMultiplier(), scale);
      }
    });

    test('textScaleMultiplier rejects values outside the allowed list',
        () async {
      expect(
        () => store.writeTextScaleMultiplier(2.5),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('reduceMotion', () async {
      await store.writeReduceMotion(true);
      expect(await store.readReduceMotion(), true);
    });

    test('biometricUnlock', () async {
      await store.writeBiometricUnlock(true);
      expect(await store.readBiometricUnlock(), true);
    });
  });

  group('SettingsStore malformed values fall back to defaults', () {
    test('bogus themeMode string -> system', () async {
      // Simulate a corrupted / future-version write.
      fake.data['settings.themeMode'] = 'plaid';
      expect(await store.readThemeMode(), ThemeMode.system);
    });

    test('non-numeric playbackSpeed -> 1.0', () async {
      fake.data['settings.playbackSpeed'] = 'fast';
      expect(await store.readPlaybackSpeed(), 1.0);
    });

    test('out-of-list playbackSpeed -> 1.0', () async {
      fake.data['settings.playbackSpeed'] = '3.14';
      expect(await store.readPlaybackSpeed(), 1.0);
    });

    test('non-bool string -> default', () async {
      fake.data['settings.dataSaver'] = 'maybe';
      expect(await store.readDataSaver(), false);
    });
  });
}
