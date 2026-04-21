import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/routing/navigation_history_observer.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a fake route whose [Route.settings.name] is [location], which
/// mirrors how GoRouter populates routes in its internal Navigator.
Route<dynamic> _fakeRoute(String location) {
  return MaterialPageRoute<void>(
    builder: (_) => const SizedBox.shrink(),
    settings: RouteSettings(name: location),
  );
}

void main() {
  // =========================================================================
  // Construction
  // =========================================================================

  group('NavigationHistoryObserver — construction', () {
    test('starts empty', () {
      final observer = NavigationHistoryObserver();
      expect(observer.length, 0);
      expect(observer.history.isEmpty, isTrue);
    });
  });

  // =========================================================================
  // didPush basics
  // =========================================================================

  group('NavigationHistoryObserver — didPush', () {
    test('appends a RouteRecord with the correct path', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/courses'), null);
      expect(observer.length, 1);
      expect(observer.history.first.path, '/courses');
      expect(observer.history.first.queryParameters, isEmpty);
      expect(observer.history.first.isSynthetic, isFalse);
    });

    test('parses query parameters', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/feed'), null); // prime so not cold-start
      observer.didPush(_fakeRoute('/videos/v1/watch?t=1234'), null);
      final record = observer.history.last;
      expect(record.path, '/videos/v1/watch');
      expect(record.queryParameters, {'t': '1234'});
    });

    test('ignores routes with null or empty name', () {
      final observer = NavigationHistoryObserver();
      final noName = MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
      );
      observer.didPush(noName, null);
      expect(observer.length, 0);

      final emptyName = MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: ''),
      );
      observer.didPush(emptyName, null);
      expect(observer.length, 0);
    });
  });

  // =========================================================================
  // Cap enforcement
  // =========================================================================

  group('NavigationHistoryObserver — cap enforcement', () {
    test('capping at ${NavigationHistoryObserver.maxEntries}: 11th push evicts '
        'the 1st entry', () {
      final observer = NavigationHistoryObserver();
      // Push a shell-branch root first so cold-start injection is not
      // triggered on the very first push below.
      observer.didPush(_fakeRoute('/feed'), null);

      // Push 10 more distinct paths (total 11 pushes after the seed).
      for (var i = 1; i <= 10; i++) {
        observer.didPush(_fakeRoute('/page/$i'), null);
      }

      expect(observer.length, NavigationHistoryObserver.maxEntries);
      // The oldest entry ('/feed') must be gone.
      expect(
        observer.history.any((r) => r.path == '/feed'),
        isFalse,
        reason: 'first pushed path should have been evicted',
      );
      // The most recently pushed entry must be present.
      expect(observer.history.last.path, '/page/10');
    });

    test('exactly ${NavigationHistoryObserver.maxEntries} pushes — no '
        'eviction occurs', () {
      final observer = NavigationHistoryObserver();
      // Start with a shell-branch root to avoid synthetic injection.
      observer.didPush(_fakeRoute('/feed'), null);
      for (var i = 1; i < NavigationHistoryObserver.maxEntries; i++) {
        observer.didPush(_fakeRoute('/page/$i'), null);
      }
      expect(observer.length, NavigationHistoryObserver.maxEntries);
      expect(observer.history.first.path, '/feed');
    });
  });

  // =========================================================================
  // didPop
  // =========================================================================

  group('NavigationHistoryObserver — didPop', () {
    test('removes the last entry', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/feed'), null);
      observer.didPush(_fakeRoute('/courses'), null);
      observer.didPush(_fakeRoute('/courses/c1'), null);

      observer.didPop(_fakeRoute('/courses/c1'), _fakeRoute('/courses'));

      expect(observer.length, 2);
      expect(observer.history.last.path, '/courses');
    });

    test('is a no-op on empty history', () {
      final observer = NavigationHistoryObserver();
      expect(() => observer.didPop(_fakeRoute('/courses'), null), returnsNormally);
      expect(observer.length, 0);
    });
  });

  // =========================================================================
  // didRemove
  // =========================================================================

  group('NavigationHistoryObserver — didRemove', () {
    test('removes the last entry (same as pop semantics)', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/feed'), null);
      observer.didPush(_fakeRoute('/courses'), null);

      observer.didRemove(_fakeRoute('/courses'), null);

      expect(observer.length, 1);
      expect(observer.history.last.path, '/feed');
    });

    test('is a no-op on empty history', () {
      final observer = NavigationHistoryObserver();
      expect(
          () => observer.didRemove(_fakeRoute('/courses'), null),
          returnsNormally);
      expect(observer.length, 0);
    });
  });

  // =========================================================================
  // didReplace
  // =========================================================================

  group('NavigationHistoryObserver — didReplace', () {
    test('replaces the last entry; length stays the same', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/feed'), null);
      observer.didPush(_fakeRoute('/courses'), null);

      observer.didReplace(
        newRoute: _fakeRoute('/courses/c1'),
        oldRoute: _fakeRoute('/courses'),
      );

      expect(observer.length, 2);
      expect(observer.history.last.path, '/courses/c1');
      expect(observer.history.first.path, '/feed');
    });

    test('when history is empty, behaves as a push (length becomes 1)', () {
      final observer = NavigationHistoryObserver();
      // /feed is a shell-branch root so no synthetic is injected.
      observer.didReplace(
        newRoute: _fakeRoute('/feed'),
        oldRoute: null,
      );
      expect(observer.length, 1);
      expect(observer.history.first.path, '/feed');
    });

    test('when empty and non-shell-branch route, synthetic injection occurs', () {
      final observer = NavigationHistoryObserver();
      observer.didReplace(
        newRoute: _fakeRoute('/courses/c1'),
        oldRoute: null,
      );
      // Synthetic /courses + real /courses/c1
      expect(observer.length, 2);
      expect(observer.history.first.isSynthetic, isTrue);
      expect(observer.history.first.path, '/courses');
      expect(observer.history.last.path, '/courses/c1');
    });

    test('no-op when newRoute is null', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/feed'), null);
      observer.didReplace(newRoute: null, oldRoute: _fakeRoute('/feed'));
      expect(observer.length, 1);
      expect(observer.history.first.path, '/feed');
    });
  });

  // =========================================================================
  // clear()
  // =========================================================================

  group('NavigationHistoryObserver — clear', () {
    test('empties the history', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/feed'), null);
      observer.didPush(_fakeRoute('/courses'), null);
      expect(observer.length, 2);

      observer.clear();
      expect(observer.length, 0);
      expect(observer.history.isEmpty, isTrue);
    });
  });

  // =========================================================================
  // Unmodifiable view
  // =========================================================================

  group('NavigationHistoryObserver — history is unmodifiable', () {
    test('throws UnsupportedError on add', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/feed'), null);

      // List.unmodifiable prevents mutation regardless of element type.
      // We must use the correct element type (RouteRecord) to reach the
      // UnsupportedError rather than a type error.
      expect(
        () => observer.history.add(
          RouteRecord(
            path: '/other',
            queryParameters: const {},
            pushedAt: DateTime.now(),
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  // =========================================================================
  // Cold-start synthetic injection
  // =========================================================================

  group('NavigationHistoryObserver — cold-start synthetic injection', () {
    test('first push to /videos/v1/watch injects synthetic /courses', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/videos/v1/watch'), null);

      expect(observer.length, 2);
      expect(observer.history[0].path, '/courses');
      expect(observer.history[0].isSynthetic, isTrue);
      expect(observer.history[0].queryParameters, isEmpty);
      expect(observer.history[1].path, '/videos/v1/watch');
      expect(observer.history[1].isSynthetic, isFalse);
    });

    test('first push to /courses/c1 injects synthetic /courses', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/courses/c1'), null);

      expect(observer.length, 2);
      expect(observer.history[0].path, '/courses');
      expect(observer.history[0].isSynthetic, isTrue);
      expect(observer.history[1].path, '/courses/c1');
    });

    test('first push to /profile/settings/privacy injects synthetic /profile',
        () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/profile/settings/privacy'), null);

      expect(observer.length, 2);
      expect(observer.history[0].path, '/profile');
      expect(observer.history[0].isSynthetic, isTrue);
      expect(observer.history[1].path, '/profile/settings/privacy');
    });

    test('first push to /designer/v1 injects synthetic /courses', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/designer/v1'), null);

      expect(observer.length, 2);
      expect(observer.history[0].path, '/courses');
      expect(observer.history[0].isSynthetic, isTrue);
    });

    test('first push to /feed (shell-branch root) — no synthetic, length is 1',
        () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/feed'), null);

      expect(observer.length, 1);
      expect(observer.history[0].isSynthetic, isFalse);
    });

    test('first push to /courses (shell-branch root) — no synthetic', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/courses'), null);

      expect(observer.length, 1);
    });

    test('first push to /admin (shell-branch root) — no synthetic', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/admin'), null);

      expect(observer.length, 1);
    });

    test('first push to /profile (shell-branch root) — no synthetic', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/profile'), null);

      expect(observer.length, 1);
    });

    test('first push to /login (pre-auth) — no synthetic, length is 1', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/login'), null);

      expect(observer.length, 1);
      expect(observer.history[0].isSynthetic, isFalse);
    });

    test('first push to /login/mfa — no synthetic', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/login/mfa'), null);
      expect(observer.length, 1);
    });

    test('first push to /signup — no synthetic', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/signup'), null);
      expect(observer.length, 1);
    });

    test('first push to /crash-consent — no synthetic', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/crash-consent'), null);
      expect(observer.length, 1);
    });

    test('first push to /designer-application — no synthetic', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/designer-application'), null);
      expect(observer.length, 1);
    });

    test('second push does not inject another synthetic', () {
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/videos/v1/watch'), null);
      // history is now [/courses(synthetic), /videos/v1/watch]
      observer.didPush(_fakeRoute('/videos/v2/watch'), null);
      // must NOT inject again
      expect(observer.length, 3);
      expect(
        observer.history.where((r) => r.isSynthetic).length,
        1,
        reason: 'only one synthetic should exist across the entire history',
      );
    });

    test('path with no known parent prefix — no synthetic', () {
      // e.g. some future /unknown/deep/route
      final observer = NavigationHistoryObserver();
      observer.didPush(_fakeRoute('/unknown/deep/route'), null);
      expect(observer.length, 1);
      expect(observer.history[0].isSynthetic, isFalse);
    });
  });

  // =========================================================================
  // @visibleForTesting path-classification helpers
  // =========================================================================

  group('isShellBranchRoot (private helper exposed for testing)', () {
    test('/feed → true', () {
      expect(NavigationHistoryObserver.isShellBranchRoot('/feed'), isTrue);
    });
    test('/courses → true', () {
      expect(NavigationHistoryObserver.isShellBranchRoot('/courses'), isTrue);
    });
    test('/admin → true', () {
      expect(NavigationHistoryObserver.isShellBranchRoot('/admin'), isTrue);
    });
    test('/profile → true', () {
      expect(NavigationHistoryObserver.isShellBranchRoot('/profile'), isTrue);
    });
    test('/courses/c1 → false', () {
      expect(
          NavigationHistoryObserver.isShellBranchRoot('/courses/c1'), isFalse);
    });
    test('/feeder → false (no prefix match, exact only)', () {
      expect(NavigationHistoryObserver.isShellBranchRoot('/feeder'), isFalse);
    });
  });

  group('isPreAuthOneShot (private helper exposed for testing)', () {
    test('/login → true', () {
      expect(NavigationHistoryObserver.isPreAuthOneShot('/login'), isTrue);
    });
    test('/login/mfa → true', () {
      expect(NavigationHistoryObserver.isPreAuthOneShot('/login/mfa'), isTrue);
    });
    test('/signup → true', () {
      expect(NavigationHistoryObserver.isPreAuthOneShot('/signup'), isTrue);
    });
    test('/crash-consent → true', () {
      expect(
          NavigationHistoryObserver.isPreAuthOneShot('/crash-consent'), isTrue);
    });
    test('/designer-application → true', () {
      expect(NavigationHistoryObserver.isPreAuthOneShot('/designer-application'),
          isTrue);
    });
    test('/courses → false', () {
      expect(NavigationHistoryObserver.isPreAuthOneShot('/courses'), isFalse);
    });
    test('/videos/v1 → false', () {
      expect(NavigationHistoryObserver.isPreAuthOneShot('/videos/v1'), isFalse);
    });
  });

  group('inferSyntheticParent (private helper exposed for testing)', () {
    test('/videos/v1/watch → /courses', () {
      expect(
        NavigationHistoryObserver.inferSyntheticParent('/videos/v1/watch'),
        '/courses',
      );
    });
    test('/courses/c1 → /courses', () {
      expect(
        NavigationHistoryObserver.inferSyntheticParent('/courses/c1'),
        '/courses',
      );
    });
    test('/courses/c1/progress → /courses', () {
      expect(
        NavigationHistoryObserver.inferSyntheticParent('/courses/c1/progress'),
        '/courses',
      );
    });
    test('/designer/v1 → /courses', () {
      expect(
        NavigationHistoryObserver.inferSyntheticParent('/designer/v1'),
        '/courses',
      );
    });
    test('/profile/settings/privacy → /profile', () {
      expect(
        NavigationHistoryObserver.inferSyntheticParent(
            '/profile/settings/privacy'),
        '/profile',
      );
    });
    test('/profile/sub → /profile', () {
      expect(
        NavigationHistoryObserver.inferSyntheticParent('/profile/sub'),
        '/profile',
      );
    });
    test('/feed → null (shell-branch root, caller should not reach here but '
        'the function is safe)', () {
      // _inferSyntheticParent does not check for shell roots — the caller
      // already filtered them out. However it should return null for /feed
      // because /feed does not start with /videos/, /courses/, /designer/,
      // or /profile/.
      expect(
        NavigationHistoryObserver.inferSyntheticParent('/feed'),
        isNull,
      );
    });
    test('/unknown/path → null', () {
      expect(
        NavigationHistoryObserver.inferSyntheticParent('/unknown/path'),
        isNull,
      );
    });
  });

  // =========================================================================
  // RouteRecord equality / hashCode
  // =========================================================================

  group('RouteRecord equality', () {
    test('equal when path + queryParameters + isSynthetic match', () {
      final a = RouteRecord(
        path: '/videos/v1/watch',
        queryParameters: const {'t': '1234'},
        pushedAt: DateTime(2025, 1, 1),
      );
      final b = RouteRecord(
        path: '/videos/v1/watch',
        queryParameters: const {'t': '1234'},
        pushedAt: DateTime(2025, 6, 15), // different — excluded from ==
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when paths differ', () {
      final a = RouteRecord(
        path: '/feed',
        queryParameters: const {},
        pushedAt: DateTime.now(),
      );
      final b = RouteRecord(
        path: '/courses',
        queryParameters: const {},
        pushedAt: DateTime.now(),
      );
      expect(a, isNot(b));
    });

    test('not equal when isSynthetic differs', () {
      final a = RouteRecord(
        path: '/courses',
        queryParameters: const {},
        pushedAt: DateTime.now(),
        isSynthetic: true,
      );
      final b = RouteRecord(
        path: '/courses',
        queryParameters: const {},
        pushedAt: DateTime.now(),
        isSynthetic: false,
      );
      expect(a, isNot(b));
    });

    test('not equal when queryParameters differ', () {
      final a = RouteRecord(
        path: '/videos/v1/watch',
        queryParameters: const {'t': '0'},
        pushedAt: DateTime.now(),
      );
      final b = RouteRecord(
        path: '/videos/v1/watch',
        queryParameters: const {'t': '9999'},
        pushedAt: DateTime.now(),
      );
      expect(a, isNot(b));
    });
  });
}
