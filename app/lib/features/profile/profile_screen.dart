import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import '../../core/auth/auth_state.dart';
import '../../data/models/achievement.dart';
import '../../data/models/user.dart';
import '../../data/repositories/me_repository.dart';
import '../../data/repositories/progress_repository.dart';
import 'profile_bloc.dart';
import 'widgets/achievement_grid.dart';
import 'widgets/edit_profile_sheet.dart';
import 'widgets/enrolled_course_card.dart';
import 'widgets/mfa_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/progress_overview_card.dart';
import 'widgets/quick_stats_strip.dart';
import 'widgets/streak_card.dart';

/// Profile tab. Slice P2 adds the headline "progress dashboard": an
/// overview card + a per-course list fed by `GET /api/me/progress`.
///
/// The screen owns a `ProfileBloc` which loads on mount and refreshes
/// on pull-to-refresh. P1's edit-profile sheet + logout + "apply to
/// become designer" tile all survive.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.meRepo,
    required this.progressRepo,
    super.key,
  });

  final MeRepository meRepo;
  final ProgressRepository progressRepo;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileBloc>(
      create: (_) => ProfileBloc(progressRepo: progressRepo)
        ..add(const ProfileLoadRequested()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is! Authenticated) {
              return const Center(child: CircularProgressIndicator());
            }
            return _ProfileBody(
              user: state.user,
              meRepo: meRepo,
              progressRepo: progressRepo,
            );
          },
        ),
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({
    required this.user,
    required this.meRepo,
    required this.progressRepo,
  });

  final User user;
  final MeRepository meRepo;
  final ProgressRepository progressRepo;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  // Tracks which recentlyUnlocked ids we've already toasted on this
  // screen instance — belt-and-braces against a BlocListener firing
  // twice on the same ProfileLoaded (e.g. a rebuild from a widget
  // higher up the tree).
  final Set<String> _toastedIds = <String>{};

  // Tracks whether we've already tried to patch the timezone-offset
  // preference this session; the patch is silent and one-shot.
  bool _timezonePatchSent = false;

  User get user => widget.user;
  MeRepository get meRepo => widget.meRepo;
  ProgressRepository get progressRepo => widget.progressRepo;

  @override
  void initState() {
    super.initState();
    _maybePatchTimezone();
  }

  /// Slice P3 — silent one-shot: if the user has no
  /// `timezoneOffsetMinutes` in their preferences blob yet, set it to
  /// the device's current offset. Makes streak day-rollover match the
  /// learner's local midnight on the server side. Failure is logged to
  /// the noop — a streak misalignment is a soft bug, not a blocker.
  void _maybePatchTimezone() {
    if (_timezonePatchSent) return;
    final prefs = user.preferences ?? const <String, dynamic>{};
    if (prefs.containsKey('timezoneOffsetMinutes')) return;
    _timezonePatchSent = true;
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    final newPrefs = <String, dynamic>{
      ...prefs,
      'timezoneOffsetMinutes': offset,
    };
    // Fire-and-forget. We don't await or surface an error — the hook
    // is best-effort and will retry on next profile open.
    meRepo.patchMe(preferences: newPrefs).catchError((_) => user);
  }

  void _toastUnlocks(BuildContext context, List<AchievementSummary> rows) {
    // Queue up one SnackBar per new unlock. Flutter's ScaffoldMessenger
    // already queues them; we just dedupe so a second ProfileLoaded with
    // the same payload doesn't double-toast.
    for (final row in rows) {
      if (_toastedIds.contains(row.id)) continue;
      _toastedIds.add(row.id);
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          key: Key('profile.unlockToast.${row.id}'),
          content: Text('Unlocked: ${row.title}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listenWhen: (prev, next) =>
          next is ProfileLoaded &&
          next.overall.recentlyUnlocked.isNotEmpty,
      listener: (context, state) {
        if (state is ProfileLoaded) {
          _toastUnlocks(context, state.overall.recentlyUnlocked);
        }
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<ProfileBloc>();
        bloc.add(const ProfileRefreshRequested());
        // Wait for a non-loading state to land before releasing the
        // pull-to-refresh spinner.
        await bloc.stream
            .firstWhere((s) => s is! ProfileLoading);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(user: user),
            // Quick-stats strip pulls numbers from the Slice P2 bloc
            // when available; otherwise falls back to dashes (the
            // widget's placeholder state).
            BlocBuilder<ProfileBloc, ProfileState>(
              builder: (context, state) {
                if (state is ProfileLoaded) {
                  final s = state.overall.summary;
                  return QuickStatsStrip(
                    courses: s.coursesEnrolled,
                    lessons: s.lessonsCompleted,
                    streakDays: s.currentStreak,
                    accuracyPct: s.overallAccuracy == null
                        ? null
                        : s.overallAccuracy! * 100,
                  );
                }
                return const QuickStatsStrip();
              },
            ),
            const SizedBox(height: 8),

            // Slice P2 + P3 — progress + streak + achievements.
            BlocBuilder<ProfileBloc, ProfileState>(
              builder: (context, state) {
                if (state is ProfileLoading || state is ProfileInitial) {
                  return const ProgressOverviewCardSkeleton();
                }
                if (state is ProfileError) {
                  return _ProgressErrorStrip(
                    message: state.error.message,
                    onRetry: () => context
                        .read<ProfileBloc>()
                        .add(const ProfileLoadRequested()),
                  );
                }
                if (state is ProfileLoaded) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Slice P3 — streak card between quick-stats and GPA.
                      StreakCard(
                        currentStreak:
                            state.overall.summary.currentStreak,
                        longestStreak:
                            state.overall.summary.longestStreak,
                      ),
                      ProgressOverviewCard(
                        summary: state.overall.summary,
                      ),
                      for (final course in state.overall.perCourse)
                        EnrolledCourseCard(
                          summary: course,
                          progressRepo: progressRepo,
                        ),
                      // Slice P3 — achievement grid at the end of the
                      // progress section. Fetches its own data lazily.
                      AchievementGrid(progressRepo: progressRepo),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            _SectionCard(
              title: 'Account',
              children: [
                ListTile(
                  key: const Key('profile.account.editProfile'),
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit profile'),
                  onTap: () => EditProfileSheet.show(
                    context: context,
                    user: user,
                    meRepo: meRepo,
                  ),
                ),
                // Slice P5 — change password lives at a dedicated screen;
                // the old "coming soon" tile flips to an active entry.
                ListTile(
                  key: const Key('profile.account.password'),
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      GoRouter.of(context).push('/profile/security/password'),
                ),
                // Slice P7a — live MFA status + setup/disable entry.
                // Replaces the P1 "Coming soon" placeholder.
                MfaCard(meRepo: meRepo),
                // Slice P6 — sessions screen is a push target. The tile
                // was previously "Coming soon"; now it routes into the
                // `/profile/security/sessions` screen which renders the
                // full list backed by `GET /api/me/sessions`.
                ListTile(
                  key: const Key('profile.account.sessions'),
                  leading: const Icon(Icons.devices_other_outlined),
                  title: const Text('Active sessions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      GoRouter.of(context).push('/profile/security/sessions'),
                ),
              ],
            ),

            _SectionCard(
              title: 'Settings',
              children: [
                ListTile(
                  key: const Key('profile.settings.entry'),
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  subtitle: const Text(
                    'Appearance, playback, privacy, accessibility',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      GoRouter.of(context).push('/profile/settings'),
                ),
              ],
            ),

            if (user.role == UserRole.learner)
              _SectionCard(
                title: 'Designers',
                children: [
                  ListTile(
                    key: const Key('profile.applyDesigner'),
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('Apply to become a course designer'),
                    onTap: () =>
                        GoRouter.of(context).go('/designer-application'),
                  ),
                ],
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: OutlinedButton.icon(
                key: const Key('profile.logout'),
                onPressed: () =>
                    context.read<AuthBloc>().add(const LoggedOut()),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),

            // Slice P5 — destructive "Delete account" entry. Below
            // Logout in deliberate order: users scanning for "log out"
            // shouldn't accidentally tap delete. Styled with the error
            // colour for visual weight.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Builder(
                builder: (ctx) {
                  final error = Theme.of(ctx).colorScheme.error;
                  return ListTile(
                    key: const Key('profile.account.delete'),
                    leading: Icon(Icons.delete_outline, color: error),
                    title: Text(
                      'Delete account',
                      style: TextStyle(color: error),
                    ),
                    onTap: () =>
                        GoRouter.of(context).push('/profile/delete'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProgressErrorStrip extends StatelessWidget {
  const _ProgressErrorStrip({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        key: const Key('profile.progress.error'),
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Progress unavailable'),
          subtitle: Text(message),
          trailing: TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}
