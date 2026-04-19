import 'package:flutter/foundation.dart';

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
