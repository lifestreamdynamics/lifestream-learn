import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/video.dart';

/// Signed-URL cache entry. Stored alongside the `PlaybackInfo` so the
/// `VideoRepository` can decide whether to reuse or refetch without
/// round-tripping through a `DateTime.parse`.
class _PlaybackCacheEntry {
  const _PlaybackCacheEntry(this.info, this.expiresAt);
  final PlaybackInfo info;
  final DateTime expiresAt;
}

/// Wraps `GET /api/videos/:id` and `GET /api/videos/:id/playback`.
///
/// The playback endpoint returns a short-lived HMAC-signed master playlist
/// URL. Re-fetching it for every page swipe in a feed would hammer the API
/// and incur unnecessary latency, so we keep an in-memory cache keyed by
/// videoId. The effective TTL is `(expiresAt - now - safetyMargin)` where
/// safetyMargin defaults to 5 minutes — better to re-fetch a fresh URL
/// than hand the player a token that expires mid-segment-download.
///
/// Cache invariants:
/// - Only 2xx responses populate the cache.
/// - 4xx and 5xx responses invalidate the cached entry for that videoId
///   (but leave other entries untouched).
/// - No network call is attempted while a fresh entry exists.
class VideoRepository {
  VideoRepository(
    this._dio, {
    this.cacheSafetyMargin = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final Dio _dio;

  /// How long before `expiresAt` we consider the cached URL stale. The
  /// nginx secure_link HMAC binds to an absolute expiry; if we hand a URL
  /// to the player with 30 seconds to spare and the player pauses for
  /// buffering, the first segment fetch after resume will 403. Defaulting
  /// to 5 minutes keeps a comfortable margin without churning the cache.
  final Duration cacheSafetyMargin;

  /// Pluggable clock for tests — production code calls `DateTime.now`.
  final DateTime Function() _now;

  /// `videoId → cache entry`. Map is private so tests exercise behaviour
  /// via `playback()` / `debugClearCache()` only.
  final Map<String, _PlaybackCacheEntry> _cache = <String, _PlaybackCacheEntry>{};

  Future<VideoSummary> get(String id) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/videos/$id');
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty video response',
        );
      }
      return VideoSummary.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Returns a fresh-enough `PlaybackInfo` for the given video.
  ///
  /// If a cached entry exists AND `expiresAt - now > safetyMargin`, it's
  /// returned directly with no network call. Otherwise the underlying
  /// endpoint is hit. On any Dio failure the cache is invalidated for
  /// this videoId and the error rethrown as an `ApiException`.
  Future<PlaybackInfo> playback(String id) async {
    final cached = _cache[id];
    if (cached != null) {
      final remaining = cached.expiresAt.difference(_now());
      if (remaining > cacheSafetyMargin) {
        return cached.info;
      }
    }
    try {
      final response = await _dio
          .get<Map<String, dynamic>>('/api/videos/$id/playback');
      final data = response.data;
      if (data == null) {
        _cache.remove(id);
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty playback response',
        );
      }
      final info = PlaybackInfo.fromJson(data);
      _cache[id] = _PlaybackCacheEntry(info, info.expiresAt);
      return info;
    } on DioException catch (e) {
      _cache.remove(id);
      throw _unwrap(e);
    }
  }

  /// Drop a specific cache entry. Called by the player when it detects a
  /// mid-stream signed-URL failure and wants a fresh URL.
  void invalidate(String videoId) {
    _cache.remove(videoId);
  }

  /// Test-only hook.
  void debugClearCache() => _cache.clear();

  ApiException _unwrap(DioException e) {
    final err = e.error;
    if (err is ApiException) return err;
    return ApiException(
      code: 'NETWORK_ERROR',
      statusCode: e.response?.statusCode ?? 0,
      message: e.message ?? 'Network error',
    );
  }
}
