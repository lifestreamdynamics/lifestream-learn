import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../data/models/user.dart';

/// Shell hosting the `BottomNavigationBar` + `IndexedStack` child
/// branches (`StatefulShellRoute.indexedStack`). Each tab keeps its own
/// state across tab switches — the feed stays scrolled to where you
/// left it when you come back from Profile.
///
/// Branch layout (fixed across roles so the `IndexedStack` has a stable
/// index):
///   0: /feed           (all roles)
///   1: /browse | /designer | /admin  (role-dependent label + screen)
///   2: /my-courses     (learner only; filtered out of the nav bar for
///                       designers + admins — the router redirects too)
///   3: /profile        (all roles)
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
              final target = tabs[i];
              navigationShell.goBranch(
                target.branchIndex,
                initialLocation:
                    target.branchIndex == navigationShell.currentIndex,
              );
              // If a role-switched branch maps to a path that's not the
              // branch's first route (e.g. designer lands on /designer,
              // not /browse), force-navigate there.
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
    icon: Icons.play_circle_outline,
    selectedIcon: Icons.play_circle,
    label: 'Feed',
  );
  const browse = HomeTabSpec(
    key: 'browse',
    branchIndex: 1,
    path: '/browse',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
    label: 'Browse',
  );
  const designer = HomeTabSpec(
    key: 'designer',
    branchIndex: 1,
    path: '/designer',
    icon: Icons.brush_outlined,
    selectedIcon: Icons.brush,
    label: 'Designer',
  );
  const admin = HomeTabSpec(
    key: 'admin',
    branchIndex: 1,
    path: '/admin',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    label: 'Admin',
  );
  const mine = HomeTabSpec(
    key: 'my-courses',
    branchIndex: 2,
    path: '/my-courses',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
    label: 'My Courses',
  );
  const profile = HomeTabSpec(
    key: 'profile',
    branchIndex: 3,
    path: '/profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Profile',
  );
  switch (role) {
    case UserRole.learner:
      return const [feed, browse, mine, profile];
    case UserRole.courseDesigner:
      return const [feed, designer, profile];
    case UserRole.admin:
      return const [feed, admin, profile];
  }
}

/// Stub designer screen — full authoring arrives in Slice E.
class DesignerStubScreen extends StatelessWidget {
  const DesignerStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Designer')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Designer authoring — coming in Slice E.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Stub admin screen — full panel arrives in Slice F.
class AdminStubScreen extends StatelessWidget {
  const AdminStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Admin panel — coming in Slice F.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
