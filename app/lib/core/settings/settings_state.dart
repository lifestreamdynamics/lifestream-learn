import 'package:flutter/material.dart';

/// Immutable snapshot of the user's application preferences.
///
/// Deliberately a hand-rolled class rather than a `@freezed` one — the
/// state is small, the surface is stable, and adding a freezed class
/// here would require a build_runner codegen step during tests that
/// don't currently need one. If this class grows or gains JSON
/// serialization, migrating to freezed is mechanical.
@immutable
class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.playbackSpeed = 1.0,
    this.captionsDefault = false,
    this.dataSaver = false,
    this.analyticsEnabled = true,
    this.crashReportingEnabled = false,
    this.textScaleMultiplier = 1.0,
    this.reduceMotion = false,
    this.biometricUnlock = false,
    this.loaded = false,
  });

  /// Initial/idle state before the cubit has read anything from disk.
  /// The [loaded] flag stays false so callers can distinguish "first
  /// paint, defaults only" from "defaults confirmed by storage".
  const SettingsState.initial() : this();

  final ThemeMode themeMode;

  /// One of [SettingsStore.allowedPlaybackSpeeds].
  final double playbackSpeed;

  /// Default state of the captions toggle on new playback sessions.
  /// (Captions themselves are not yet implemented; see TODO in the
  /// player.)
  final bool captionsDefault;

  /// When true, cap ABR at 540p on cellular. UI-only today; wiring a
  /// real bandwidth cap needs `connectivity_plus` which isn't a dep.
  final bool dataSaver;

  /// When false, the AnalyticsBuffer refuses new events and purges the
  /// on-disk queue on next flush.
  final bool analyticsEnabled;

  /// Mirror of the CrashConsentBloc's `granted` state. The bloc remains
  /// the source of truth; the cubit keeps this synced so the Settings
  /// UI can render a single toggle.
  final bool crashReportingEnabled;

  /// One of [SettingsStore.allowedTextScales].
  final double textScaleMultiplier;

  /// When true, widgets that animate by default (cue overlays, feed
  /// transitions) short-circuit to zero-duration renders.
  final bool reduceMotion;

  /// Preference only in P4; P7 wires the actual `local_auth` prompt.
  final bool biometricUnlock;

  /// Flips to true after the cubit has populated the state from
  /// [SettingsStore]. Tests can assert the cubit actually read from
  /// disk (vs. returned defaults synchronously).
  final bool loaded;

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? playbackSpeed,
    bool? captionsDefault,
    bool? dataSaver,
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    double? textScaleMultiplier,
    bool? reduceMotion,
    bool? biometricUnlock,
    bool? loaded,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        captionsDefault: captionsDefault ?? this.captionsDefault,
        dataSaver: dataSaver ?? this.dataSaver,
        analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
        crashReportingEnabled:
            crashReportingEnabled ?? this.crashReportingEnabled,
        textScaleMultiplier:
            textScaleMultiplier ?? this.textScaleMultiplier,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        biometricUnlock: biometricUnlock ?? this.biometricUnlock,
        loaded: loaded ?? this.loaded,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsState &&
          other.themeMode == themeMode &&
          other.playbackSpeed == playbackSpeed &&
          other.captionsDefault == captionsDefault &&
          other.dataSaver == dataSaver &&
          other.analyticsEnabled == analyticsEnabled &&
          other.crashReportingEnabled == crashReportingEnabled &&
          other.textScaleMultiplier == textScaleMultiplier &&
          other.reduceMotion == reduceMotion &&
          other.biometricUnlock == biometricUnlock &&
          other.loaded == loaded;

  @override
  int get hashCode => Object.hash(
        themeMode,
        playbackSpeed,
        captionsDefault,
        dataSaver,
        analyticsEnabled,
        crashReportingEnabled,
        textScaleMultiplier,
        reduceMotion,
        biometricUnlock,
        loaded,
      );
}
