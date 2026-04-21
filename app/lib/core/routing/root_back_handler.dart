import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'navigation_history_observer.dart';

/// Root-level back-press fallback for the app shell.
///
/// Resolution order on each invocation:
/// 1. If a descendant [PopScope] already handled the event, do nothing.
/// 2. If GoRouter can pop a real route, pop it.
/// 3. Else if the history observer has a synthetic tab-root entry (cold-start
///    deep-link priming), `go` to that path and consume the synthetic entry.
/// 4. Else exit the app via [SystemNavigator.pop].
class RootBackHandler extends StatelessWidget {
  const RootBackHandler({
    required this.child,
    this.historyObserver,
    super.key,
  });

  final Widget child;
  final NavigationHistoryObserver? historyObserver;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }

        final synthetic = _pendingSyntheticRoot();
        if (synthetic != null) {
          historyObserver!.consumeSyntheticRoot();
          router.go(synthetic);
          return;
        }

        await SystemNavigator.pop();
      },
      child: child,
    );
  }

  String? _pendingSyntheticRoot() {
    final observer = historyObserver;
    if (observer == null || observer.length == 0) return null;
    final first = observer.history.first;
    return first.isSynthetic ? first.path : null;
  }
}
