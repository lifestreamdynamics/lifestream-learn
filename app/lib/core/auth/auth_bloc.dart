import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/auth_repository.dart';
import '../http/auth_interceptor.dart';
import '../http/error_envelope.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'token_store.dart';

/// Authentication state machine + the `AuthStateSink` that the Dio
/// interceptor uses to force-logout when a refresh fails mid-request.
class AuthBloc extends Bloc<AuthEvent, AuthState> implements AuthStateSink {
  AuthBloc({
    required this.authRepo,
    required this.tokenStore,
  }) : super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<LoginRequested>(_onLogin);
    on<SignupRequested>(_onSignup);
    on<LoggedOut>(_onLoggedOut);
  }

  final AuthRepository authRepo;
  final TokenStore tokenStore;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final tokens = await tokenStore.read();
    if (tokens == null) {
      emit(const Unauthenticated());
      return;
    }
    try {
      final user = await authRepo.me();
      emit(Authenticated(user));
    } on ApiException {
      // Tokens were present but invalid / user gone — scrub and demote.
      await tokenStore.clear();
      emit(const Unauthenticated());
    }
  }

  Future<void> _onLogin(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthAuthenticating());
    try {
      final session = await authRepo.login(
        email: event.email,
        password: event.password,
      );
      await tokenStore.save(session.tokens);
      emit(Authenticated(session.user));
    } on ApiException catch (e) {
      emit(Unauthenticated(errorMessage: e.message));
    }
  }

  Future<void> _onSignup(
    SignupRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthAuthenticating());
    try {
      final session = await authRepo.signup(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );
      await tokenStore.save(session.tokens);
      emit(Authenticated(session.user));
    } on ApiException catch (e) {
      emit(Unauthenticated(errorMessage: e.message));
    }
  }

  Future<void> _onLoggedOut(
    LoggedOut event,
    Emitter<AuthState> emit,
  ) async {
    await tokenStore.clear();
    emit(const Unauthenticated());
  }

  /// `AuthStateSink` implementation — called by the Dio interceptor when
  /// refresh fails. Add a `LoggedOut` event so the reducer handles it in
  /// the same serial order as user-initiated logouts.
  @override
  void emitLoggedOut() {
    add(const LoggedOut());
  }
}
