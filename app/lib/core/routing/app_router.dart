import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_shell.dart';
import '../auth/auth_bloc.dart';
import '../auth/auth_state.dart';

/// Builds the app router, wired up to react to `AuthBloc` state changes.
GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _GoRouterRefreshStream(authBloc.stream),
    redirect: (context, routerState) {
      final authState = authBloc.state;

      // Still initializing → don't redirect. This avoids flicker on cold
      // boot while `/me` is in flight.
      if (authState is AuthInitial || authState is AuthAuthenticating) {
        return null;
      }

      final location = routerState.uri.path;
      final onAuthRoute = location == '/login' || location == '/signup';

      if (authState is Unauthenticated) {
        return onAuthRoute ? null : '/login';
      }

      if (authState is Authenticated) {
        if (onAuthRoute) {
          return _roleHome(authState.user.role);
        }
        // Role gating on protected areas.
        if (location == '/admin' && authState.user.role != UserRole.admin) {
          return '/feed';
        }
        if (location == '/designer' &&
            authState.user.role == UserRole.learner) {
          return '/feed';
        }
        return null;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, __) => const HomeShell(),
      ),
      GoRoute(
        path: '/designer',
        builder: (_, __) => const HomeShell(),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const HomeShell(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const HomeShell(),
      ),
    ],
  );
}

String _roleHome(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return '/admin';
    case UserRole.courseDesigner:
    case UserRole.learner:
      return '/feed';
  }
}

/// Adapts a broadcast `Stream` into a `Listenable` the router can watch.
/// Standard pattern from go_router's recipes.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
