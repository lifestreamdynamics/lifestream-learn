import 'package:dio/dio.dart';

import '../../core/auth/auth_tokens.dart';
import '../../core/http/error_envelope.dart';
import '../models/user.dart';

/// Result of a successful signup/login: tokens + the owner user record.
class AuthSession {
  const AuthSession({required this.tokens, required this.user});
  final AuthTokens tokens;
  final User user;
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

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: <String, String>{'email': email, 'password': password},
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
