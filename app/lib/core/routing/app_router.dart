import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user.dart';
import '../../data/repositories/attempt_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/cue_repository.dart';
import '../../data/repositories/enrollment_repository.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/courses/course_detail_screen.dart';
import '../../features/courses/courses_browse_screen.dart';
import '../../features/courses/my_courses_screen.dart';
import '../../features/designer/course_editor_screen.dart';
import '../../features/designer/create_course_screen.dart';
import '../../features/designer/designer_home_screen.dart';
import '../../features/designer/video_editor_screen.dart';
import '../../features/feed/feed_bloc.dart';
import '../../features/feed/feed_event.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/player/video_with_cues_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../auth/auth_bloc.dart';
import '../auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Builds the app router. Repositories are injected (owned by
/// `main.dart`) so tests that need a router can swap them for fakes.
GoRouter createRouter(
  AuthBloc authBloc, {
  required FeedRepository feedRepo,
  required CourseRepository courseRepo,
  required VideoRepository videoRepo,
  required EnrollmentRepository enrollmentRepo,
  required CueRepository cueRepo,
  required AttemptRepository attemptRepo,
}) {
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  final feedBloc = FeedBloc(feedRepo: feedRepo);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _GoRouterRefreshStream(authBloc.stream),
    redirect: (context, routerState) {
      final authState = authBloc.state;

      // Still initializing → don't redirect.
      if (authState is AuthInitial || authState is AuthAuthenticating) {
        return null;
      }

      final location = routerState.uri.path;
      final onAuthRoute = location == '/login' || location == '/signup';

      if (authState is Unauthenticated) {
        return onAuthRoute ? null : '/login';
      }

      if (authState is Authenticated) {
        if (onAuthRoute) return _roleHome(authState.user.role);

        // Role gating for the tab-anchored routes. Non-tabs (e.g. course
        // detail, designer-application) are allowed for any authed user.
        final role = authState.user.role;
        if (location == '/admin' && role != UserRole.admin) {
          return _roleHome(role);
        }
        if (location == '/designer' && role == UserRole.learner) {
          return _roleHome(role);
        }
        if (location == '/my-courses' && role != UserRole.learner) {
          return _roleHome(role);
        }
        if (location == '/browse' && role != UserRole.learner) {
          return _roleHome(role);
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
        path: '/courses/:id',
        builder: (context, state) => CourseDetailScreen(
          courseId: state.pathParameters['id']!,
          courseRepo: courseRepo,
        ),
      ),
      GoRoute(
        path: '/designer-application',
        builder: (_, __) => const DesignerApplicationStubScreen(),
      ),
      GoRoute(
        path: '/designer/courses/new',
        builder: (_, __) => CreateCourseScreen(courseRepo: courseRepo),
      ),
      GoRoute(
        path: '/designer/courses/:id',
        builder: (context, state) => CourseEditorScreen(
          courseId: state.pathParameters['id']!,
          courseRepo: courseRepo,
          videoRepo: videoRepo,
        ),
      ),
      GoRoute(
        path: '/designer/videos/:id/edit',
        builder: (context, state) => VideoEditorScreen(
          videoId: state.pathParameters['id']!,
          videoRepo: videoRepo,
          cueRepo: cueRepo,
          enrollmentRepo: enrollmentRepo,
        ),
      ),
      GoRoute(
        path: '/videos/:id/watch',
        builder: (context, state) => VideoWithCuesScreen(
          videoId: state.pathParameters['id']!,
          videoRepo: videoRepo,
          cueRepo: cueRepo,
          attemptRepo: attemptRepo,
          enrollmentRepo: enrollmentRepo,
        ),
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: shellNavigatorKey,
        builder: (context, _, navigationShell) => HomeShell(
          navigationShell: navigationShell,
        ),
        branches: <StatefulShellBranch>[
          // Branch 0 — Feed (all roles).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/feed',
                builder: (_, __) => BlocProvider<FeedBloc>.value(
                  value: feedBloc..add(const FeedLoadRequested()),
                  child: FeedScreen(
                    videoRepo: videoRepo,
                    enrollmentRepo: enrollmentRepo,
                  ),
                ),
              ),
            ],
          ),
          // Branch 1 — Browse (learner) / Designer (designer) / Admin (admin).
          // Route paths are distinct so role-based redirects work; shell
          // index is the same slot for all three.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/browse',
                builder: (_, __) =>
                    CoursesBrowseScreen(courseRepo: courseRepo),
              ),
              GoRoute(
                path: '/designer',
                builder: (_, __) =>
                    DesignerHomeScreen(courseRepo: courseRepo),
              ),
              GoRoute(
                path: '/admin',
                builder: (_, __) => const AdminStubScreen(),
              ),
            ],
          ),
          // Branch 2 — My Courses (learner only; empty stub for other roles
          // but redirect keeps them out).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/my-courses',
                builder: (_, __) => MyCoursesScreen(courseRepo: courseRepo),
              ),
            ],
          ),
          // Branch 3 — Profile (all roles).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

String _roleHome(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return '/feed';
    case UserRole.courseDesigner:
      return '/feed';
    case UserRole.learner:
      return '/feed';
  }
}

/// Adapts a broadcast `Stream` into a `Listenable` the router can watch.
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
