import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/features/player/caption_loader.dart';
import 'package:video_player/video_player.dart';

import '../../test_support/fake_dio_adapter.dart';

// Minimal valid WebVTT content with one cue.
const _validVtt = '''WEBVTT

00:00:01.000 --> 00:00:04.000
Hello, world.
''';

CaptionTrack _track({String url = 'https://cdn.test/captions/en.vtt'}) =>
    CaptionTrack(
      language: 'en',
      url: url,
      expiresAt: DateTime.utc(2030, 1, 1),
    );

void main() {
  group('CaptionLoader', () {
    test('happy path — returns a WebVTTCaptionFile with at least one cue',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://cdn.test'));
      dio.httpClientAdapter = _PlainTextAdapter(200, _validVtt);

      final loader = CaptionLoader(dio: dio);
      final file = await loader.load(_track());

      expect(file, isA<WebVTTCaptionFile>());
      // The VTT has one cue — verify the parser didn't silently drop it.
      expect(file.captions, isNotEmpty);
    });

    test('empty body → ApiException with code EMPTY_CAPTION', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://cdn.test'));
      dio.httpClientAdapter = _PlainTextAdapter(200, '');

      final loader = CaptionLoader(dio: dio);
      expect(
        () => loader.load(_track()),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'EMPTY_CAPTION'),
        ),
      );
    });

    test('404 response → ApiException with statusCode 404', () async {
      final adapter = FakeDioAdapter();
      adapter.enqueueError(404, {'error': 'NOT_FOUND', 'message': 'gone'});
      final dio = buildTestDio(adapter);

      final loader = CaptionLoader(dio: dio);
      expect(
        () => loader.load(_track()),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('network error → ApiException with code NETWORK_ERROR', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://cdn.test'));
      dio.httpClientAdapter = _ErrorAdapter();

      final loader = CaptionLoader(dio: dio);
      expect(
        () => loader.load(_track()),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'NETWORK_ERROR'),
        ),
      );
    });
  });
}

/// Minimal Dio adapter that responds with a plain-text body at a given
/// status code. Used for WebVTT content which is not JSON.
class _PlainTextAdapter implements HttpClientAdapter {
  _PlainTextAdapter(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = body.codeUnits;
    return ResponseBody.fromBytes(
      List<int>.from(bytes),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: ['text/vtt; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Adapter that always throws a connection error.
class _ErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'Connection refused',
    );
  }

  @override
  void close({bool force = false}) {}
}
