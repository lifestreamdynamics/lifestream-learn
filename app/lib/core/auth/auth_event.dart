import 'package:flutter/foundation.dart';

import '../../data/models/user.dart';

/// Base event class. All auth events are value-types so `bloc_test`
/// expectations compare by equality.
@immutable
abstract class AuthEvent {
  const AuthEvent();
}

/// Fired once on app boot to attempt rehydration from `TokenStore`.
class AuthStarted extends AuthEvent {
  const AuthStarted();

  @override
  bool operator ==(Object other) => other is AuthStarted;

  @override
  int get hashCode => 0;
}

class LoginRequested extends AuthEvent {
  const LoginRequested({required this.email, required this.password});
  final String email;
  final String password;

  @override
  bool operator ==(Object other) =>
      other is LoginRequested &&
      other.email == email &&
      other.password == password;

  @override
  int get hashCode => Object.hash(email, password);
}

class SignupRequested extends AuthEvent {
  const SignupRequested({
    required this.email,
    required this.password,
    required this.displayName,
  });
  final String email;
  final String password;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is SignupRequested &&
      other.email == email &&
      other.password == password &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(email, password, displayName);
}

class LoggedOut extends AuthEvent {
  const LoggedOut();

  @override
  bool operator ==(Object other) => other is LoggedOut;

  @override
  int get hashCode => 1;
}

/// Emitted after a successful `PATCH /api/me` or avatar upload so the
/// cached `AuthState.user` stays in sync with the server without a full
/// re-auth. Only meaningful while the state is `Authenticated` —
/// ignored otherwise (prevents a race where a late response lands
/// after the user logs out).
class UserUpdated extends AuthEvent {
  const UserUpdated(this.user);
  final User user;

  @override
  bool operator ==(Object other) =>
      other is UserUpdated && other.user == user;

  @override
  int get hashCode => Object.hash('UserUpdated', user);
}

/// Slice P7a — fired by the login screen when the server responds with
/// `mfaPending: true`. Stashes the pending token + advertised methods
/// so the challenge screen has everything it needs to drive
/// `POST /api/auth/login/mfa/*`.
class MfaChallengeStarted extends AuthEvent {
  const MfaChallengeStarted({
    required this.mfaToken,
    required this.availableMethods,
  });
  final String mfaToken;
  final List<String> availableMethods;

  @override
  bool operator ==(Object other) =>
      other is MfaChallengeStarted &&
      other.mfaToken == mfaToken &&
      _listEq(other.availableMethods, availableMethods);

  @override
  int get hashCode => Object.hash(mfaToken, Object.hashAll(availableMethods));
}

/// Slice P7a — user submitted a code from the challenge screen.
///
/// `useBackup = true` routes through `/api/auth/login/mfa/backup`;
/// otherwise the TOTP endpoint. A successful completion transitions
/// the bloc into `Authenticated`; a wrong code lands back on the
/// challenge screen with an inline error.
class MfaSubmitted extends AuthEvent {
  const MfaSubmitted({required this.code, this.useBackup = false});
  final String code;
  final bool useBackup;

  @override
  bool operator ==(Object other) =>
      other is MfaSubmitted &&
      other.code == code &&
      other.useBackup == useBackup;

  @override
  int get hashCode => Object.hash(code, useBackup);
}

/// Slice P7a — cancel an in-flight MFA challenge (e.g. user tapped
/// Back). Returns to `Unauthenticated` and discards the pending token.
class MfaChallengeAborted extends AuthEvent {
  const MfaChallengeAborted();

  @override
  bool operator ==(Object other) => other is MfaChallengeAborted;

  @override
  int get hashCode => Object.hash('MfaChallengeAborted', 0);
}

/// Slice P7b — user chose to complete the challenge with a passkey.
/// The bloc drives the Credential Manager prompt + the server exchange
/// under the hood so the UI only has to dispatch one event.
class MfaPasskeySubmitted extends AuthEvent {
  const MfaPasskeySubmitted();

  @override
  bool operator ==(Object other) => other is MfaPasskeySubmitted;

  @override
  int get hashCode => Object.hash('MfaPasskeySubmitted', 0);
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
