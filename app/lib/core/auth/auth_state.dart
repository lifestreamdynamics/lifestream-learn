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
