import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/repositories/video_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

void main() {
  group('VideoRepository.playback TTL cache', () {
    test('first fetch hits the network and caches', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);

      final now = DateTime.utc(2026, 1, 1, 12);
      final repo = VideoRepository(dio, clock: () => now);

      adapter.enqueueJson(<String, dynamic>{
        'masterPlaylistUrl': 'http://cdn/hls/v1/master.m3u8?sig=abc',
        'expiresAt': DateTime.utc(2026, 1, 1, 14).toIso8601String(),
      });

      final info = await repo.playback('v1');
      expect(info.masterPlaylistUrl, contains('master.m3u8'));
      expect(adapter.requestLog.length, 1);
      expect(adapter.requestLog.single.path, '/api/videos/v1/playback');
    });

    test('second fetch within TTL does not hit the network', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      var now = DateTime.utc(2026, 1, 1, 12);
      final repo = VideoRepository(dio, clock: () => now);

      adapter.enqueueJson(<String, dynamic>{
        'masterPlaylistUrl': 'http://cdn/hls/v1/master.m3u8',
        'expiresAt': DateTime.utc(2026, 1, 1, 14).toIso8601String(),
      });
      await repo.playback('v1');
      // Advance the clock but well within TTL (safety margin 5min).
      now = DateTime.utc(2026, 1, 1, 13, 0);

      await repo.playback('v1');
      expect(adapter.requestLog.length, 1,
          reason: 'cache hit should not re-call');
    });

    test('expired cache (past safety margin) re-fetches', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      var now = DateTime.utc(2026, 1, 1, 12);
      final repo = VideoRepository(dio, clock: () => now);

      // expiresAt 5 minutes from now → immediately inside the safety
      // margin, so the "cache" is effectively unusable.
      adapter.enqueueJson(<String, dynamic>{
        'masterPlaylistUrl': 'http://cdn/hls/v1/master.m3u8?old',
        'expiresAt': DateTime.utc(2026, 1, 1, 12, 5).toIso8601String(),
      });
      adapter.enqueueJson(<String, dynamic>{
        'masterPlaylistUrl': 'http://cdn/hls/v1/master.m3u8?new',
        'expiresAt': DateTime.utc(2026, 1, 1, 14).toIso8601String(),
      });

      await repo.playback('v1');
      // Push past the 5-minute safety margin (i.e. now > expiresAt -
      // safetyMargin).
      now = DateTime.utc(2026, 1, 1, 12, 1);
      final refreshed = await repo.playback('v1');

      expect(refreshed.masterPlaylistUrl, contains('?new'));
      expect(adapter.requestLog.length, 2);
    });

    test('invalidate drops cache for a specific videoId', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final now = DateTime.utc(2026, 1, 1, 12);
      final repo = VideoRepository(dio, clock: () => now);

      adapter.enqueueJson(<String, dynamic>{
        'masterPlaylistUrl': 'http://cdn/hls/v1/master.m3u8',
        'expiresAt': DateTime.utc(2026, 1, 1, 14).toIso8601String(),
      });
      adapter.enqueueJson(<String, dynamic>{
        'masterPlaylistUrl': 'http://cdn/hls/v2/master.m3u8',
        'expiresAt': DateTime.utc(2026, 1, 1, 14).toIso8601String(),
      });
      await repo.playback('v1');
      await repo.playback('v2');
      expect(adapter.requestLog.length, 2);

      repo.invalidate('v1');
      // v1 cache gone → refetch; v2 still cached.
      adapter.enqueueJson(<String, dynamic>{
        'masterPlaylistUrl': 'http://cdn/hls/v1/master.m3u8?fresh',
        'expiresAt': DateTime.utc(2026, 1, 1, 14).toIso8601String(),
      });
      await repo.playback('v1');
      await repo.playback('v2');
      expect(adapter.requestLog.length, 3,
          reason: 'only v1 refetch should have hit the network');
    });

    test('4xx response invalidates cache + rethrows ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final now = DateTime.utc(2026, 1, 1, 12);
      final repo = VideoRepository(dio, clock: () => now);

      adapter.enqueueError(409, <String, dynamic>{
        'error': 'CONFLICT',
        'message': 'Video is not ready for playback (status=TRANSCODING)',
      });

      await expectLater(
        repo.playback('v1'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'CONFLICT')
            .having((e) => e.statusCode, 'statusCode', 409)),
      );

      // A subsequent successful call must hit the network (error was not
      // cached).
      adapter.enqueueJson(<String, dynamic>{
        'masterPlaylistUrl': 'http://cdn/hls/v1/master.m3u8',
        'expiresAt': DateTime.utc(2026, 1, 1, 14).toIso8601String(),
      });
      await repo.playback('v1');
      expect(adapter.requestLog.length, 2);
    });

    test('5xx response invalidates cache + rethrows ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final now = DateTime.utc(2026, 1, 1, 12);
      final repo = VideoRepository(dio, clock: () => now);

      adapter.enqueueError(500, <String, dynamic>{
        'error': 'INTERNAL_ERROR',
        'message': 'db down',
      });
      await expectLater(
        repo.playback('v1'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );

      adapter.enqueueJson(<String, dynamic>{
        'masterPlaylistUrl': 'http://cdn/hls/v1/master.m3u8',
        'expiresAt': DateTime.utc(2026, 1, 1, 14).toIso8601String(),
      });
      await repo.playback('v1');
      expect(adapter.requestLog.length, 2);
    });
  });

  group('VideoRepository.get', () {
    test('decodes VideoSummary', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = VideoRepository(dio);

      adapter.enqueueJson(<String, dynamic>{
        'id': 'v1',
        'courseId': 'c1',
        'title': 'Intro',
        'orderIndex': 0,
        'status': 'READY',
        'durationMs': 60000,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-02T00:00:00.000Z',
      });
      final v = await repo.get('v1');
      expect(v.id, 'v1');
      expect(v.title, 'Intro');
      expect(v.durationMs, 60000);
    });
  });
}
