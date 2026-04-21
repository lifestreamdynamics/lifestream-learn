import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin async wrapper around `FlutterSecureStorage` for per-user
/// application preferences. Mirrors the `TokenStore` shape: callers
/// pass in a single `FlutterSecureStorage` instance configured at the
/// composition root (`main.dart`) with
/// `AndroidOptions(encryptedSharedPreferences: true)` so we don't
/// instantiate a second encrypted store.
///
/// Typed accessors parse the stored strings into their semantic types
/// (`ThemeMode`, `double`, `bool`) and silently fall back to defaults
/// when a key is missing or the value is malformed — first-launch users
/// have no keys stored, so every getter must survive a `null` read.
///
/// Writes happen one key at a time; the cubit coordinates them. A torn
/// write (process killed mid-operation) just leaves the one key at its
/// previous value; there's no invariant that requires two keys to be
/// consistent.
class SettingsStore {
  SettingsStore(this._storage);

  final FlutterSecureStorage _storage;

  // --- Key constants ----------------------------------------------------
  static const _kThemeMode = 'settings.themeMode';
  static const _kPlaybackSpeed = 'settings.playbackSpeed';
  static const _kCaptionsDefault = 'settings.captionsDefault';
  static const _kDataSaver = 'settings.dataSaver';
  static const _kAnalyticsEnabled = 'settings.analyticsEnabled';
  static const _kCrashReportingEnabled = 'settings.crashReportingEnabled';
  static const _kTextScaleMultiplier = 'settings.textScaleMultiplier';
  static const _kReduceMotion = 'settings.reduceMotion';
  static const _kBiometricUnlock = 'settings.biometricUnlock';

  // --- Defaults ---------------------------------------------------------
  // Match whatever the app currently ships so first-launch users don't
  // get accidentally opted in to anything.
  static const ThemeMode defaultThemeMode = ThemeMode.system;
  static const double defaultPlaybackSpeed = 1.0;
  static const bool defaultCaptions = false;
  static const bool defaultDataSaver = false;
  // Analytics default ON — consistent with existing buffer default.
  static const bool defaultAnalyticsEnabled = true;
  // Crash reporting default follows the CrashConsentBloc state at read
  // time, not a settings-store read. The cubit reconciles the two.
  static const bool defaultCrashReportingEnabled = false;
  static const double defaultTextScaleMultiplier = 1.0;
  static const bool defaultReduceMotion = false;
  static const bool defaultBiometricUnlock = false;

  /// Allowed playback speeds. Kept as a strict list so UI dropdowns
  /// can't drift from what the parser accepts.
  static const List<double> allowedPlaybackSpeeds = <double>[
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];

  /// Allowed text-scale multipliers.
  static const List<double> allowedTextScales = <double>[0.9, 1.0, 1.15, 1.3];

  // --- Typed getters ----------------------------------------------------

  Future<ThemeMode> readThemeMode() async {
    final raw = await _storage.read(key: _kThemeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return defaultThemeMode;
    }
  }

  Future<double> readPlaybackSpeed() async {
    final raw = await _storage.read(key: _kPlaybackSpeed);
    if (raw == null) return defaultPlaybackSpeed;
    final parsed = double.tryParse(raw);
    if (parsed == null) return defaultPlaybackSpeed;
    if (!allowedPlaybackSpeeds.contains(parsed)) {
      return defaultPlaybackSpeed;
    }
    return parsed;
  }

  Future<bool> readCaptionsDefault() async =>
      _readBool(_kCaptionsDefault, defaultCaptions);

  Future<bool> readDataSaver() async =>
      _readBool(_kDataSaver, defaultDataSaver);

  Future<bool> readAnalyticsEnabled() async =>
      _readBool(_kAnalyticsEnabled, defaultAnalyticsEnabled);

  /// Distinct from [CrashConsentBloc]'s `consent_decision` key — the
  /// cubit mirrors the bloc's state into this key so the Settings UI
  /// can read the current decision synchronously without subscribing
  /// to the bloc. The CrashConsentBloc remains the source of truth;
  /// do not write here directly from outside the cubit.
  Future<bool> readCrashReportingEnabled() async =>
      _readBool(_kCrashReportingEnabled, defaultCrashReportingEnabled);

  Future<double> readTextScaleMultiplier() async {
    final raw = await _storage.read(key: _kTextScaleMultiplier);
    if (raw == null) return defaultTextScaleMultiplier;
    final parsed = double.tryParse(raw);
    if (parsed == null) return defaultTextScaleMultiplier;
    if (!allowedTextScales.contains(parsed)) {
      return defaultTextScaleMultiplier;
    }
    return parsed;
  }

  Future<bool> readReduceMotion() async =>
      _readBool(_kReduceMotion, defaultReduceMotion);

  Future<bool> readBiometricUnlock() async =>
      _readBool(_kBiometricUnlock, defaultBiometricUnlock);

  // --- Typed setters ----------------------------------------------------

  Future<void> writeThemeMode(ThemeMode mode) async {
    final encoded = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _storage.write(key: _kThemeMode, value: encoded);
  }

  Future<void> writePlaybackSpeed(double speed) async {
    if (!allowedPlaybackSpeeds.contains(speed)) {
      throw ArgumentError.value(
        speed,
        'speed',
        'must be one of $allowedPlaybackSpeeds',
      );
    }
    await _storage.write(key: _kPlaybackSpeed, value: speed.toString());
  }

  Future<void> writeCaptionsDefault(bool value) =>
      _writeBool(_kCaptionsDefault, value);

  Future<void> writeDataSaver(bool value) => _writeBool(_kDataSaver, value);

  Future<void> writeAnalyticsEnabled(bool value) =>
      _writeBool(_kAnalyticsEnabled, value);

  Future<void> writeCrashReportingEnabled(bool value) =>
      _writeBool(_kCrashReportingEnabled, value);

  Future<void> writeTextScaleMultiplier(double value) async {
    if (!allowedTextScales.contains(value)) {
      throw ArgumentError.value(
        value,
        'value',
        'must be one of $allowedTextScales',
      );
    }
    await _storage.write(
      key: _kTextScaleMultiplier,
      value: value.toString(),
    );
  }

  Future<void> writeReduceMotion(bool value) =>
      _writeBool(_kReduceMotion, value);

  Future<void> writeBiometricUnlock(bool value) =>
      _writeBool(_kBiometricUnlock, value);

  // --- internals --------------------------------------------------------

  Future<bool> _readBool(String key, bool fallback) async {
    final raw = await _storage.read(key: key);
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    return fallback;
  }

  Future<void> _writeBool(String key, bool value) =>
      _storage.write(key: key, value: value ? 'true' : 'false');
}
