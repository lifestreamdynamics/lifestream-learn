import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../settings/settings_store.dart';
import 'token_store.dart';

/// Slice P7a — biometric unlock gate, orchestrated at cold-start.
///
/// Semantics:
///   - If the user has NOT enabled "Biometric unlock" in settings, or
///     there are no saved tokens, this is a no-op.
///   - If biometrics are enabled but the device no longer supports
///     them (sensor removed, enrolments deleted), we allow startup to
///     proceed rather than stranding the user — the next failed
///     authenticate() reverts the preference on its own.
///   - On a hard authentication failure (cancelled, too many
///     attempts), we clear the token store and let the router's
///     redirect rule land on `/login`. This is the correct security
///     posture: a stolen device with known tokens must not hand those
///     tokens to the attacker before the owner re-authenticates.
///
/// The gate is called ONCE from `main.dart` between the TokenStore
/// read and the `AuthBloc.add(AuthStarted)`. It does not manage the
/// AuthBloc directly — it only manipulates the TokenStore so the
/// subsequent `AuthStarted` handler sees either the original tokens
/// (success) or no tokens (failure).
class BiometricGate {
  BiometricGate({
    required this.settingsStore,
    required this.tokenStore,
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  final SettingsStore settingsStore;
  final TokenStore tokenStore;
  final LocalAuthentication _localAuth;

  /// Runs the gate. Returns `true` when the app should proceed as
  /// authenticated (either because biometrics passed, or the feature is
  /// off, or there are no tokens so nothing to gate). Returns `false`
  /// when the tokens were cleared due to a biometric failure — in
  /// which case the caller may skip the `AuthStarted` rehydration.
  Future<bool> run() async {
    final enabled = await settingsStore.readBiometricUnlock();
    if (!enabled) return true;
    final tokens = await tokenStore.read();
    if (tokens == null) return true;

    bool canCheck = false;
    try {
      canCheck = await _localAuth.canCheckBiometrics;
      if (canCheck) {
        final supported = await _localAuth.isDeviceSupported();
        if (!supported) canCheck = false;
      }
    } on PlatformException {
      canCheck = false;
    }
    if (!canCheck) {
      // The user enabled biometrics previously, but the device no
      // longer supports them. Let them in and fix it themselves in
      // settings; refusing to boot would be worse than the attacker-
      // with-device worst case we're already accepting for anyone
      // whose device has biometrics turned off.
      return true;
    }

    bool ok = false;
    try {
      ok = await _localAuth.authenticate(
        localizedReason: 'Unlock Lifestream Learn',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      ok = false;
    }

    if (!ok) {
      // Defensive: clear tokens so the session doesn't revive with
      // stale credentials until the user re-enters their password.
      await tokenStore.clear();
      return false;
    }
    return true;
  }
}
