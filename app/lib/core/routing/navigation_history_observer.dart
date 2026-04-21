import 'package:flutter/widgets.dart';

/// A [NavigatorObserver] that maintains a bounded history of visited routes.
///
/// Keeps the last [maxEntries] routes (FIFO eviction of the oldest on
/// overflow). Exposes a read-only [history] list for tests and analytics;
/// never drives navigation — observe, don't control.
///
/// Register this in the GoRouter `observers: [...]` list alongside any
/// crash-reporter observer. This observer fires on every GoRouter navigation
/// because GoRouter uses a real [Navigator] under the hood.
///
/// Thread safety: Navigator callbacks fire on the main thread from within the
/// Navigator's transaction; no locking is needed.
class NavigationHistoryObserver extends NavigatorObserver {
  NavigationHistoryObserver() : _entries = [];

  static const int maxEntries = 10;

  final List<RouteRecord> _entries;

  /// Unmodifiable view of the current history (oldest first, newest last).
  List<RouteRecord> get history => List.unmodifiable(_entries);

  /// Current number of entries in the history.
  int get length => _entries.length;

  /// Clears the history. Call on logout so stale breadcrumbs do not survive
  /// across the auth boundary.
  void clear() => _entries.clear();

  /// If the first history entry is a cold-start synthetic tab-root, remove it
  /// and return `true`. Used by [RootBackHandler] to avoid re-consuming the
  /// same synthetic entry on a subsequent back press.
  bool consumeSyntheticRoot() {
    if (_entries.isEmpty) return false;
    if (!_entries.first.isSynthetic) return false;
    _entries.removeAt(0);
    return true;
  }

  // -------------------------------------------------------------------------
  // NavigatorObserver overrides
  // -------------------------------------------------------------------------

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _handlePush(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_entries.isNotEmpty) {
      _entries.removeLast();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Removal is rarer (e.g. Navigator.removeRoute) but semantically similar
    // to a pop from the history perspective — trim the top entry.
    if (_entries.isNotEmpty) {
      _entries.removeLast();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_entries.isEmpty) {
      // Empty history during a replace is an unusual edge case.  Delegate to
      // the push logic (which also handles cold-start synthetic injection).
      if (newRoute != null) {
        _handlePush(newRoute);
      }
      return;
    }

    // Replace the top entry with a record derived from the new route.
    // Do NOT run cold-start injection here — we already have history.
    if (newRoute == null) return;
    final raw = newRoute.settings.name;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.parse(raw);
    final record = RouteRecord(
      path: uri.path,
      queryParameters: uri.queryParameters,
      pushedAt: DateTime.now(),
    );
    _entries[_entries.length - 1] = record;
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  void _handlePush(Route<dynamic> route) {
    final raw = route.settings.name;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.parse(raw);
    final path = uri.path;
    final qp = uri.queryParameters;

    // Cold-start synthetic injection: if history is empty and the first pushed
    // route is neither a shell-branch root nor a pre-auth/one-shot route,
    // prepend a synthetic entry for the inferred parent tab so the user has
    // somewhere to back-navigate to.
    if (_entries.isEmpty &&
        !_isShellBranchRoot(path) &&
        !_isPreAuthOneShot(path)) {
      final syntheticPath = _inferSyntheticParent(path);
      if (syntheticPath != null) {
        _entries.add(RouteRecord(
          path: syntheticPath,
          queryParameters: const {},
          pushedAt: DateTime.now(),
          isSynthetic: true,
        ));
      }
    }

    _entries.add(RouteRecord(
      path: path,
      queryParameters: qp,
      pushedAt: DateTime.now(),
    ));

    // FIFO eviction: if we exceeded the cap, drop the oldest entry.
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  /// Returns `true` for the shell-branch roots that are valid landing spots
  /// on their own — no synthetic parent injection needed.
  @visibleForTesting
  static bool isShellBranchRoot(String path) => _isShellBranchRoot(path);

  static bool _isShellBranchRoot(String path) {
    return path == '/feed' ||
        path == '/courses' ||
        path == '/admin' ||
        path == '/profile';
  }

  /// Returns `true` for pre-auth and one-shot routes that should never trigger
  /// synthetic parent injection (they have no meaningful "back" destination
  /// within the authenticated shell).
  @visibleForTesting
  static bool isPreAuthOneShot(String path) => _isPreAuthOneShot(path);

  static bool _isPreAuthOneShot(String path) {
    return path == '/login' ||
        path == '/login/mfa' ||
        path == '/signup' ||
        path == '/crash-consent' ||
        path == '/designer-application';
  }

  /// Infers the appropriate shell-branch root to inject as a synthetic first
  /// history entry when a deep route is the cold-start destination.
  ///
  /// Returns `null` when no synthetic parent is applicable.
  @visibleForTesting
  static String? inferSyntheticParent(String path) =>
      _inferSyntheticParent(path);

  static String? _inferSyntheticParent(String path) {
    if (path.startsWith('/profile/') || path == '/profile') {
      return '/profile';
    }
    if (path.startsWith('/videos/') ||
        path.startsWith('/courses/') ||
        path.startsWith('/designer/')) {
      return '/courses';
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// RouteRecord
// ---------------------------------------------------------------------------

/// An immutable snapshot of a single navigation event.
///
/// [pushedAt] is intentionally excluded from [==] / [hashCode] so tests can
/// compare records without worrying about clock precision.
class RouteRecord {
  const RouteRecord({
    required this.path,
    required this.queryParameters,
    required this.pushedAt,
    this.isSynthetic = false,
  });

  /// The path component of the route URI (e.g. `/videos/v1/watch`).
  final String path;

  /// The query parameters of the route URI (e.g. `{'t': '1234'}`).
  final Map<String, String> queryParameters;

  /// The moment this record was created.  Client-sourced; prefer
  /// server-side timestamps for analytics queries where clock skew matters.
  final DateTime pushedAt;

  /// `true` when this entry was injected synthetically during cold-start
  /// deep-link handling (not the result of a real user navigation).
  final bool isSynthetic;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RouteRecord) return false;
    if (path != other.path) return false;
    if (isSynthetic != other.isSynthetic) return false;
    if (queryParameters.length != other.queryParameters.length) return false;
    for (final entry in queryParameters.entries) {
      if (other.queryParameters[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        path,
        isSynthetic,
        Object.hashAllUnordered(
          queryParameters.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() =>
      'RouteRecord(path: $path, qp: $queryParameters, '
      'pushedAt: $pushedAt, isSynthetic: $isSynthetic)';
}
