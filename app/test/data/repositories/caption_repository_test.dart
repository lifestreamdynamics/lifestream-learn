import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/repositories/caption_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

Map<String, dynamic> _captionSummaryJson({
  String language = 'en',
  int bytes = 1024,
  String uploadedAt = '2026-04-21T12:00:00.000Z',
}) =>
    <String, dynamic>{
      'language': language,
      'bytes': bytes,
      'uploadedAt': uploadedAt,
    };

void main() {
  group('CaptionRepository.upload', () {
    test('happy path: POSTs raw bytes, correct content-type and query params',
        () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CaptionRepository(dio);

      final payload = Uint8List.fromList('WEBVTT\n\n'.codeUnits);
      adapter.enqueueJson(_captionSummaryJson(language: 'en', bytes: payload.length),
          statusCode: 200);

      final result = await repo.upload(
        videoId: 'v1',
        language: 'en',
        bytes: payload,
        contentType: 'text/vtt',
      );

      expect(result.language, 'en');
      expect(result.bytes, payload.length);

      final req = adapter.requestLog.single;
      expect(req.path, '/api/videos/v1/captions');
      expect(req.method, 'POST');
      expect(req.queryParameters['language'], 'en');
      expect(req.queryParameters.containsKey('setDefault'), isFalse);
    });

    test('setDefault: true adds setDefault=1 to query params', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CaptionRepository(dio);

      final payload = Uint8List.fromList('WEBVTT\n'.codeUnits);
      adapter.enqueueJson(_captionSummaryJson(), statusCode: 200);

      await repo.upload(
        videoId: 'v2',
        language: 'fr',
        bytes: payload,
        contentType: 'text/vtt',
        setDefault: true,
      );

      final req = adapter.requestLog.single;
      expect(req.queryParameters['setDefault'], '1');
    });

    test('413 response surfaces as ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CaptionRepository(dio);

      adapter.enqueueError(413, <String, dynamic>{
        'error': 'PAYLOAD_TOO_LARGE',
        'message': 'Caption file exceeds 512 KB limit',
      });

      await expectLater(
        repo.upload(
          videoId: 'v1',
          language: 'en',
          bytes: Uint8List(1),
          contentType: 'text/vtt',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 413)
            .having((e) => e.code, 'code', 'PAYLOAD_TOO_LARGE')),
      );
    });
  });

  group('CaptionRepository.list', () {
    test('happy path: returns parsed CaptionSummary list', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CaptionRepository(dio);

      adapter.enqueueJson(<String, dynamic>{
        'captions': [
          _captionSummaryJson(language: 'en', bytes: 2048),
          _captionSummaryJson(language: 'fr', bytes: 1500),
        ],
      });

      final captions = await repo.list('v1');
      expect(captions, hasLength(2));
      expect(captions[0].language, 'en');
      expect(captions[0].bytes, 2048);
      expect(captions[1].language, 'fr');

      expect(adapter.requestLog.single.path, '/api/videos/v1/captions');
    });

    test('empty captions array returns empty list', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CaptionRepository(dio);

      adapter.enqueueJson(<String, dynamic>{'captions': <dynamic>[]});

      final captions = await repo.list('v1');
      expect(captions, isEmpty);
    });

    test('403 response throws ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CaptionRepository(dio);

      adapter.enqueueError(403, <String, dynamic>{
        'error': 'FORBIDDEN',
        'message': 'Not the video owner',
      });

      await expectLater(
        repo.list('v1'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.code, 'code', 'FORBIDDEN')),
      );
    });
  });

  group('CaptionRepository.delete', () {
    test('sends DELETE to the correct path and resolves on 204', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CaptionRepository(dio);

      adapter.enqueueEmpty204();

      await expectLater(
        repo.delete(videoId: 'v1', language: 'en'),
        completes,
      );

      final req = adapter.requestLog.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/videos/v1/captions/en');
    });
  });
}
