// navigation_intent_test.dart
//
// Integration-ish widget tests that pump a standalone GoRouter (mirroring the
// relevant subset of real routes) with the REAL NavigationHistoryObserver and
// RootBackHandler wired together.  This exercises the full navigation-intent
// contract in isolation from the 13+ repository dependencies of createRouter.
//
// Test scope
// ----------
// 1. Happy-path drill-down: /feed → push /courses → push /videos/:id/watch,
//    two handlePopRoute() calls → lands on /feed.  This path goes through
//    RootBackHandler.onPopInvokedWithResult(true) → router.pop() on each step.
//
// 2. Cold-start deep-link: starts at /videos/v1/watch.  Verifies that the
//    observer immediately records the synthetic /courses root entry as the
//    first history item.  Also verifies that router.canPop() is false (there
//    is only one real route), which is the precondition RootBackHandler tests
//    before consulting the synthetic entry.
//
// 3. Cold-start synthetic consumption: simulates what RootBackHandler does
//    when it detects a synthetic entry and router.canPop() is false —
//    consumeSyntheticRoot() + router.go(synthetic).  This is the exact code
//    path inside the handler; testing it directly is the most faithful way to
//    assert the logic because handlePopRoute() on a single-route GoRouter
//    stack does not route through PopScope.onPopInvokedWithResult in test
//    bindings (it is delivered directly to SystemNavigator.pop via
//    RootBackButtonDispatcher).  Production Android 13+ uses a different code
//    path (OnBackInvokedCallback → PopScope) that is not emulated by
//    handlePopRoute(); the on-device checklist in the commit covers that leg.
//
// 4. SystemNavigator.pop when genuinely at the root (no real routes to pop,
//    no synthetic entry).  Both handlePopRoute() and RootBackHandler lead to
//    the same outcome; handlePopRoute() tests the end-to-end result.
//
// 5. Ten-entry observer cap: pushing 11 routes keeps observer.length == 10
//    and evicts the oldest.
//
// Note on route.settings.name format
// ------------------------------------
// GoRouter populates route.settings.name with the ROUTE TEMPLATE (e.g.
// /videos/:id/watch), not the resolved URI (/videos/v1/watch).  Observer
// path assertions therefore use the template form.  The rendered widget text
// (e.g. "WATCH v1") comes from the builder receiving the resolved parameters
// and is used to assert the current page without caring about the name format.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/routing/navigation_history_observer.dart';
import 'package:lifestream_learn_app/core/routing/root_back_handler.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Builds a standalone [GoRouter] that mirrors the relevant production
/// route subset.  [observer] is registered so it fires on every navigation.
GoRouter _buildRouter({
  required String initialLocation,
  required NavigationHistoryObserver observer,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    observers: [observer],
    routes: [
      GoRoute(
        path: '/feed',
        builder: (_, __) => const Scaffold(body: Center(child: Text('FEED'))),
      ),
      GoRoute(
        path: '/courses',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('COURSES'))),
      ),
      GoRoute(
        path: '/videos/:id/watch',
        builder: (_, state) => Scaffold(
          body: Center(
            child: Text('WATCH ${state.pathParameters['id']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/page/:n',
        builder: (_, state) => Scaffold(
          body: Center(child: Text('PAGE ${state.pathParameters['n']}')),
        ),
      ),
    ],
  );
}

/// Pumps a [MaterialApp.router] with [RootBackHandler] wrapping the child —
/// the same shape used in production's [App.build].
Widget _buildApp(GoRouter router, NavigationHistoryObserver observer) {
  return MaterialApp.router(
    routerConfig: router,
    builder: (context, child) => RootBackHandler(
      historyObserver: observer,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. Happy-path drill-down
  // =========================================================================

  group('navigation_intent — happy-path drill-down', () {
    testWidgets(
      'push /feed → /courses → /videos/:id/watch, two backs → /feed',
      (tester) async {
        final observer = NavigationHistoryObserver();
        final router = _buildRouter(
          initialLocation: '/feed',
          observer: observer,
        );

        await tester.pumpWidget(_buildApp(router, observer));
        await tester.pumpAndSettle();

        expect(find.text('FEED'), findsOneWidget,
            reason: 'should start on /feed');

        // Push /courses.
        router.push('/courses');
        await tester.pumpAndSettle();
        expect(find.text('COURSES'), findsOneWidget);

        // Push /videos/v1/watch.
        router.push('/videos/v1/watch');
        await tester.pumpAndSettle();
        expect(find.text('WATCH v1'), findsOneWidget);

        // GoRouter has two routes on the stack; canPop is true.
        expect(router.canPop(), isTrue);

        // First system back: /videos/:id/watch → /courses.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('COURSES'), findsOneWidget,
            reason: 'first back should return to /courses');

        // Second system back: /courses → /feed.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('FEED'), findsOneWidget,
            reason: 'second back should return to /feed');
      },
    );

    testWidgets(
      'observer tracks three entries after two pushes from /feed',
      (tester) async {
        final observer = NavigationHistoryObserver();
        final router = _buildRouter(
          initialLocation: '/feed',
          observer: observer,
        );

        await tester.pumpWidget(_buildApp(router, observer));
        await tester.pumpAndSettle();

        router.push('/courses');
        await tester.pumpAndSettle();
        router.push('/videos/v1/watch');
        await tester.pumpAndSettle();

        // Observer has /feed, /courses, /videos/:id/watch (template form).
        expect(observer.length, 3);
        expect(observer.history[0].path, '/feed');
        expect(observer.history[0].isSynthetic, isFalse);
        expect(observer.history[1].path, '/courses');
        // GoRouter sets route.settings.name to the template path.
        expect(observer.history[2].path, '/videos/:id/watch');
        expect(observer.history[2].isSynthetic, isFalse);
      },
    );
  });

  // =========================================================================
  // 2. Cold-start deep-link observer state
  // =========================================================================

  group('navigation_intent — cold-start deep-link observer state', () {
    testWidgets(
      'starting at /videos/v1/watch: observer injects synthetic /courses first',
      (tester) async {
        final observer = NavigationHistoryObserver();
        final router = _buildRouter(
          initialLocation: '/videos/v1/watch',
          observer: observer,
        );

        await tester.pumpWidget(_buildApp(router, observer));
        await tester.pumpAndSettle();

        expect(find.text('WATCH v1'), findsOneWidget);

        // Observer must have 2 entries: synthetic /courses + real watch route.
        expect(observer.length, 2,
            reason: 'cold-start should inject synthetic /courses entry');
        expect(observer.history[0].isSynthetic, isTrue,
            reason: 'first entry must be the synthetic tab root');
        expect(observer.history[0].path, '/courses');
        // GoRouter stores the template name, not the resolved URI.
        expect(observer.history[1].path, '/videos/:id/watch');
        expect(observer.history[1].isSynthetic, isFalse);

        // router.canPop() is false; the Navigator has only one route entry.
        // This is the precondition that causes RootBackHandler to fall through
        // to the synthetic-entry branch.
        expect(router.canPop(), isFalse,
            reason: 'single-route cold-start has nothing to pop');
      },
    );

    test(
      'starting at /courses/detail: infers synthetic /courses parent',
      () {
        // /courses/detail is not in our mini-router, but we can verify the
        // observer's inference logic directly — this is the same computation
        // NavigationHistoryObserver.didPush calls internally when history is
        // empty and the pushed path is not a shell-branch root.
        final syntheticParent =
            NavigationHistoryObserver.inferSyntheticParent('/courses/detail');
        expect(syntheticParent, '/courses',
            reason:
                '/courses/detail should infer /courses as its synthetic root');
      },
    );
  });

  // =========================================================================
  // 3. Cold-start synthetic consumption (direct path test)
  // =========================================================================

  group('navigation_intent — cold-start synthetic consumption', () {
    testWidgets(
      'consumeSyntheticRoot() + router.go() navigates to /courses',
      (tester) async {
        // This test exercises the exact code path inside
        // RootBackHandler.onPopInvokedWithResult when:
        //   • router.canPop() == false (single cold-start route), AND
        //   • observer.history.first.isSynthetic == true
        //
        // We call consumeSyntheticRoot() + router.go() directly because
        // handlePopRoute() on a single-route GoRouter stack is delivered to
        // SystemNavigator.pop via RootBackButtonDispatcher, bypassing
        // PopScope.onPopInvokedWithResult.  The on-device checklist covers the
        // Android OnBackInvokedCallback path that does go through PopScope.
        final observer = NavigationHistoryObserver();
        final router = _buildRouter(
          initialLocation: '/videos/v1/watch',
          observer: observer,
        );

        await tester.pumpWidget(_buildApp(router, observer));
        await tester.pumpAndSettle();

        expect(find.text('WATCH v1'), findsOneWidget);

        // Pre-condition: synthetic entry exists, canPop is false.
        expect(router.canPop(), isFalse);
        expect(observer.history.first.isSynthetic, isTrue);
        final synthetic = observer.history.first.path; // '/courses'
        expect(synthetic, '/courses');

        // Simulate what RootBackHandler does in its else-if branch:
        //   1. consumeSyntheticRoot() removes the synthetic entry.
        //   2. router.go(synthetic) navigates to /courses.
        final consumed = observer.consumeSyntheticRoot();
        expect(consumed, isTrue,
            reason: 'consumeSyntheticRoot should return true when a synthetic '
                'entry exists');
        router.go(synthetic);
        await tester.pumpAndSettle();

        // We should now be on /courses.
        expect(find.text('COURSES'), findsOneWidget,
            reason: 'router.go(/courses) after synthetic consumption should '
                'display the /courses screen');
      },
    );

    testWidgets(
      'after synthetic consumption, second back exits via SystemNavigator.pop',
      (tester) async {
        // Extend the previous scenario: after landing on /courses via synthetic
        // consumption, a further back press finds canPop()==false and no
        // synthetic → SystemNavigator.pop.
        final List<MethodCall> platformCalls = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });

        final observer = NavigationHistoryObserver();
        final router = _buildRouter(
          initialLocation: '/videos/v1/watch',
          observer: observer,
        );

        await tester.pumpWidget(_buildApp(router, observer));
        await tester.pumpAndSettle();

        // Consume synthetic + navigate to /courses (same as previous test).
        final consumed = observer.consumeSyntheticRoot();
        expect(consumed, isTrue);
        router.go('/courses');
        await tester.pumpAndSettle();
        expect(find.text('COURSES'), findsOneWidget);

        // Now issue a system back.  /courses is the sole route; router.canPop()
        // is false; no synthetic entry remains → SystemNavigator.pop.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(
          platformCalls.any((c) => c.method == 'SystemNavigator.pop'),
          isTrue,
          reason: 'Expected SystemNavigator.pop when no routes remain to pop '
              'and no synthetic entry exists',
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      },
    );

    testWidgets(
      'consumeSyntheticRoot() returns false when history is empty',
      (tester) async {
        final observer = NavigationHistoryObserver();
        final consumed = observer.consumeSyntheticRoot();
        expect(consumed, isFalse,
            reason: 'no synthetic to consume on an empty observer');
      },
    );

    testWidgets(
      'consumeSyntheticRoot() returns false when first entry is not synthetic',
      (tester) async {
        final observer = NavigationHistoryObserver();
        final router = _buildRouter(
          initialLocation: '/feed',
          observer: observer,
        );
        await tester.pumpWidget(_buildApp(router, observer));
        await tester.pumpAndSettle();

        // /feed is a shell-branch root; no synthetic is injected.
        expect(observer.length, 1);
        expect(observer.history.first.isSynthetic, isFalse);
        final consumed = observer.consumeSyntheticRoot();
        expect(consumed, isFalse,
            reason: 'first entry is real, not synthetic; should not consume');
      },
    );
  });

  // =========================================================================
  // 4. SystemNavigator.pop at true root (no synthetic, no real back)
  // =========================================================================

  group('navigation_intent — SystemNavigator.pop at true root', () {
    testWidgets(
      'at /feed with no history, handlePopRoute calls SystemNavigator.pop',
      (tester) async {
        final List<MethodCall> platformCalls = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });

        final observer = NavigationHistoryObserver();
        final router = _buildRouter(
          initialLocation: '/feed',
          observer: observer,
        );

        await tester.pumpWidget(_buildApp(router, observer));
        await tester.pumpAndSettle();

        expect(find.text('FEED'), findsOneWidget);
        expect(router.canPop(), isFalse);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(
          platformCalls.any((c) => c.method == 'SystemNavigator.pop'),
          isTrue,
          reason:
              'Expected SystemNavigator.pop when at the root with nothing to pop',
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      },
    );
  });

  // =========================================================================
  // 5. Ten-entry observer cap
  // =========================================================================

  group('navigation_intent — ten-entry observer cap', () {
    testWidgets(
      'pushing 11 routes keeps observer.length at 10 (oldest evicted)',
      (tester) async {
        final observer = NavigationHistoryObserver();
        // Start at /feed so cold-start synthetic injection is not triggered.
        final router = _buildRouter(
          initialLocation: '/feed',
          observer: observer,
        );

        await tester.pumpWidget(_buildApp(router, observer));
        await tester.pumpAndSettle();

        expect(find.text('FEED'), findsOneWidget);
        // /feed is the first entry; length == 1.
        expect(observer.length, 1);

        // Push 10 more routes (/page/1 through /page/10).
        // Total pushes: 11 (feed + 10 pages); observer must cap at 10.
        for (var i = 1; i <= 10; i++) {
          router.push('/page/$i');
          await tester.pumpAndSettle();
        }

        // Observer must be exactly at the cap.
        expect(
          observer.length,
          NavigationHistoryObserver.maxEntries,
          reason: 'Observer must not grow beyond maxEntries (10)',
        );

        // The oldest entry (/feed) must have been evicted.
        expect(
          observer.history.any((r) => r.path == '/feed'),
          isFalse,
          reason: 'First pushed entry (/feed) should have been evicted',
        );

        // GoRouter stores the template path (/page/:n), not the resolved value.
        // Verify the most-recently pushed entry template is present.
        expect(
          observer.history.last.path,
          '/page/:n',
          reason: 'Last entry should be the /page/:n template',
        );

        // Verify we are also at the right number after checking entries.
        expect(observer.length, NavigationHistoryObserver.maxEntries);
      },
    );

    testWidgets(
      'pushing exactly 10 routes produces exactly 10 observer entries',
      (tester) async {
        final observer = NavigationHistoryObserver();
        final router = _buildRouter(
          initialLocation: '/feed',
          observer: observer,
        );

        await tester.pumpWidget(_buildApp(router, observer));
        await tester.pumpAndSettle();

        // Push 9 more on top of the initial /feed to hit exactly maxEntries.
        for (var i = 1; i <= 9; i++) {
          router.push('/page/$i');
          await tester.pumpAndSettle();
        }

        expect(
          observer.length,
          NavigationHistoryObserver.maxEntries,
          reason: 'Exactly 10 pushes should fill to the cap with no eviction',
        );

        // The initial /feed entry must still be present (no eviction needed).
        expect(observer.history.first.path, '/feed');
      },
    );
  });
}
