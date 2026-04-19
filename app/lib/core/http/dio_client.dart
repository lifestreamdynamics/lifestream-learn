import 'package:dio/dio.dart';

import '../../config/api_config.dart';
import '../auth/auth_tokens.dart';
import '../auth/token_store.dart';
import 'auth_interceptor.dart';
import 'error_envelope.dart';

/// Builds a configured Dio instance.
///
/// Interceptor order matters:
///   1. `AuthInterceptor` — attaches Bearer, owns the single-flight 401 refresh.
///   2. `ErrorEnvelopeInterceptor` — final stop that turns any remaining
///      DioException into a typed `ApiException`.
///
/// `baseUrlOverride` is provided for tests; production code reads from
/// `ApiConfig.baseUrl` (dart-define).
Dio createDio({
  required TokenStore tokenStore,
  required AuthStateSink authStateSink,
  String? baseUrlOverride,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrlOverride ?? ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: <String, dynamic>{'accept': 'application/json'},
  ));

  // Closure passed into the interceptor so the interceptor has no dependency
  // on AuthRepository. It issues a fresh POST /api/auth/refresh through a
  // bare Dio to avoid re-entering the interceptor chain during refresh.
  Future<AuthTokens> refreshFn(String refreshToken) async {
    final bare = Dio(BaseOptions(
      baseUrl: baseUrlOverride ?? ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    final response = await bare.post<Map<String, dynamic>>(
      '/api/auth/refresh',
      data: <String, String>{'refreshToken': refreshToken},
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Refresh returned no body');
    }
    return AuthTokens.fromJson(data);
  }

  final authInterceptor = AuthInterceptor(
    tokenStore: tokenStore,
    refreshFn: refreshFn,
    authStateSink: authStateSink,
  )..dio = dio;
  dio.interceptors.add(authInterceptor);
  dio.interceptors.add(ErrorEnvelopeInterceptor());
  return dio;
}
