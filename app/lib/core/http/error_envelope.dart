import 'package:dio/dio.dart';

/// Typed exception surfaced to app code for any non-2xx HTTP response or
/// network error. Matches the canonical backend error envelope:
/// `{error: string, message: string, details?: any}` plus the HTTP status.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.statusCode,
    required this.message,
    this.details,
  });

  /// Backend error code (e.g. 'UNAUTHORIZED', 'VALIDATION_ERROR', 'CONFLICT').
  /// For network/transport failures we synthesise 'NETWORK_ERROR'.
  final String code;

  /// HTTP status code (0 if no response was received).
  final int statusCode;

  /// Human-readable message (safe to render in UI inline error strips).
  final String message;

  /// Optional structured details (e.g. field-level validation errors).
  final Object? details;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// Dio interceptor that converts `DioException` into `ApiException` and
/// rethrows. Placed after `AuthInterceptor` so that 401 recovery (refresh +
/// retry) can still short-circuit before a final failure becomes an
/// ApiException.
class ErrorEnvelopeInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) {
      final data = response.data;
      if (data is Map) {
        final code = data['error'];
        final message = data['message'];
        if (code is String && message is String) {
          final apiError = ApiException(
            code: code,
            statusCode: response.statusCode ?? 0,
            message: message,
            details: data['details'],
          );
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: response,
              type: err.type,
              error: apiError,
              message: message,
            ),
          );
          return;
        }
      }
      // Response present but not a valid envelope — fall through to generic.
    }

    // No response (timeout, DNS, socket close) or malformed body.
    final apiError = ApiException(
      code: 'NETWORK_ERROR',
      statusCode: response?.statusCode ?? 0,
      message: err.message ?? 'Network error',
    );
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: response,
        type: err.type,
        error: apiError,
        message: apiError.message,
      ),
    );
  }
}
