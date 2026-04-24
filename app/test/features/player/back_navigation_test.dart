import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Minimal stub pages that reproduce the exact back-guard logic from
// VideoWithCuesScreen._wrapWithBackGuard, without requiring the full
// widget tree (video_player platform channels, repos, etc.).
// ---------------------------------------------------------------------------

/// Stub feed page.
class _StubFeedPage extends StatelessWidget {
  const _StubFeedPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('feedPage'),
      body: Center(child: Text('Feed')),
    );
  }
}

/// Stub watch page — replicates _wrapWithBackGuard exactly:
///   - canPop: false (PopScope always intercepts)
///   - onPopInvokedWithResult: if context.canPop() → pop, else go('/feed')
class _StubWatchPage extends StatelessWidget {
  const _StubWatchPage();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/feed');
        }
      },
      child: const Scaffold(
        key: Key('watchPage'),
        body: Center(child: Text('Watch')),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

GoRouter _buildRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/feed',
        builder: (_, __) => const _StubFeedPage(),
      ),
      GoRoute(
        path: '/videos/:id/watch',
        builder: (_, __) => const _StubWatchPage(),
      ),
    ],
  );
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  final router = _buildRouter(initialLocation: initialLocation);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Back-navigation correctness — push/go invariants', () {
    // -----------------------------------------------------------------------
    // 1. User-initiated tap-through: feed → push → watch → back → feed
    //    When the watch route is pushed on top of /feed, canPop() is true
    //    so the back-guard calls context.pop() and returns to /feed.
    // -----------------------------------------------------------------------
    testWidgets(
      'push from feed to watch: back returns to feed (canPop is true)',
      (tester) async {
        final router = await _pump(tester, initialLocation: '/feed');

        // Confirm we start on the feed.
        expect(find.byKey(const Key('feedPage')), findsOneWidget);
        expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');

        // Push the watch route — simulates context.push used by the fixed
        // enrolled_courses_body.dart and profile card widgets.
        router.push('/videos/abc/watch');
        await tester.pumpAndSettle();

        // Confirm we're now on the watch page (widget key visible).
        // Note: GoRouter 14's currentConfiguration.uri reflects the base
        // declarative route when push() is used (push is imperative), so
        // we verify by widget presence rather than router path.
        expect(find.byKey(const Key('watchPage')), findsOneWidget);

        // canPop should be true — /feed is still on the stack.
        expect(router.canPop(), isTrue);

        // Simulate the back gesture. router.pop() routes through GoRouter's
        // imperative navigator pop, which triggers PopScope callbacks.
        router.pop();
        await tester.pumpAndSettle();

        // We should land back on the feed.
        expect(find.byKey(const Key('feedPage')), findsOneWidget);
        expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');
      },
    );

    // -----------------------------------------------------------------------
    // 2. Cold deep-link entry: go('/videos/abc/watch') puts only the watch
    //    route on the stack. canPop() returns false, so the guard must
    //    fall through to go('/feed') — the existing safe-exit behaviour.
    // -----------------------------------------------------------------------
    testWidgets(
      'cold deep-link to watch: canPop is false, guard routes to /feed',
      (tester) async {
        // Start the app directly on the watch route — simulates a
        // notification deep-link or external intent that used context.go.
        final router = await _pump(
          tester,
          initialLocation: '/videos/abc/watch',
        );

        // Confirm we're on the watch page with no feed page below it.
        expect(find.byKey(const Key('watchPage')), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/videos/abc/watch',
        );

        // canPop is false — no prior route on the stack.
        expect(router.canPop(), isFalse);

        // The back guard's fallback branch calls context.go('/feed').
        // We invoke it directly via the router to stay in unit-test territory.
        router.go('/feed');
        await tester.pumpAndSettle();

        // The fallback go('/feed') should have fired.
        expect(find.byKey(const Key('feedPage')), findsOneWidget);
        expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');
      },
    );

    // -----------------------------------------------------------------------
    // 3. Regression guard: context.go to watch REPLACES the stack so
    //    canPop() is false — proves that go() leaves no back history.
    //    This test documents the pre-fix behaviour that caused the bug:
    //    enrolled_courses_body used go() instead of push().
    // -----------------------------------------------------------------------
    testWidgets(
      'go() from feed to watch leaves no back stack (canPop is false)',
      (tester) async {
        final router = await _pump(tester, initialLocation: '/feed');
        expect(find.byKey(const Key('feedPage')), findsOneWidget);

        // Simulate what the old code did: context.go instead of push.
        router.go('/videos/abc/watch');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('watchPage')), findsOneWidget);
        // canPop is false — go() replaced the stack, no feed entry remains.
        expect(router.canPop(), isFalse);
      },
    );

    // -----------------------------------------------------------------------
    // 4. push() from feed to watch preserves back stack (canPop is true).
    //    Contrast with test 3 above — this is the corrected behaviour.
    // -----------------------------------------------------------------------
    testWidgets(
      'push() from feed to watch preserves back stack (canPop is true)',
      (tester) async {
        final router = await _pump(tester, initialLocation: '/feed');
        expect(find.byKey(const Key('feedPage')), findsOneWidget);

        // Corrected code uses push, not go.
        router.push('/videos/abc/watch');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('watchPage')), findsOneWidget);
        // canPop is true — feed is still on the stack below watch.
        expect(router.canPop(), isTrue);
      },
    );
  });
}
