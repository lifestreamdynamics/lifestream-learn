import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/features/shared/friendly_error_screen.dart';

Widget _wrapScreen(FriendlyErrorScreen screen) {
  final router = GoRouter(
    initialLocation: '/err',
    routes: [
      GoRoute(path: '/err', builder: (_, __) => screen),
      GoRoute(
        path: '/feed',
        builder: (_, __) => const Scaffold(body: Text('feed-home')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('renders title, message, and both CTAs when onRetry provided',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(_wrapScreen(
      FriendlyErrorScreen(
        title: 'Oh no',
        message: 'Could not load',
        onRetry: () => retries++,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Oh no'), findsOneWidget);
    expect(find.text('Could not load'), findsOneWidget);
    expect(find.byKey(const Key('friendlyError.retry')), findsOneWidget);
    expect(find.byKey(const Key('friendlyError.goHome')), findsOneWidget);

    await tester.tap(find.byKey(const Key('friendlyError.retry')));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('Retry button is hidden when onRetry is null', (tester) async {
    await tester.pumpWidget(_wrapScreen(
      const FriendlyErrorScreen(
        title: 'Oh no',
        message: 'Could not load',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('friendlyError.retry')), findsNothing);
    expect(find.byKey(const Key('friendlyError.goHome')), findsOneWidget);
  });

  testWidgets('Go home navigates to the configured homePath',
      (tester) async {
    await tester.pumpWidget(_wrapScreen(
      const FriendlyErrorScreen(
        title: 'Oh no',
        message: 'Could not load',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('friendlyError.goHome')));
    await tester.pumpAndSettle();
    expect(find.text('feed-home'), findsOneWidget);
  });

  testWidgets('does not render debugError text, even when provided',
      (tester) async {
    await tester.pumpWidget(_wrapScreen(
      FriendlyErrorScreen(
        title: 'Oh no',
        message: 'Could not load',
        debugError: Exception('secret internal detail'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('secret internal detail'), findsNothing);
  });
}
