import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Factory seam. Production code constructs via
/// `VideoPlayerController.networkUrl(Uri.parse(url))` + `.initialize()`;
/// tests inject a stub that returns a fake controller so they never hit
/// the platform channel.
typedef VideoPlayerControllerFactory = Future<VideoPlayerController> Function(
  String url,
);

/// Default factory: builds a real `VideoPlayerController` backed by the
/// platform `video_player` plugin (ExoPlayer on Android via fvp).
Future<VideoPlayerController> defaultVideoControllerFactory(String url) async {
  final controller = VideoPlayerController.networkUrl(Uri.parse(url));
  await controller.initialize();
  return controller;
}

/// LRU cache of pre-initialised `VideoPlayerController`s, keyed by
/// `videoId`. Capacity is **load-bearing**:
///
/// - 3 is the sweet spot on Android — prev + current + next pre-rolled.
/// - Lower values cause stutter during PageView swipes because the next
///   page has to wait on `.initialize()`.
/// - Higher values exhaust MediaCodec decoder instances on low-end
///   devices (some chipsets cap at 4–6 concurrent decoders) and blow up
///   with an IllegalStateException mid-playback.
///
/// Eviction discipline:
/// - Insertion order is the LRU order — a `LinkedHashMap` is perfect.
/// - `getOrCreate` that hits an existing entry promotes it to MRU by
///   re-inserting.
/// - Evicted controllers are `dispose()`d **synchronously-scheduled** to
///   free decoder threads.
///
/// Concurrency:
/// - If three `initialize()` calls are already outstanding, the fourth
///   awaits one to finish before starting. This caps decoder thread
///   contention at the capacity.
/// - Concurrent `getOrCreate(sameVideoId)` calls share one future — no
///   duplicate init.
class VideoControllerCache {
  VideoControllerCache({
    this.capacity = 3,
    VideoPlayerControllerFactory? factory,
  }) : _factory = factory ?? defaultVideoControllerFactory;

  final int capacity;
  final VideoPlayerControllerFactory _factory;

  final LinkedHashMap<String, VideoPlayerController> _cache =
      LinkedHashMap<String, VideoPlayerController>();

  /// In-flight initializations by videoId. Concurrent requests for the
  /// same id piggyback on the same future.
  final Map<String, Future<VideoPlayerController>> _inFlight =
      <String, Future<VideoPlayerController>>{};

  bool contains(String videoId) => _cache.containsKey(videoId);

  /// Total open slots — cached entries + currently-initializing entries.
  /// Callers that want to respect the decoder-thread budget can check
  /// this before kicking off a preload.
  int get loadCount => _cache.length + _inFlight.length;

  /// Returns the cached controller for `videoId` (promoting it to MRU),
  /// or creates one via the factory, caching on success and evicting
  /// whichever controller has been idle longest when capacity is hit.
  ///
  /// Initialization backpressure: if `capacity` init-or-cached slots are
  /// already in use, this method waits for one to free up before
  /// starting a new initialize.
  Future<VideoPlayerController> getOrCreate(String videoId, String url) async {
    // Cache hit — promote MRU and return.
    final existing = _cache.remove(videoId);
    if (existing != null) {
      _cache[videoId] = existing;
      return existing;
    }

    // Dedupe concurrent calls for the same id.
    final pending = _inFlight[videoId];
    if (pending != null) return pending;

    // Backpressure / eviction. Each iteration either:
    //   (a) evicts the oldest cached entry to free a slot, OR
    //   (b) if all slots are held by IN-FLIGHT inits, waits for any of
    //       them to complete before re-checking.
    while (_cache.length + _inFlight.length >= capacity) {
      if (_cache.isNotEmpty) {
        final firstKey = _cache.keys.first;
        final victim = _cache.remove(firstKey)!;
        unawaited(Future(() async {
          try {
            await victim.dispose();
          } catch (e) {
            if (kDebugMode) {
              debugPrint('VideoControllerCache: evicted dispose failed: $e');
            }
          }
        }));
      } else if (_inFlight.isNotEmpty) {
        await Future.any(_inFlight.values.map((f) => f.catchError((Object _) {
              // We just want a completion signal — the value is ignored.
              return _DummyController.instance;
            })));
      } else {
        // Shouldn't reach here given the while-condition, but guard.
        break;
      }
    }

    final future = _factory(url).then((controller) {
      _inFlight.remove(videoId);
      _cache[videoId] = controller;
      return controller;
    }).catchError((Object e, StackTrace st) {
      _inFlight.remove(videoId);
      // Surface the error to the caller; nothing cached.
      throw e;
    });
    _inFlight[videoId] = future;
    return future;
  }

  /// Dispose everything and clear both in-flight and cached maps.
  /// Idempotent. Safe to call from `State.dispose()`.
  Future<void> evictAll() async {
    final controllers = _cache.values.toList(growable: false);
    _cache.clear();
    // Let any in-flight initializations complete and dispose their result.
    final pending = _inFlight.values.toList(growable: false);
    _inFlight.clear();
    await Future.wait<void>([
      for (final c in controllers)
        Future(() async {
          try {
            await c.dispose();
          } catch (_) {
            /* best-effort */
          }
        }),
      for (final p in pending)
        p.then<void>((c) async {
          try {
            await c.dispose();
          } catch (_) {
            /* best-effort */
          }
        }).catchError((Object _) {
          /* init itself failed — nothing to dispose */
        }),
    ]);
  }

  /// Evict a specific entry (no-op if absent). The controller is
  /// disposed. Used by the player when a signed URL expires mid-playback
  /// and we need to start over.
  Future<void> evict(String videoId) async {
    final victim = _cache.remove(videoId);
    if (victim == null) return;
    try {
      await victim.dispose();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VideoControllerCache.evict dispose failed: $e');
      }
    }
  }
}

/// A dummy controller used only as a completion signal inside
/// `Future.any(...).catchError(...)`. Never returned to user code.
class _DummyController implements VideoPlayerController {
  _DummyController._();
  static final _DummyController instance = _DummyController._();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
