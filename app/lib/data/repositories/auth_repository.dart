import 'package:dio/dio.dart';

import '../../core/auth/auth_tokens.dart';
import '../../core/http/error_envelope.dart';
import '../models/user.dart';
import '../models/webauthn.dart';

/// Result of a successful signup/login: tokens + the owner user record.
class AuthSession {
  const AuthSession({required this.tokens, required this.user});
  final AuthTokens tokens;
  final User user;
}

/// Slice P7a — `login()` now returns a union.
///
/// A fully successful login (no MFA enrolled) carries a [AuthSession].
/// A user with MFA enabled instead receives [MfaChallenge]: the tokens
/// are NOT minted until the client completes the challenge through
/// [AuthRepository.loginMfaTotp] or [AuthRepository.loginMfaBackup].
sealed class LoginOutcome {
  const LoginOutcome();
}

class LoginSuccess extends LoginOutcome {
  const LoginSuccess(this.session);
  final AuthSession session;
}

class MfaChallenge extends LoginOutcome {
  const MfaChallenge({
    required this.mfaToken,
    required this.availableMethods,
  });

  /// Short-lived (server TTL 5 min) pending token. Must be passed back
  /// to `loginMfaTotp` / `loginMfaBackup` along with the code.
  final String mfaToken;

  /// Advertised by the server: currently `['totp', 'backup']`.
  /// P7b adds `'webauthn'`. Clients should surface the intersection
  /// of known methods and advertised methods.
  final List<String> availableMethods;
}

/// Thin wrapper around the `/api/auth/*` endpoints. Throws `ApiException`
/// on non-2xx responses (via `ErrorEnvelopeInterceptor`).
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthSession> signup({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/signup',
        data: <String, String>{
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
      return _sessionFromResponse(response.data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// POST `/api/auth/login`.
  ///
  /// Returns [LoginSuccess] when the account has no MFA enrolled, or
  /// [MfaChallenge] when the server responds with
  /// `{ mfaPending: true, mfaToken, availableMethods }`. Callers must
  /// handle both cases — the widget layer (`AuthBloc`) branches on the
  /// type via a sealed-class `switch`.
  Future<LoginOutcome> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: <String, String>{'email': email, 'password': password},
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty auth response',
        );
      }
      if (data['mfaPending'] == true) {
        final rawMethods = data['availableMethods'];
        final methods = rawMethods is List
            ? rawMethods.whereType<String>().toList(growable: false)
            : const <String>[];
        return MfaChallenge(
          mfaToken: data['mfaToken'] as String,
          availableMethods: methods,
        );
      }
      return LoginSuccess(_sessionFromResponse(data));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7a — second step of a MFA-gated login.
  ///
  /// POST `{ mfaToken, code }` to `/api/auth/login/mfa/totp`. Server
  /// mints the real token pair + Session row on match and returns the
  /// same shape as a normal `/login` success. 401 maps to "wrong code
  /// or expired token" (deliberately conflated server-side).
  Future<AuthSession> loginMfaTotp({
    required String mfaToken,
    required String code,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login/mfa/totp',
        data: <String, dynamic>{'mfaToken': mfaToken, 'code': code},
      );
      return _sessionFromResponse(response.data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7b — begin a WebAuthn step-up for a MFA-gated login.
  ///
  /// POSTs `{ mfaToken }` to `/api/auth/login/mfa/webauthn/options`.
  /// Server returns the assertion options JSON the platform Credential
  /// Manager expects, plus a short-lived challenge token the client
  /// hands back to [loginMfaWebauthnVerify].
  Future<WebauthnAssertionOptions> loginMfaWebauthnOptions({
    required String mfaToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login/mfa/webauthn/options',
        data: <String, dynamic>{'mfaToken': mfaToken},
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty WebAuthn options response',
        );
      }
      return WebauthnAssertionOptions.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7b — complete a WebAuthn MFA step-up.
  ///
  /// POSTs `{ mfaToken, challengeToken, assertionResponse }`. Server
  /// verifies the assertion, bumps the stored sign-count, and mints a
  /// full token pair + Session row exactly like the TOTP completion
  /// endpoint does. 401 maps to "wrong assertion or expired token"
  /// (server deliberately conflates).
  Future<AuthSession> loginMfaWebauthnVerify({
    required String mfaToken,
    required String challengeToken,
    required Map<String, dynamic> assertionResponse,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login/mfa/webauthn/verify',
        data: <String, dynamic>{
          'mfaToken': mfaToken,
          'challengeToken': challengeToken,
          'assertionResponse': assertionResponse,
        },
      );
      return _sessionFromResponse(response.data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7a — backup-code fallback on a MFA-gated login.
  ///
  /// POST `{ mfaToken, code }` to `/api/auth/login/mfa/backup`. The
  /// matched code is burned server-side; subsequent calls with the same
  /// code fail.
  Future<AuthSession> loginMfaBackup({
    required String mfaToken,
    required String code,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login/mfa/backup',
        data: <String, dynamic>{'mfaToken': mfaToken, 'code': code},
      );
      return _sessionFromResponse(response.data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: <String, String>{'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty refresh response',
        );
      }
      return AuthTokens.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P6 — explicit server-side logout.
  ///
  /// POSTs `/api/auth/logout` with the refresh token in the body. The
  /// server revokes the matching Session row and pushes the jti into
  /// the Redis revocation set so any concurrent refresh call fails
  /// fast. Callers should invoke this BEFORE clearing the local
  /// TokenStore so a stolen device can't replay the refresh token
  /// after the user taps "Log out".
  ///
  /// Idempotent + best-effort: the server returns 204 even for bogus
  /// tokens, and this method swallows any DioException so a caller
  /// with no network connectivity can still complete the local logout.
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/api/auth/logout',
        data: <String, String>{'refreshToken': refreshToken},
      );
    } on DioException {
      // Intentional swallow — the local logout flow must proceed even
      // when we're offline or the server is down. Server-side
      // revocation is best-effort from the client's perspective;
      // the next refresh attempt will 401 regardless once connectivity
      // returns and the access token expires.
    }
  }

  /// The backend's `GET /api/auth/me` returns the `PublicUser` directly
  /// (id/email/role/displayName/createdAt). We ignore `createdAt` and map
  /// the rest into our `User` model.
  Future<User> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/auth/me');
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty user response',
        );
      }
      return User.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  AuthSession _sessionFromResponse(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        statusCode: 0,
        message: 'Empty auth response',
      );
    }
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    final tokens = AuthTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return AuthSession(tokens: tokens, user: user);
  }

  ApiException _unwrap(DioException e) {
    final err = e.error;
    if (err is ApiException) return err;
    return ApiException(
      code: 'NETWORK_ERROR',
      statusCode: e.response?.statusCode ?? 0,
      message: e.message ?? 'Network error',
    );
  }
}
