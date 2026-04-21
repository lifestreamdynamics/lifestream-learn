import 'dart:collection';
import 'dart:typed_data';

import '../../../data/repositories/me_repository.dart';

/// Small in-memory LRU of avatar bytes keyed by `avatarKey`.
///
/// The server-side upload path rotates `avatarKey` on every upload
/// (`<userId>/<uuid>.<ext>`), so keying the cache by key means a newly
/// uploaded avatar never collides with the previous one — the old entry
/// just ages out of the LRU naturally. No manual invalidation is needed
/// on upload.
///
/// 16 entries is enough to cover the profile header plus a handful of
/// other surfaces (a designer list, an admin table) without crossing
/// into memory-pressure territory: 16 × ≤2 MB = 32 MB upper bound, and
/// in practice avatars are well under 200 KB after client-side
/// resizing.
class AvatarBytesCache {
  AvatarBytesCache({int maxEntries = 16, MeRepository? repo})
      : _maxEntries = maxEntries,
        _repo = repo;

  final int _maxEntries;
  final MeRepository? _repo;
  final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List?>> _inflight =
      <String, Future<Uint8List?>>{};

  /// Shared instance used by ProfileHeader when no explicit cache is
  /// injected by a test. Tests should pass an `AvatarBytesCache` with
  /// a specific [MeRepository] mock rather than rely on this.
  static final AvatarBytesCache instance = AvatarBytesCache();

  /// Load the caller's avatar bytes for [avatarKey]. Returns null when
  /// the server responds 204 (no avatar set) or when the fetch fails —
  /// callers are expected to fall through to another presentation
  /// (Gravatar, initials) rather than surface the error.
  ///
  /// Concurrent calls for the same key coalesce onto a single in-flight
  /// future so a ProfileHeader rebuild storm doesn't hammer the API.
  Future<Uint8List?> load(String avatarKey, MeRepository repo) async {
    final hit = _cache.remove(avatarKey);
    if (hit != null) {
      // LRU touch: re-inserting moves the key to the end.
      _cache[avatarKey] = hit;
      return hit;
    }
    final pending = _inflight[avatarKey];
    if (pending != null) return pending;
    final activeRepo = _repo ?? repo;
    final future = activeRepo.fetchMyAvatar().then<Uint8List?>((bytes) {
      if (bytes != null) {
        _cache[avatarKey] = bytes;
        _evictIfNeeded();
      }
      return bytes;
    }).catchError((Object _) => null);
    _inflight[avatarKey] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(avatarKey);
    }
  }

  /// Drop every entry. Used by tests and by the logout path so a
  /// second account on the same device doesn't flash the previous
  /// user's avatar.
  void clear() {
    _cache.clear();
    _inflight.clear();
  }

  void _evictIfNeeded() {
    while (_cache.length > _maxEntries) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
  }
}
