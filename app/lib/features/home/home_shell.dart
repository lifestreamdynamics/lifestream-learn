import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/haptics.dart';
import '../../data/models/user.dart';

/// Shell hosting the `BottomNavigationBar` + `IndexedStack` child
/// branches (`StatefulShellRoute.indexedStack`). Each tab keeps its own
/// state across tab switches — the feed stays scrolled to where you
/// left it when you come back from Profile.
///
/// Branch layout (fixed across roles so the `IndexedStack` has a stable
/// index):
///   0: /feed     (all roles)
///   1: /courses  (all roles — replaces former /browse, /my-courses, /designer)
///   2: /admin    (admin only; routed-to-role-home for other roles)
///   3: /profile  (all roles)
///
/// Non-admin roles simply don't render the admin tab in the bottom nav
/// (see `tabsForRole`); the branch slot still exists so the stack index
/// stays consistent regardless of role.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, next) => prev.runtimeType != next.runtimeType,
      builder: (context, authState) {
        if (authState is! Authenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = authState.user.role;
        final tabs = tabsForRole(role);
        // Map the currently-active branch index to the tab's slot in the
        // (possibly shorter) visible list. If we're on a branch this role
        // doesn't expose as a tab, fall back to branch 0 (Feed).
        final currentBranchIndex = navigationShell.currentIndex;
        final selectedTabIndex = tabs.indexWhere(
          (t) => t.branchIndex == currentBranchIndex,
        );
        final safeSelected = selectedTabIndex < 0 ? 0 : selectedTabIndex;
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            key: const Key('home.nav'),
            selectedIndex: safeSelected,
            onDestinationSelected: (i) {
              Haptics.selection();
              final target = tabs[i];
              navigationShell.goBranch(
                target.branchIndex,
                initialLocation:
                    target.branchIndex == navigationShell.currentIndex,
              );
              // Force-navigate to the canonical path for the target
              // branch. Not strictly necessary today — every branch has
              // exactly one top-level route — but guards against future
              // drift if a branch gains a sub-route the nav should ignore.
              GoRouter.of(context).go(target.path);
            },
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  key: Key('home.nav.${t.key}'),
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selectedIcon),
                  label: t.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Public description of a tab. `branchIndex` aligns with the router's
/// `StatefulShellRoute.indexedStack` branch ordering — **do not reorder
/// without updating the router too**.
class HomeTabSpec {
  const HomeTabSpec({
    required this.key,
    required this.branchIndex,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final String key;
  final int branchIndex;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Role-specific visible tabs. Exposed so widget tests can assert the
/// ordering directly (instead of tap-scraping icons).
List<HomeTabSpec> tabsForRole(UserRole role) {
  const feed = HomeTabSpec(
    key: 'feed',
    branchIndex: 0,
    path: '/feed',
    icon: Icons.play_circle_outline_rounded,
    selectedIcon: Icons.play_circle_rounded,
    label: 'Feed',
  );
  const courses = HomeTabSpec(
    key: 'courses',
    branchIndex: 1,
    path: '/courses',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
    label: 'Courses',
  );
  const admin = HomeTabSpec(
    key: 'admin',
    branchIndex: 2,
    path: '/admin',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings_rounded,
    label: 'Admin',
  );
  const profile = HomeTabSpec(
    key: 'profile',
    branchIndex: 3,
    path: '/profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'Profile',
  );
  switch (role) {
    case UserRole.learner:
      return const [feed, courses, profile];
    case UserRole.courseDesigner:
      return const [feed, courses, profile];
    case UserRole.admin:
      return const [feed, courses, admin, profile];
  }
}
