import 'package:flutter/material.dart';

/// Four mini-tiles at the top of the profile — courses, lessons,
/// current streak, overall accuracy. Values come from the `ProfileBloc`
/// → `ProgressOverall.summary`, which calls `GET /api/me/progress`.
/// Nullable parameters are kept so the strip can render during the
/// initial loading state (before the first `ProfileLoaded` arrives) and
/// during error states, where it falls back to "—" placeholders.
class QuickStatsStrip extends StatelessWidget {
  const QuickStatsStrip({
    this.courses,
    this.lessons,
    this.streakDays,
    this.accuracyPct,
    super.key,
  });

  /// Null → render "—" placeholder (loading or error state).
  final int? courses;
  final int? lessons;
  final int? streakDays;
  final double? accuracyPct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              key: const Key('profile.stat.courses'),
              label: 'Courses',
              value: _renderInt(courses),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              key: const Key('profile.stat.lessons'),
              label: 'Lessons',
              value: _renderInt(lessons),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              key: const Key('profile.stat.streak'),
              label: 'Streak',
              value: streakDays == null ? '—' : '$streakDays d',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              key: const Key('profile.stat.accuracy'),
              label: 'Accuracy',
              value: accuracyPct == null
                  ? '—'
                  : '${accuracyPct!.toStringAsFixed(0)}%',
            ),
          ),
        ],
      ),
    );
  }

  static String _renderInt(int? n) => n == null ? '—' : '$n';
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
