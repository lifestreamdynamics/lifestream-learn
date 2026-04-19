import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_tokens.dart';
import '../auth/token_store.dart';

/// Narrow seam the interceptor uses to notify the auth layer that refresh
/// failed and the user should be logged out. Implemented by `AuthBloc`.
/// Kept as its own interface so the interceptor is testable without pulling
/// in flutter_bloc.
abstract class AuthStateSink {
  void emitLoggedOut();
}

/// Signature for the refresh closure. Injected into `AuthInterceptor` so it
/// has no direct dependency on `AuthRepository`.
typedef RefreshFn = Future<AuthTokens> Function(String refreshToken);

/// Attaches `Authorization: Bearer <accessToken>` to every request (except
/// auth endpoints + /health), and transparently recovers from a 401 by
/// performing a single-flight refresh then retrying the original request
/// exactly once.
///
/// # Concurrency invariant
///
/// The class holds a static `Completer<AuthTokens>? _inFlight` — any number of
/// concurrent requests that 401 at the same moment share exactly one call to
/// `refreshFn`. Tested in `test/core/http/auth_interceptor_test.dart`.
///
/// # Logging
///
/// No `print` / `debugPrint` of tokens or `Authorization` headers — ever.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStore,
    required this.refreshFn,
    required this.authStateSink,
  });

  final TokenStore tokenStore;
  final RefreshFn refreshFn;
  final AuthStateSink authStateSink;

  /// The host `Dio` — assigned by `createDio` after construction so the
  /// interceptor can replay the original request through the *same* client
  /// (same adapter, same base URL, same timeouts) when recovering from a
  /// 401. Set before the Dio is used.
  Dio? dio;

  /// Shared across all instances — the refresh operation is global to the app.
  static Completer<AuthTokens>? _inFlight;

  /// Paths that MUST NOT receive a Bearer header and must never trigger a
  /// refresh. Matched by "contains" against `path` so `/api/auth/login` hits
  /// as well as a fully-qualified `https://.../api/auth/login`.
  static const List<String> _unauthPaths = [
    '/api/auth/signup',
    '/api/auth/login',
    '/api/auth/refresh',
    '/health',
  ];

  bool _isAuthPath(String path) =>
      _unauthPaths.any((p) => path.contains(p));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthPath(options.path)) {
      final tokens = await tokenStore.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final path = err.requestOptions.path;

    // Not a 401 with the canonical UNAUTHORIZED envelope — let it propagate.
    if (response?.statusCode != 401 ||
        response?.data is! Map ||
        (response!.data as Map)['error'] != 'UNAUTHORIZED') {
      return handler.next(err);
    }

    // A 401 on an auth endpoint means the refresh token itself is bad (or
    // creds are wrong) — attempting to refresh would just infinite-loop.
    if (_isAuthPath(path)) {
      return handler.next(err);
    }

    // Guard against a retried request that already carries the "retry" marker
    // coming back 401 again — bubble so we don't loop.
    if (err.requestOptions.extra['authInterceptor.retried'] == true) {
      return handler.next(err);
    }

    final AuthTokens newTokens;
    try {
      newTokens = await _refresh();
    } catch (_) {
      authStateSink.emitLoggedOut();
      return handler.next(err);
    }

    // Retry the original request once with the new access token.
    final retryOptions = err.requestOptions.copyWith(
      headers: Map<String, dynamic>.from(err.requestOptions.headers)
        ..['Authorization'] = 'Bearer ${newTokens.accessToken}',
      extra: Map<String, dynamic>.from(err.requestOptions.extra)
        ..['authInterceptor.retried'] = true,
    );

    final host = dio;
    if (host == null) {
      // Should never happen in production — `createDio` wires this up.
      return handler.next(err);
    }
    try {
      final response = await host.fetch<dynamic>(retryOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Returns the refreshed tokens. Callers fan in on `_inFlight`; only the
  /// first caller performs the network call. On failure the completer is
  /// completed-with-error and cleared in `finally` so a future request can
  /// start a fresh attempt.
  Future<AuthTokens> _refresh() async {
    final existing = _inFlight;
    if (existing != null) {
      return existing.future;
    }
    final completer = Completer<AuthTokens>();
    // Attach a noop error handler now so that if nobody else awaits the
    // future (e.g. only the starter saw the throw), Dart's zone doesn't
    // report it as an unhandled async error.
    completer.future.catchError((_) => const AuthTokens(
          accessToken: '',
          refreshToken: '',
        ));
    _inFlight = completer;
    try {
      final current = await tokenStore.read();
      if (current == null) {
        throw StateError('No refresh token available');
      }
      final fresh = await refreshFn(current.refreshToken);
      await tokenStore.save(fresh);
      completer.complete(fresh);
      return fresh;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _inFlight = null;
    }
  }

  /// Test-only hook: reset the shared in-flight completer between tests.
  /// Exposed because the static is shared across interceptor instances.
  @visibleForTesting
  static void debugResetInFlight() {
    _inFlight = null;
  }
}
