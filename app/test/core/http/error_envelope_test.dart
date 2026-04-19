import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';

/// Helper: build a DioException carrying `data` as the response body and
/// run it through `ErrorEnvelopeInterceptor.onError`, returning the
/// DioException the handler finally rejected with.
Future<DioException> _runThrough(Object? data, {int statusCode = 400}) async {
  final requestOptions = RequestOptions(path: '/x');
  final response = Response<dynamic>(
    requestOptions: requestOptions,
    data: data,
    statusCode: statusCode,
  );
  final err = DioException(
    requestOptions: requestOptions,
    response: response,
    type: DioExceptionType.badResponse,
  );

  DioException? rejected;
  final handler = _CapturingErrorInterceptorHandler((e) => rejected = e);
  ErrorEnvelopeInterceptor().onError(err, handler);
  // Handler completes synchronously here, but await a microtask just in case.
  await Future<void>.value();
  return rejected!;
}

class _CapturingErrorInterceptorHandler extends ErrorInterceptorHandler {
  _CapturingErrorInterceptorHandler(this._onReject);
  final void Function(DioException) _onReject;

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {
    _onReject(error);
  }
}

void main() {
  group('ErrorEnvelopeInterceptor', () {
    test('decodes canonical envelope into ApiException', () async {
      final rejected = await _runThrough(
        <String, Object?>{
          'error': 'VALIDATION_ERROR',
          'message': 'Invalid email',
          'details': <String, Object?>{'field': 'email'},
        },
        statusCode: 400,
      );
      final api = rejected.error;
      expect(api, isA<ApiException>());
      final apiErr = api! as ApiException;
      expect(apiErr.code, 'VALIDATION_ERROR');
      expect(apiErr.statusCode, 400);
      expect(apiErr.message, 'Invalid email');
      expect(apiErr.details, <String, Object?>{'field': 'email'});
    });

    test('decodes UNAUTHORIZED envelope', () async {
      final rejected = await _runThrough(
        <String, Object?>{
          'error': 'UNAUTHORIZED',
          'message': 'Invalid credentials',
        },
        statusCode: 401,
      );
      final apiErr = rejected.error! as ApiException;
      expect(apiErr.code, 'UNAUTHORIZED');
      expect(apiErr.statusCode, 401);
      expect(apiErr.message, 'Invalid credentials');
      expect(apiErr.details, isNull);
    });

    test('falls back to NETWORK_ERROR on malformed envelope', () async {
      final rejected = await _runThrough('not a json body', statusCode: 500);
      final apiErr = rejected.error! as ApiException;
      expect(apiErr.code, 'NETWORK_ERROR');
      expect(apiErr.statusCode, 500);
    });

    test('falls back to NETWORK_ERROR when no response', () async {
      final requestOptions = RequestOptions(path: '/x');
      final err = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
        message: 'timed out',
      );
      DioException? rejected;
      final handler =
          _CapturingErrorInterceptorHandler((e) => rejected = e);
      ErrorEnvelopeInterceptor().onError(err, handler);
      await Future<void>.value();
      final apiErr = rejected!.error! as ApiException;
      expect(apiErr.code, 'NETWORK_ERROR');
      expect(apiErr.statusCode, 0);
      expect(apiErr.message, 'timed out');
    });
  });

  test('ApiException toString contains code and status', () {
    const e = ApiException(
      code: 'X',
      statusCode: 418,
      message: 'teapot',
    );
    expect(e.toString(), contains('X'));
    expect(e.toString(), contains('418'));
    expect(e.toString(), contains('teapot'));
  });
}
