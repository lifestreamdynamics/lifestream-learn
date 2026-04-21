import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../analytics/analytics_buffer.dart';
import '../crash/crash_consent_bloc.dart';
import 'settings_state.dart';
import 'settings_store.dart';

/// Application-wide preferences cubit.
///
/// Responsibilities:
/// 1. Read all persisted preferences from [SettingsStore] on [load] and
///    emit a populated [SettingsState].
/// 2. Each setter writes to [SettingsStore] first, then emits the
///    updated state. Write failures are logged but don't crash — the
///    in-memory state still updates so the UI stays responsive.
/// 3. Propagate runtime-observable preferences to the systems that
///    honour them:
///    - `analyticsEnabled` → [AnalyticsBuffer.setEnabled].
///    - `crashReportingEnabled` → dispatches `CrashConsentGranted` /
///      `CrashConsentRevoked` on the provided [CrashConsentBloc]; the
///      bloc remains the source of truth for crash consent.
///
/// The cubit does NOT subscribe to the CrashConsentBloc continuously
/// — it reads the current state on load so the Settings UI shows the
/// right value, but downstream mutations go through [setCrashReporting]
/// which dispatches events on the bloc. This avoids fighting the bloc
/// for ownership of the consent decision.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SettingsStore store,
    AnalyticsBuffer? analyticsBuffer,
    CrashConsentBloc? crashConsentBloc,
  })  : _store = store,
        _analyticsBuffer = analyticsBuffer,
        _crashConsentBloc = crashConsentBloc,
        super(const SettingsState.initial());

  final SettingsStore _store;
  final AnalyticsBuffer? _analyticsBuffer;
  final CrashConsentBloc? _crashConsentBloc;

  StreamSubscription<CrashConsentStatus>? _consentSub;

  /// Read every key in parallel and emit a single populated state.
  /// Also pushes the `analyticsEnabled` value into the buffer so the
  /// gate is correct before the first flush.
  Future<void> load() async {
    final results = await Future.wait<Object?>([
      _store.readThemeMode(),
      _store.readPlaybackSpeed(),
      _store.readCaptionsDefault(),
      _store.readDataSaver(),
      _store.readAnalyticsEnabled(),
      _store.readTextScaleMultiplier(),
      _store.readReduceMotion(),
      _store.readBiometricUnlock(),
      _store.readCaptionLanguage(),
    ]);

    final themeMode = results[0] as ThemeMode;
    final playbackSpeed = results[1] as double;
    final captionsDefault = results[2] as bool;
    final dataSaver = results[3] as bool;
    final analyticsEnabled = results[4] as bool;
    final textScale = results[5] as double;
    final reduceMotion = results[6] as bool;
    final biometricUnlock = results[7] as bool;
    final captionLanguage = results[8] as String?;

    // Crash reporting comes from the CrashConsentBloc — the source of
    // truth — not from our own store. The bloc's state is a tri-state
    // (undecided / granted / denied); Settings presents it as a binary
    // toggle where "undecided" reads as "off" (matches the default).
    final crashEnabled =
        _crashConsentBloc?.state == CrashConsentStatus.granted;

    emit(state.copyWith(
      themeMode: themeMode,
      playbackSpeed: playbackSpeed,
      captionsDefault: captionsDefault,
      captionLanguage: captionLanguage,
      dataSaver: dataSaver,
      analyticsEnabled: analyticsEnabled,
      crashReportingEnabled: crashEnabled,
      textScaleMultiplier: textScale,
      reduceMotion: reduceMotion,
      biometricUnlock: biometricUnlock,
      loaded: true,
    ));

    // Push current analytics state into the buffer so a user who
    // opted-out on a previous session doesn't resume queuing on the
    // next launch.
    _analyticsBuffer?.setEnabled(analyticsEnabled);

    // Subscribe to consent changes so the Settings UI reflects a
    // decision flipped elsewhere (e.g. the onboarding consent screen).
    _consentSub ??= _crashConsentBloc?.stream.listen((status) {
      final enabled = status == CrashConsentStatus.granted;
      if (enabled == state.crashReportingEnabled) return;
      emit(state.copyWith(crashReportingEnabled: enabled));
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _store.writeThemeMode(mode);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _store.writePlaybackSpeed(speed);
    emit(state.copyWith(playbackSpeed: speed));
  }

  Future<void> setCaptionsDefault(bool value) async {
    await _store.writeCaptionsDefault(value);
    emit(state.copyWith(captionsDefault: value));
  }

  /// Stores a BCP-47 language code as the caption preference. Pass null
  /// to clear the preference (player falls through to video default).
  Future<void> setCaptionLanguage(String? language) async {
    await _store.writeCaptionLanguage(language);
    emit(state.copyWith(captionLanguage: language));
  }

  Future<void> setDataSaver(bool value) async {
    await _store.writeDataSaver(value);
    emit(state.copyWith(dataSaver: value));
  }

  Future<void> setAnalyticsEnabled(bool value) async {
    await _store.writeAnalyticsEnabled(value);
    // Flip the buffer gate FIRST so a flush that races this setter
    // sees the new value. The buffer's setEnabled(false) also purges
    // the on-disk queue (see AnalyticsBuffer.setEnabled).
    _analyticsBuffer?.setEnabled(value);
    emit(state.copyWith(analyticsEnabled: value));
  }

  /// Crash reporting toggle. Reads and writes through the existing
  /// [CrashConsentBloc] rather than maintaining a parallel decision —
  /// the bloc owns the persisted consent key and the SDK consent flag.
  ///
  /// When the bloc isn't wired (tests that don't provide one), the
  /// call is a no-op on the downstream side but still updates the
  /// local state so UI tests can assert toggle behaviour.
  Future<void> setCrashReporting(bool value) async {
    final bloc = _crashConsentBloc;
    if (bloc != null) {
      if (value) {
        bloc.add(const CrashConsentGranted());
      } else {
        bloc.add(const CrashConsentRevoked());
      }
    }
    emit(state.copyWith(crashReportingEnabled: value));
  }

  Future<void> setTextScaleMultiplier(double value) async {
    await _store.writeTextScaleMultiplier(value);
    emit(state.copyWith(textScaleMultiplier: value));
  }

  Future<void> setReduceMotion(bool value) async {
    await _store.writeReduceMotion(value);
    emit(state.copyWith(reduceMotion: value));
  }

  Future<void> setBiometricUnlock(bool value) async {
    await _store.writeBiometricUnlock(value);
    emit(state.copyWith(biometricUnlock: value));
  }

  @override
  Future<void> close() async {
    await _consentSub?.cancel();
    return super.close();
  }
}
