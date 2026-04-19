import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/auth/auth_tokens.dart';
import 'package:lifestream_learn_app/core/auth/token_store.dart';
import 'package:lifestream_learn_app/core/http/auth_interceptor.dart';
import 'package:mocktail/mocktail.dart';

/// Fake secure-storage platform so `TokenStore` works in unit tests.
class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _data = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      _data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async =>
      _data.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _data.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      _data[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map<String, String>.from(_data);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _data[key] = value;
  }
}

/// Deterministic Dio transport. Each invocation pops the next scripted
/// response for the matching path (or the default if none).
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter();

  /// Map of path → ordered queue of ResponseBody builders. Each builder
  /// receives the RequestOptions (so it can inspect headers, e.g. check
  /// that the retry carried the new Bearer).
  final Map<String, List<Future<ResponseBody> Function(RequestOptions)>>
      _scripts = {};

  /// Record of every request that arrived, in order.
  final List<RequestOptions> calls = [];

  void enqueue(
    String path,
    Future<ResponseBody> Function(RequestOptions) build,
  ) {
    (_scripts[path] ??= <Future<ResponseBody> Function(RequestOptions)>[])
        .add(build);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls.add(options);
    final script = _scripts[options.path];
    if (script == null || script.isEmpty) {
      throw StateError('No scripted response for ${options.path}');
    }
    final next = script.removeAt(0);
    return next(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Map<String, Object?> body, {int status = 200}) {
  final bytes = utf8.encode(jsonEncode(body));
  return ResponseBody.fromBytes(
    bytes,
    status,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

/// Simple `AuthStateSink` stub that records whether `emitLoggedOut` fired.
class _RecordingSink implements AuthStateSink {
  int count = 0;
  @override
  void emitLoggedOut() {
    count++;
  }
}

class _RefreshFn extends Mock {
  Future<AuthTokens> call(String refreshToken);
}

void main() {
  late _FakeSecureStoragePlatform fakePlatform;
  late TokenStore tokenStore;
  late _RefreshFn refreshFn;
  late _RecordingSink sink;

  setUp(() async {
    fakePlatform = _FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = fakePlatform;
    tokenStore = TokenStore(const FlutterSecureStorage());
    refreshFn = _RefreshFn();
    sink = _RecordingSink();
    AuthInterceptor.debugResetInFlight();
  });

  setUpAll(() {
    registerFallbackValue('');
  });

  /// Build a Dio with the `AuthInterceptor` chained and a scripted adapter.
  (Dio, _ScriptedAdapter, AuthInterceptor) buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
    final adapter = _ScriptedAdapter();
    dio.httpClientAdapter = adapter;
    final interceptor = AuthInterceptor(
      tokenStore: tokenStore,
      refreshFn: refreshFn.call,
      authStateSink: sink,
    )..dio = dio;
    dio.interceptors.add(interceptor);
    return (dio, adapter, interceptor);
  }

  test('attaches Authorization header when a token is stored', () async {
    await tokenStore.save(
      const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
    final (dio, adapter, _) = buildDio();
    adapter.enqueue('/api/items', (_) async => _jsonBody({'ok': true}));

    await dio.get<dynamic>('/api/items');

    expect(
      adapter.calls.single.headers['Authorization'],
      'Bearer access-1',
    );
  });

  test('does not attach Authorization header when no tokens stored',
      () async {
    final (dio, adapter, _) = buildDio();
    adapter.enqueue('/api/items', (_) async => _jsonBody({'ok': true}));

    await dio.get<dynamic>('/api/items');

    expect(adapter.calls.single.headers.containsKey('Authorization'), isFalse);
  });

  test('does NOT attach Authorization on /api/auth/login', () async {
    await tokenStore.save(
      const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
    final (dio, adapter, _) = buildDio();
    adapter.enqueue(
      '/api/auth/login',
      (_) async => _jsonBody({'ok': true}),
    );

    await dio.post<dynamic>('/api/auth/login',
        data: <String, String>{'email': 'x', 'password': 'y'});

    expect(adapter.calls.single.headers.containsKey('Authorization'), isFalse);
  });

  test('401 UNAUTHORIZED -> refresh once, retry once, succeed', () async {
    await tokenStore.save(
      const AuthTokens(accessToken: 'old', refreshToken: 'r-old'),
    );
    when(() => refreshFn.call(any())).thenAnswer(
      (_) async =>
          const AuthTokens(accessToken: 'new', refreshToken: 'r-new'),
    );

    final (dio, adapter, _) = buildDio();
    // First hit: 401. Second hit: 200.
    adapter
      ..enqueue(
        '/api/items',
        (_) async => _jsonBody(
          {'error': 'UNAUTHORIZED', 'message': 'expired'},
          status: 401,
        ),
      )
      ..enqueue(
        '/api/items',
        (opts) async {
          // Second call should carry the new Bearer.
          expect(opts.headers['Authorization'], 'Bearer new');
          return _jsonBody({'ok': true});
        },
      );

    final response = await dio.get<Map<String, dynamic>>('/api/items');

    expect(response.statusCode, 200);
    expect(response.data, {'ok': true});
    verify(() => refreshFn.call('r-old')).called(1);
    // Store was updated.
    expect(
      await tokenStore.read(),
      const AuthTokens(accessToken: 'new', refreshToken: 'r-new'),
    );
  });

  test('5 concurrent 401s share ONE refresh call', () async {
    await tokenStore.save(
      const AuthTokens(accessToken: 'old', refreshToken: 'r-old'),
    );

    // Make refresh resolve on a Completer we control so all five requests
    // pile up on the same in-flight future.
    final refreshCompleter = Completer<AuthTokens>();
    var refreshCalls = 0;
    when(() => refreshFn.call(any())).thenAnswer((_) async {
      refreshCalls++;
      return refreshCompleter.future;
    });

    final (dio, adapter, _) = buildDio();
    // Each of the five requests hits /api/items once with 401, then retries
    // once with 200. Enqueue in matched pairs (order matters: adapter
    // serves them FIFO, but Dio fires all five in parallel below).
    for (var i = 0; i < 5; i++) {
      adapter.enqueue(
        '/api/items',
        (_) async => _jsonBody(
          {'error': 'UNAUTHORIZED', 'message': 'expired'},
          status: 401,
        ),
      );
    }
    for (var i = 0; i < 5; i++) {
      adapter.enqueue(
        '/api/items',
        (opts) async {
          expect(opts.headers['Authorization'], 'Bearer new');
          return _jsonBody({'ok': i});
        },
      );
    }

    // Fire five in parallel.
    final futures = List.generate(
      5,
      (_) => dio.get<Map<String, dynamic>>('/api/items'),
    );

    // Wait a tick so all five hit 401 and fan in on the completer.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(refreshCalls, 1, reason: 'refresh started exactly once');

    // Now release the refresh.
    refreshCompleter.complete(
      const AuthTokens(accessToken: 'new', refreshToken: 'r-new'),
    );

    final responses = await Future.wait(futures);
    expect(responses.length, 5);
    for (final r in responses) {
      expect(r.statusCode, 200);
    }
    verify(() => refreshFn.call('r-old')).called(1);
  });

  test('refresh failure calls authStateSink.emitLoggedOut and bubbles',
      () async {
    await tokenStore.save(
      const AuthTokens(accessToken: 'old', refreshToken: 'r-old'),
    );
    when(() => refreshFn.call(any()))
        .thenThrow(StateError('refresh blew up'));

    final (dio, adapter, _) = buildDio();
    adapter.enqueue(
      '/api/items',
      (_) async => _jsonBody(
        {'error': 'UNAUTHORIZED', 'message': 'expired'},
        status: 401,
      ),
    );

    await expectLater(
      dio.get<dynamic>('/api/items'),
      throwsA(isA<DioException>()),
    );
    expect(sink.count, 1);
  });

  test('401 on /api/auth/login is bubbled without refresh attempt',
      () async {
    await tokenStore.save(
      const AuthTokens(accessToken: 'old', refreshToken: 'r-old'),
    );

    final (dio, adapter, _) = buildDio();
    adapter.enqueue(
      '/api/auth/login',
      (_) async => _jsonBody(
        {'error': 'UNAUTHORIZED', 'message': 'bad creds'},
        status: 401,
      ),
    );

    await expectLater(
      dio.post<dynamic>('/api/auth/login',
          data: <String, String>{'email': 'x', 'password': 'y'}),
      throwsA(isA<DioException>()),
    );
    verifyNever(() => refreshFn.call(any()));
    expect(sink.count, 0, reason: 'login failure is not a logout signal');
  });

  test('401 without UNAUTHORIZED envelope bubbles without refresh',
      () async {
    await tokenStore.save(
      const AuthTokens(accessToken: 'old', refreshToken: 'r-old'),
    );

    final (dio, adapter, _) = buildDio();
    adapter.enqueue(
      '/api/items',
      (_) async => _jsonBody(
        // Some different error code — interceptor should not treat as
        // a token-expiry signal.
        {'error': 'FORBIDDEN', 'message': 'nope'},
        status: 401,
      ),
    );

    await expectLater(
      dio.get<dynamic>('/api/items'),
      throwsA(isA<DioException>()),
    );
    verifyNever(() => refreshFn.call(any()));
  });

  test('second 401 after refresh is NOT retried again', () async {
    await tokenStore.save(
      const AuthTokens(accessToken: 'old', refreshToken: 'r-old'),
    );
    when(() => refreshFn.call(any())).thenAnswer(
      (_) async =>
          const AuthTokens(accessToken: 'new', refreshToken: 'r-new'),
    );

    final (dio, adapter, _) = buildDio();
    // First call: 401. Retry: still 401.
    adapter
      ..enqueue(
        '/api/items',
        (_) async => _jsonBody(
          {'error': 'UNAUTHORIZED', 'message': 'expired'},
          status: 401,
        ),
      )
      ..enqueue(
        '/api/items',
        (_) async => _jsonBody(
          {'error': 'UNAUTHORIZED', 'message': 'still bad'},
          status: 401,
        ),
      );

    await expectLater(
      dio.get<dynamic>('/api/items'),
      throwsA(isA<DioException>()),
    );
    verify(() => refreshFn.call(any())).called(1);
  });
}
