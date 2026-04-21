import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics_sinks.dart';
import '../crash/crash_consent_bloc.dart';
import '../../data/models/user.dart';
import '../../data/repositories/admin_analytics_repository.dart';
import '../../data/repositories/admin_designer_application_repository.dart';
import '../../data/repositories/attempt_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/cue_repository.dart';
import '../../data/repositories/designer_application_repository.dart';
import '../../data/repositories/enrollment_repository.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/courses/course_detail_screen.dart';
import '../../features/courses/courses_screen.dart';
import '../../features/designer/course_editor_screen.dart';
import '../../features/designer/create_course_screen.dart';
import '../../features/designer/designer_application_screen.dart';
import '../../features/designer/video_editor_screen.dart';
import '../../features/feed/feed_bloc.dart';
import '../../features/feed/feed_event.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/onboarding/crash_consent_screen.dart';
import '../../features/player/video_with_cues_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shared/friendly_error_screen.dart';
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
  required DesignerApplicationRepository designerAppRepo,
  required AdminDesignerApplicationRepository adminDesignerAppRepo,
  required AdminAnalyticsRepository adminAnalyticsRepo,
  CueAnalyticsSink cueAnalyticsSink = const NoopCueAnalyticsSink(),
  VideoAnalyticsSink videoAnalyticsSink = const NoopVideoAnalyticsSink(),
  CrashConsentBloc? crashConsentBloc,
  List<NavigatorObserver> observers = const [],
}) {
  final feedBloc = FeedBloc(feedRepo: feedRepo);

  return GoRouter(
    initialLocation: '/login',
    observers: observers,
    refreshListenable: _CombinedRefresh(<Stream<dynamic>>[
      authBloc.stream,
      if (crashConsentBloc != null) crashConsentBloc.stream,
    ]),
    // Route-level fallback for any unmatched or unresolvable location —
    // keeps the user off a raw go_router "Page not found" red screen.
    errorBuilder: (context, state) => FriendlyErrorScreen(
      title: 'Page not found',
      message: "We couldn't find that screen. Head home and try again.",
      debugError: state.error,
    ),
    redirect: (context, routerState) => resolveRedirect(
      authState: authBloc.state,
      consentStatus: crashConsentBloc?.state,
      location: routerState.uri.path,
    ),
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
        path: '/crash-consent',
        builder: (_, __) => const CrashConsentScreen(),
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
        builder: (_, __) => DesignerApplicationScreen(repo: designerAppRepo),
      ),
      // The `/designer` top-level tab is gone — its functionality folded
      // into `/courses`. The editor entry points below stay, reached via
      // the Course detail screen's owner-only "Edit course" button and
      // the Courses screen's "Create course" FAB.
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
          cueAnalyticsSink: cueAnalyticsSink,
          videoAnalyticsSink: videoAnalyticsSink,
        ),
      ),
      StatefulShellRoute.indexedStack(
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
                    videoAnalyticsSink: videoAnalyticsSink,
                  ),
                ),
              ),
            ],
          ),
          // Branch 1 — Courses (Enrolled / Available tabs). Shared by
          // every role; replaces the former role-specific
          // /browse | /designer | /admin slot.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/courses',
                builder: (_, __) => CoursesScreen(courseRepo: courseRepo),
              ),
            ],
          ),
          // Branch 2 — Admin (admin only; non-admins redirect at
          // `resolveRedirect`). HomeShell hides this tab from
          // non-admins in the bottom nav.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin',
                builder: (_, __) => AdminHomeScreen(
                  adminDesignerAppsRepo: adminDesignerAppRepo,
                  adminAnalyticsRepo: adminAnalyticsRepo,
                  courseRepo: courseRepo,
                ),
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

/// Pure function implementing the router's redirect rule. Exposed so
/// it can be unit-tested in isolation without a live `GoRouter` +
/// navigator tree. Returns `null` when no redirect is needed, or the
/// target path string otherwise.
///
/// Inputs:
/// - [authState] — the current [AuthBloc] state.
/// - [consentStatus] — the current [CrashConsentBloc] state, or `null`
///   when crash-consent gating is disabled.
/// - [location] — the path the router is about to navigate to.
@visibleForTesting
String? resolveRedirect({
  required AuthState authState,
  required CrashConsentStatus? consentStatus,
  required String location,
}) {
  // Still initializing → don't redirect.
  if (authState is AuthInitial || authState is AuthAuthenticating) {
    return null;
  }

  final onAuthRoute = location == '/login' || location == '/signup';
  final onConsentRoute = location == '/crash-consent';

  if (authState is Unauthenticated) {
    return onAuthRoute ? null : '/login';
  }

  if (authState is Authenticated) {
    // Gate authed traffic on the first-launch crash-consent decision.
    // This check runs BEFORE the onAuthRoute → role-home redirect so
    // a user landing on `/login` while still undecided goes straight
    // to the consent screen rather than flashing through their role
    // home. Once the bloc emits `granted` or `denied` the
    // refreshListenable fires and this redirect bounces them on to
    // their role home.
    if (consentStatus == CrashConsentStatus.undecided) {
      return onConsentRoute ? null : '/crash-consent';
    }
    if (onAuthRoute) return _roleHome(authState.user.role);
    if (onConsentRoute) return _roleHome(authState.user.role);

    // Deprecated paths from the old role-specific shell layout fold
    // into the unified /courses tab. Keeping these redirects means old
    // deep-links + shared links keep working.
    if (location == '/browse' ||
        location == '/my-courses' ||
        location == '/designer') {
      return '/courses';
    }

    // Role gating for the tab-anchored routes.
    final role = authState.user.role;
    if (location == '/admin' && role != UserRole.admin) {
      return _roleHome(role);
    }
    // `/courses`, `/feed`, `/profile` are open to all authed roles.
    // Non-tab routes (course detail, designer application, editor
    // entry points) are intentionally unrestricted here — the server
    // enforces per-resource authorization, and gating the URL up-front
    // would break legitimate deep-links (e.g. a designer opening a
    // course-detail URL for a course they collaborate on).
    return null;
  }

  return null;
}

String _roleHome(UserRole role) {
  // Post-Slice G3: all roles land on /courses after login. It's the
  // only tab that's useful for every role out of the box — feed is
  // empty for admins (they don't enroll) and profile is a leaf. For
  // learners, /courses auto-lands on the Enrolled tab (the tabbed
  // screen defaults to tab 0); admins and designers see an explanatory
  // empty-state on Enrolled and can swipe to Available.
  switch (role) {
    case UserRole.admin:
    case UserRole.courseDesigner:
    case UserRole.learner:
      return '/courses';
  }
}

/// Adapts one or more broadcast `Stream`s into a `Listenable` the
/// router can watch. Fires on every event from every input stream so
/// the router re-runs its redirect rule when any of the underlying
/// blocs emits.
class _CombinedRefresh extends ChangeNotifier {
  _CombinedRefresh(List<Stream<dynamic>> streams) {
    notifyListeners();
    _subscriptions = streams
        .map((s) => s.asBroadcastStream().listen((_) => notifyListeners()))
        .toList(growable: false);
  }

  late final List<StreamSubscription<dynamic>> _subscriptions;

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
