import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/auth_repository.dart';
import '../http/auth_interceptor.dart';
import '../http/error_envelope.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'passkey_platform.dart';
import 'token_store.dart';

/// Authentication state machine + the `AuthStateSink` that the Dio
/// interceptor uses to force-logout when a refresh fails mid-request.
class AuthBloc extends Bloc<AuthEvent, AuthState> implements AuthStateSink {
  AuthBloc({
    required this.authRepo,
    required this.tokenStore,
    PasskeyPlatform? passkeyPlatform,
  })  : _passkeyPlatform = passkeyPlatform,
        super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<LoginRequested>(_onLogin);
    on<SignupRequested>(_onSignup);
    on<LoggedOut>(_onLoggedOut);
    on<UserUpdated>(_onUserUpdated);
    // Slice P7a — MFA step-up events.
    on<MfaChallengeStarted>(_onMfaChallengeStarted);
    on<MfaSubmitted>(_onMfaSubmitted);
    on<MfaChallengeAborted>(_onMfaChallengeAborted);
    // Slice P7b — passkey step-up.
    on<MfaPasskeySubmitted>(_onMfaPasskeySubmitted);
  }

  final AuthRepository authRepo;
  final TokenStore tokenStore;
  final PasskeyPlatform? _passkeyPlatform;

  PasskeyPlatform _passkeys() => _passkeyPlatform ?? PasskeyPlatform();

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
      final outcome = await authRepo.login(
        email: event.email,
        password: event.password,
      );
      switch (outcome) {
        case LoginSuccess(:final session):
          await tokenStore.save(session.tokens);
          emit(Authenticated(session.user));
        case MfaChallenge(:final mfaToken, :final availableMethods):
          // Slice P7a — password step succeeded; pause here while the
          // challenge screen collects a 6-digit code or backup code.
          // Tokens have NOT been minted and nothing has landed in
          // TokenStore yet.
          emit(MfaChallengeRequired(
            mfaToken: mfaToken,
            availableMethods: availableMethods,
          ));
      }
    } on ApiException catch (e) {
      emit(Unauthenticated(errorMessage: e.message));
    }
  }

  Future<void> _onMfaChallengeStarted(
    MfaChallengeStarted event,
    Emitter<AuthState> emit,
  ) async {
    // Defensive re-emit. The login flow itself emits
    // `MfaChallengeRequired`; this handler exists so callers who receive
    // an event stream (e.g. a test harness, or a future OAuth callback
    // path) can drive the bloc into the challenge state directly.
    emit(MfaChallengeRequired(
      mfaToken: event.mfaToken,
      availableMethods: event.availableMethods,
    ));
  }

  Future<void> _onMfaSubmitted(
    MfaSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! MfaChallengeRequired) return;
    emit(current.copyWith(submitting: true, clearError: true));
    try {
      final session = event.useBackup
          ? await authRepo.loginMfaBackup(
              mfaToken: current.mfaToken,
              code: event.code,
            )
          : await authRepo.loginMfaTotp(
              mfaToken: current.mfaToken,
              code: event.code,
            );
      await tokenStore.save(session.tokens);
      emit(Authenticated(session.user));
    } on ApiException catch (e) {
      // Keep the user on the challenge screen with an inline error so
      // they can retype. Wrong code and expired token both surface as
      // 401 — we don't distinguish, matching the server's constant-shape
      // error posture.
      emit(current.copyWith(
        submitting: false,
        errorMessage: e.statusCode == 401 ? 'Invalid code — try again' : e.message,
      ));
    }
  }

  Future<void> _onMfaPasskeySubmitted(
    MfaPasskeySubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! MfaChallengeRequired) return;
    emit(current.copyWith(submitting: true, clearError: true));
    try {
      final opts = await authRepo.loginMfaWebauthnOptions(
        mfaToken: current.mfaToken,
      );
      final assertion = await _passkeys().authenticate(opts.options);
      final session = await authRepo.loginMfaWebauthnVerify(
        mfaToken: current.mfaToken,
        challengeToken: opts.challengeToken,
        assertionResponse: assertion,
      );
      await tokenStore.save(session.tokens);
      emit(Authenticated(session.user));
    } on PasskeyCancelledException {
      // Platform prompt dismissed — keep the challenge open so the
      // user can retry or switch to another method.
      emit(current.copyWith(submitting: false, clearError: true));
    } on ApiException catch (e) {
      emit(current.copyWith(
        submitting: false,
        errorMessage: e.statusCode == 401
            ? 'Passkey rejected — try again'
            : e.message,
      ));
    } catch (e) {
      emit(current.copyWith(
        submitting: false,
        errorMessage: 'Passkey error: $e',
      ));
    }
  }

  Future<void> _onMfaChallengeAborted(
    MfaChallengeAborted event,
    Emitter<AuthState> emit,
  ) async {
    // User tapped back / cancel. We discard the pending token and
    // return to the login screen. The server-side token expires on
    // its own (5 min) so nothing else to do.
    emit(const Unauthenticated());
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
    // Slice P6 — best-effort server-side logout BEFORE clearing the
    // local TokenStore. We read the refresh token first; if absent
    // (already logged out, or we're handling an auth-interceptor
    // force-logout after a failed refresh), skip the HTTP call. The
    // repo swallows network errors internally so an offline logout
    // still completes locally.
    final tokens = await tokenStore.read();
    if (tokens != null) {
      await authRepo.logout(tokens.refreshToken);
    }
    await tokenStore.clear();
    emit(const Unauthenticated());
  }

  /// Replace the cached user on an already-authenticated state. Ignored
  /// when the state is anything else so a late-arriving response (e.g.
  /// a PATCH /api/me completing after the user logged out) doesn't
  /// resurrect an authenticated view.
  void _onUserUpdated(UserUpdated event, Emitter<AuthState> emit) {
    final current = state;
    if (current is Authenticated) {
      emit(Authenticated(event.user));
    }
  }

  /// `AuthStateSink` implementation — called by the Dio interceptor when
  /// refresh fails. Add a `LoggedOut` event so the reducer handles it in
  /// the same serial order as user-initiated logouts.
  @override
  void emitLoggedOut() {
    add(const LoggedOut());
  }
}
