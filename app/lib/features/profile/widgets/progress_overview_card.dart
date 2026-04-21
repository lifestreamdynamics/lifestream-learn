import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/utils/duration_formatters.dart';
import '../../../data/models/progress.dart';

/// Slice P2 — headline "progress dashboard" card at the top of the
/// profile screen. Shows the server-computed GPA letter + accuracy, plus
/// a strip of counters (courses, lessons completed, cues attempted,
/// watch time). Grade letter and numeric accuracy always appear
/// together — colour is never the sole signal (a11y rule from the plan).
class ProgressOverviewCard extends StatelessWidget {
  const ProgressOverviewCard({
    required this.summary,
    super.key,
  });

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Empty-state copy triggers when the user has no enrollments OR
    // hasn't attempted a single cue yet — even one enrolled course with
    // zero attempts still looks empty on the GPA card, so we'd rather
    // prompt them to start than show a stark "--" letter grade.
    final isEmpty = summary.coursesEnrolled == 0 ||
        summary.totalCuesAttempted == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        key: const Key('profile.progress.overview'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isEmpty
              ? _EmptyState(theme: theme)
              : _FilledCard(summary: summary, theme: theme),
        ),
      ),
    );
  }
}

/// Skeletonised placeholder for the overview card. Use on the loading
/// path so the card has the same footprint as the loaded state.
class ProgressOverviewCardSkeleton extends StatelessWidget {
  const ProgressOverviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // Skeletonizer replaces the leaves of the tree with animated shimmer
    // bands — we just give it a sensible structure to mirror.
    return const Skeletonizer(
      enabled: true,
      child: ProgressOverviewCard(
        summary: ProgressSummary(
          coursesEnrolled: 3,
          lessonsCompleted: 7,
          totalCuesAttempted: 42,
          totalCuesCorrect: 35,
          overallAccuracy: 0.85,
          overallGrade: Grade.b,
          totalWatchTimeMs: 3600000,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('profile.progress.overview.empty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_outlined,
                color: theme.colorScheme.primary, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your progress will appear here',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Complete your first lesson to see progress here.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FilledCard extends StatelessWidget {
  const _FilledCard({required this.summary, required this.theme});
  final ProgressSummary summary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final grade = summary.overallGrade;
    final accuracyPct = summary.overallAccuracy != null
        ? '${(summary.overallAccuracy! * 100).round()}%'
        : null;
    final accessibleLabel = grade != null && accuracyPct != null
        ? 'Overall grade ${grade.label}, $accuracyPct accuracy'
        : 'Overall grade unavailable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: accessibleLabel,
          child: Row(
            children: [
              _GradeBadge(grade: grade),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall grade',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accuracyPct ?? '—',
                      key: const Key('profile.progress.overview.accuracy'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _StatsRow(summary: summary, theme: theme),
      ],
    );
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade});
  final Grade? grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = grade?.label ?? '—';
    return Container(
      key: const Key('profile.progress.overview.grade'),
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: theme.textTheme.displaySmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary, required this.theme});
  final ProgressSummary summary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          keyValue: const Key('profile.progress.overview.courses'),
          label: 'Courses',
          value: summary.coursesEnrolled.toString(),
          theme: theme,
        ),
        _StatTile(
          keyValue: const Key('profile.progress.overview.lessons'),
          label: 'Lessons',
          value: summary.lessonsCompleted.toString(),
          theme: theme,
        ),
        _StatTile(
          keyValue: const Key('profile.progress.overview.cues'),
          label: 'Cues',
          value: summary.totalCuesAttempted.toString(),
          theme: theme,
        ),
        _StatTile(
          keyValue: const Key('profile.progress.overview.watchTime'),
          label: 'Watch time',
          value: formatWatchTimeMs(summary.totalWatchTimeMs),
          theme: theme,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.keyValue,
    required this.label,
    required this.value,
    required this.theme,
  });

  final Key keyValue;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        key: keyValue,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
