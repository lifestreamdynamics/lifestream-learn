import 'package:flutter/material.dart';

/// Slice P3 — small card showing the learner's current + longest
/// streaks. Slots into the profile screen between the quick-stats
/// strip and the progress overview card. Empty state prompts a
/// not-yet-streaking learner; a live streak shows the flame icon in
/// primary colour + a subtitle with the longest streak.
class StreakCard extends StatelessWidget {
  const StreakCard({
    required this.currentStreak,
    required this.longestStreak,
    super.key,
  });

  final int currentStreak;
  final int longestStreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onStreak = currentStreak > 0;
    final iconColor = onStreak
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final title = onStreak
        ? '$currentStreak day${currentStreak == 1 ? '' : 's'} streak'
        : 'Start a streak today';
    final subtitle = onStreak
        ? 'Longest: $longestStreak day${longestStreak == 1 ? '' : 's'}'
        : 'Watch a lesson or answer a cue to begin.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        key: const Key('profile.streak'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: iconColor,
                size: 32,
                key: const Key('profile.streak.icon'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      key: const Key('profile.streak.title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      key: const Key('profile.streak.subtitle'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
