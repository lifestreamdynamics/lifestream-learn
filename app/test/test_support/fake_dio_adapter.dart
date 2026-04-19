import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';

/// Minimal Dio adapter for repository unit tests. Enqueue responses (or
/// failures) and `fetch()` dequeues FIFO. Records request paths so
/// callers can assert counts / query strings.
class FakeDioAdapter implements HttpClientAdapter {
  final List<_Queued> _queue = <_Queued>[];
  final List<RequestOptions> requestLog = <RequestOptions>[];

  void enqueueJson(Object body,
      {int statusCode = 200, Map<String, List<String>>? headers}) {
    _queue.add(_Queued(statusCode, body, headers ?? <String, List<String>>{}));
  }

  void enqueueError(int statusCode, Map<String, dynamic> body) {
    _queue.add(_Queued(statusCode, body, <String, List<String>>{}));
  }

  void enqueueEmpty204() {
    _queue.add(_Queued(204, null, <String, List<String>>{}));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestLog.add(options);
    if (_queue.isEmpty) {
      throw StateError(
        'No queued response for ${options.method} ${options.path}',
      );
    }
    final next = _queue.removeAt(0);
    final bytes = next.body == null
        ? Uint8List(0)
        : Uint8List.fromList(utf8.encode(jsonEncode(next.body)));
    return ResponseBody.fromBytes(
      bytes,
      next.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: ['application/json'],
        ...next.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Queued {
  _Queued(this.statusCode, this.body, this.headers);
  final int statusCode;
  final Object? body;
  final Map<String, List<String>> headers;
}

/// Construct a Dio wired to `adapter` with the shared error-envelope
/// interceptor in place (so 4xx/5xx responses surface as `ApiException`
/// the way production code sees them).
Dio buildTestDio(FakeDioAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(ErrorEnvelopeInterceptor());
  return dio;
}
