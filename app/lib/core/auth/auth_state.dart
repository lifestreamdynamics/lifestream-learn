import 'package:flutter/foundation.dart';

import '../../data/models/user.dart';

@immutable
abstract class AuthState {
  const AuthState();
}

/// App has not yet attempted rehydration. Router should hold on the splash.
class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  bool operator ==(Object other) => other is AuthInitial;

  @override
  int get hashCode => 0;
}

/// A signup/login call is in flight. Submit buttons should disable.
class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();

  @override
  bool operator ==(Object other) => other is AuthAuthenticating;

  @override
  int get hashCode => 1;
}

class Authenticated extends AuthState {
  const Authenticated(this.user);
  final User user;

  @override
  bool operator ==(Object other) =>
      other is Authenticated && other.user == user;

  @override
  int get hashCode => user.hashCode;
}

class Unauthenticated extends AuthState {
  const Unauthenticated({this.errorMessage});
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      other is Unauthenticated && other.errorMessage == errorMessage;

  @override
  int get hashCode => errorMessage?.hashCode ?? 2;
}

/// Slice P7a — transitional state between `AuthAuthenticating` and
/// `Authenticated` for users with MFA enabled.
///
/// Held while the challenge screen is on-stage. Carries the pending
/// token (the server's 5-minute JWT), the methods the user may choose
/// from, an inline error string for wrong-code retries, and a
/// "submitting" flag for the submit button's disabled state.
class MfaChallengeRequired extends AuthState {
  const MfaChallengeRequired({
    required this.mfaToken,
    required this.availableMethods,
    this.errorMessage,
    this.submitting = false,
  });

  final String mfaToken;
  final List<String> availableMethods;
  final String? errorMessage;
  final bool submitting;

  MfaChallengeRequired copyWith({
    String? errorMessage,
    bool? submitting,
    bool clearError = false,
  }) {
    return MfaChallengeRequired(
      mfaToken: mfaToken,
      availableMethods: availableMethods,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submitting: submitting ?? this.submitting,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MfaChallengeRequired &&
      other.mfaToken == mfaToken &&
      other.errorMessage == errorMessage &&
      other.submitting == submitting &&
      _listEq(other.availableMethods, availableMethods);

  @override
  int get hashCode => Object.hash(
        mfaToken,
        Object.hashAll(availableMethods),
        errorMessage,
        submitting,
      );
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
