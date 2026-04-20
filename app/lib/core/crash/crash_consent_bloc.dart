import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'crash_reporter.dart';
import 'secure_storage_backend.dart';

/// Tri-state consent for crash reporting uploads.
///
/// - [undecided] — the user has not yet seen the consent screen on
///   this install. The router's redirect rule forces them to see it
///   before the rest of the app is reachable.
/// - [granted] — uploads allowed. The reporter's SDK has had
///   `grantConsent()` + `setConsentPreVerified()` called on it.
/// - [denied] — uploads suppressed. The SDK has had `revokeConsent()`
///   called and its offline queue cleared.
enum CrashConsentStatus { undecided, granted, denied }

@immutable
abstract class CrashConsentEvent {
  const CrashConsentEvent();
}

/// Fired on app start; reads the persisted status from storage so the
/// user isn't re-prompted on every launch.
class CrashConsentLoadRequested extends CrashConsentEvent {
  const CrashConsentLoadRequested();
}

class CrashConsentGranted extends CrashConsentEvent {
  const CrashConsentGranted();
}

class CrashConsentRevoked extends CrashConsentEvent {
  const CrashConsentRevoked();
}

/// Owns the user's crash-consent decision.
///
/// Persists the decision to [SecureStorageBackend] under the
/// `crash.consent_decision` key (note: the reporter's SDK owns the
/// `consent` key itself, so we use a different key here to avoid
/// semantic overlap). On grant/revoke we also drive the SDK state via
/// [CrashReporter.grant] / [CrashReporter.revoke].
class CrashConsentBloc extends Bloc<CrashConsentEvent, CrashConsentStatus> {
  CrashConsentBloc({
    required CrashReporter reporter,
    required SecureStorageBackend storage,
  })  : _reporter = reporter,
        _storage = storage,
        super(CrashConsentStatus.undecided) {
    on<CrashConsentLoadRequested>(_onLoad);
    on<CrashConsentGranted>(_onGrant);
    on<CrashConsentRevoked>(_onRevoke);
  }

  final CrashReporter _reporter;
  final SecureStorageBackend _storage;

  static const String _key = 'consent_decision';

  Future<void> _onLoad(
    CrashConsentLoadRequested event,
    Emitter<CrashConsentStatus> emit,
  ) async {
    final value = await _storage.getItem(_key);
    if (value == 'granted') {
      // The persisted decision already implies the SDK's `consent`
      // key is set; rehydrate the *in-memory* pre-verified flag only
      // so an exception thrown before the first async storage read
      // still lands cleanly. Avoid re-writing the consent key — that
      // used to happen via `reporter.grant()` and produced a redundant
      // secure-storage round-trip on every app launch.
      _reporter.setConsentPreVerified();
      emit(CrashConsentStatus.granted);
    } else if (value == 'denied') {
      emit(CrashConsentStatus.denied);
    } else {
      emit(CrashConsentStatus.undecided);
    }
  }

  Future<void> _onGrant(
    CrashConsentGranted event,
    Emitter<CrashConsentStatus> emit,
  ) async {
    await _reporter.grant();
    await _storage.setItem(_key, 'granted');
    emit(CrashConsentStatus.granted);
  }

  Future<void> _onRevoke(
    CrashConsentRevoked event,
    Emitter<CrashConsentStatus> emit,
  ) async {
    await _reporter.revoke();
    await _storage.setItem(_key, 'denied');
    emit(CrashConsentStatus.denied);
  }
}
