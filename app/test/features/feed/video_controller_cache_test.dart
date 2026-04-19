import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/features/feed/video_controller_cache.dart';
import 'package:video_player/video_player.dart';

/// Fake `VideoPlayerController` that records disposal without touching
/// the platform plugin. `VideoPlayerController` has a large surface but
/// the cache only cares about `dispose()` — `noSuchMethod` tolerates
/// anything else we accidentally hit.
class _FakeController implements VideoPlayerController {
  _FakeController(this.id);
  final String id;

  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('VideoControllerCache', () {
    test('getOrCreate caches and returns same instance on second call',
        () async {
      final cache = VideoControllerCache(
        capacity: 3,
        factory: (url) async => _FakeController(url),
      );
      final a1 = await cache.getOrCreate('v1', 'url-1');
      final a2 = await cache.getOrCreate('v1', 'url-1');
      expect(identical(a1, a2), true);
      expect(cache.contains('v1'), true);
    });

    test('concurrent getOrCreate for the same id dedupes to one factory call',
        () async {
      var factoryCalls = 0;
      final cache = VideoControllerCache(
        capacity: 3,
        factory: (url) async {
          factoryCalls++;
          // Delay so the second getOrCreate starts before the first
          // resolves.
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return _FakeController(url);
        },
      );

      final f1 = cache.getOrCreate('v1', 'url-1');
      final f2 = cache.getOrCreate('v1', 'url-1');
      final results = await Future.wait<VideoPlayerController>([f1, f2]);
      expect(identical(results[0], results[1]), true);
      expect(factoryCalls, 1,
          reason: 'second call should piggyback on the in-flight future');
    });

    test('evicts the oldest entry when capacity is exceeded + disposes it',
        () async {
      final created = <_FakeController>[];
      final cache = VideoControllerCache(
        capacity: 3,
        factory: (url) async {
          final c = _FakeController(url);
          created.add(c);
          return c;
        },
      );

      await cache.getOrCreate('v1', 'u1');
      await cache.getOrCreate('v2', 'u2');
      await cache.getOrCreate('v3', 'u3');
      // At capacity.
      expect(cache.contains('v1'), true);
      expect(cache.contains('v2'), true);
      expect(cache.contains('v3'), true);

      await cache.getOrCreate('v4', 'u4');

      // v1 evicted.
      expect(cache.contains('v1'), false);
      expect(cache.contains('v2'), true);
      expect(cache.contains('v3'), true);
      expect(cache.contains('v4'), true);

      // Dispose of evicted controller is fire-and-forget — allow the
      // event loop to drain before asserting.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(created[0].disposed, true);
      expect(created[1].disposed, false);
      expect(created[2].disposed, false);
      expect(created[3].disposed, false);
    });

    test('cache hit promotes to MRU: repeated access keeps entry warm',
        () async {
      final created = <_FakeController>[];
      final cache = VideoControllerCache(
        capacity: 3,
        factory: (url) async {
          final c = _FakeController(url);
          created.add(c);
          return c;
        },
      );

      await cache.getOrCreate('v1', 'u1');
      await cache.getOrCreate('v2', 'u2');
      await cache.getOrCreate('v3', 'u3');
      // Touch v1 → it becomes MRU, v2 should be evicted next.
      await cache.getOrCreate('v1', 'u1');
      await cache.getOrCreate('v4', 'u4');

      expect(cache.contains('v1'), true);
      expect(cache.contains('v2'), false);
      expect(cache.contains('v3'), true);
      expect(cache.contains('v4'), true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(created[1].disposed, true);
    });

    test('evictAll disposes every cached controller', () async {
      final created = <_FakeController>[];
      final cache = VideoControllerCache(
        capacity: 3,
        factory: (url) async {
          final c = _FakeController(url);
          created.add(c);
          return c;
        },
      );
      await cache.getOrCreate('v1', 'u1');
      await cache.getOrCreate('v2', 'u2');
      await cache.evictAll();
      expect(cache.contains('v1'), false);
      expect(cache.contains('v2'), false);
      for (final c in created) {
        expect(c.disposed, true);
      }
    });

    test('evict(videoId) disposes that one entry only', () async {
      final created = <_FakeController>[];
      final cache = VideoControllerCache(
        capacity: 3,
        factory: (url) async {
          final c = _FakeController(url);
          created.add(c);
          return c;
        },
      );
      await cache.getOrCreate('v1', 'u1');
      await cache.getOrCreate('v2', 'u2');
      await cache.evict('v1');
      expect(cache.contains('v1'), false);
      expect(cache.contains('v2'), true);
      expect(created[0].disposed, true);
      expect(created[1].disposed, false);
    });

    test(
        'backpressure: fourth concurrent init waits until a slot frees up',
        () async {
      final completers = <String, Completer<VideoPlayerController>>{};
      final cache = VideoControllerCache(
        capacity: 3,
        factory: (url) async {
          final c = Completer<VideoPlayerController>();
          completers[url] = c;
          return c.future;
        },
      );

      // Kick off 4 inits — fourth should NOT be registered as in-flight
      // until one of the first three completes.
      final f1 = cache.getOrCreate('v1', 'u1');
      final f2 = cache.getOrCreate('v2', 'u2');
      final f3 = cache.getOrCreate('v3', 'u3');
      // Let microtasks run so the first three enter _inFlight.
      await Future<void>.delayed(Duration.zero);
      expect(cache.loadCount, 3);
      final f4 = cache.getOrCreate('v4', 'u4');
      // Still 3 — the fourth is awaiting slack.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(completers.containsKey('u4'), false);

      completers['u1']!.complete(_FakeController('u1'));
      await f1;
      // Now v4 should proceed.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(completers.containsKey('u4'), true);
      completers['u2']!.complete(_FakeController('u2'));
      completers['u3']!.complete(_FakeController('u3'));
      completers['u4']!.complete(_FakeController('u4'));
      await Future.wait<void>([f2, f3, f4]);
    });
  });
}
