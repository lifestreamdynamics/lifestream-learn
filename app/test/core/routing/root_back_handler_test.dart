import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/routing/root_back_handler.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [GoRouter] with two routes: '/' and '/other'.
/// The builder wraps its child in [RootBackHandler].
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _HomePage(),
      ),
      GoRoute(
        path: '/other',
        builder: (context, state) => const _OtherPage(),
      ),
    ],
    // Wrap the navigator shell in RootBackHandler.
    // Using the `navigatorKey` approach would require a GlobalKey passed
    // through; instead we use the `builder` parameter which wraps the
    // top-level Navigator widget — exactly the right insertion point.
    redirect: null,
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => context.push('/other'),
          child: const Text('Go to other'),
        ),
      ),
    );
  }
}

class _OtherPage extends StatelessWidget {
  const _OtherPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Other')));
  }
}

/// Pumps a [MaterialApp.router] whose builder wraps the shell in
/// [RootBackHandler].
Future<GoRouter> _pump(WidgetTester tester) async {
  final router = _buildRouter();
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        return RootBackHandler(child: child ?? const SizedBox.shrink());
      },
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RootBackHandler', () {
    testWidgets(
        'navigating to /other then invoking system back returns to /',
        (tester) async {
      final router = await _pump(tester);

      // Navigate to /other.
      router.push('/other');
      await tester.pumpAndSettle();

      // Verify we're on /other.
      expect(find.text('Other'), findsOneWidget);

      // Simulate system back.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Should have returned to '/'.
      expect(find.text('Other'), findsNothing);
      // The home scaffold has the 'Go to other' button.
      expect(find.text('Go to other'), findsOneWidget);
    });

    testWidgets(
        'at root (canPop false) system back calls SystemNavigator.pop',
        (tester) async {
      // Intercept platform method channel calls so SystemNavigator.pop
      // doesn't actually kill the test process.
      final List<MethodCall> calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });

      await _pump(tester);

      // At '/', GoRouter has nothing to pop.
      // Simulate system back.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        calls.any((c) => c.method == 'SystemNavigator.pop'),
        isTrue,
        reason: 'Expected SystemNavigator.pop to be called when at the root',
      );

      // Clean up the mock handler.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });
}
