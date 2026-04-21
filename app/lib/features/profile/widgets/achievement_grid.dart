import 'package:flutter/material.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/models/achievement.dart';
import '../../../data/repositories/progress_repository.dart';

/// Slice P3 — achievement grid placed below the per-course cards on
/// the profile screen. Pulls `GET /api/me/achievements` lazily on first
/// build and caches the response in widget state for the lifetime of
/// the profile screen. Unlocked achievements render in primary colour;
/// locked ones render greyed. Tapping any tile opens a bottom sheet
/// with the full description and unlock timestamp (if applicable).
///
/// Icon resolution: the server sends an `iconKey` string (e.g.
/// `"local_fire_department"`). We map a short hard-coded list here —
/// tree-shake-friendly (only the icons we reference stay in the bundle)
/// and offline-safe (no network fetch for graphics).
class AchievementGrid extends StatefulWidget {
  const AchievementGrid({
    required this.progressRepo,
    super.key,
  });

  final ProgressRepository progressRepo;

  @override
  State<AchievementGrid> createState() => _AchievementGridState();
}

class _AchievementGridState extends State<AchievementGrid> {
  AchievementsResponse? _data;
  ApiException? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.progressRepo.fetchAchievements();
      if (!mounted) return;
      setState(() {
        _data = r;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        key: const Key('profile.achievements'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Achievements',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: _buildBody(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final err = _error;
    if (err != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              err.message,
              key: const Key('profile.achievements.error'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                _load();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final data = _data;
    if (data == null || (data.unlocked.isEmpty && data.locked.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No achievements yet.'),
      );
    }
    // Unlocked first, then locked — both in catalog order.
    final all = [
      ...data.unlocked.map((a) => _GridEntry(a, unlocked: true)),
      ...data.locked.map((a) => _GridEntry(a, unlocked: false)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: all.length,
      itemBuilder: (context, i) {
        final e = all[i];
        final unlockedAt = data.unlockedAtByAchievementId[e.achievement.id];
        return _AchievementTile(
          achievement: e.achievement,
          unlocked: e.unlocked,
          unlockedAt: unlockedAt,
        );
      },
    );
  }
}

class _GridEntry {
  const _GridEntry(this.achievement, {required this.unlocked});
  final Achievement achievement;
  final bool unlocked;
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
    required this.unlockedAt,
  });

  final Achievement achievement;
  final bool unlocked;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = unlocked
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    final bg = unlocked
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
        : theme.colorScheme.surfaceContainerHighest;

    return InkWell(
      key: Key('profile.achievement.${achievement.id}'),
      onTap: () => _openDetailSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconForKey(achievement.iconKey),
              color: colour,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colour,
                fontWeight: unlocked ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final iconColour = unlocked
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      iconForKey(achievement.iconKey),
                      color: iconColour,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  achievement.description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (unlocked && unlockedAt != null)
                  Text(
                    'Unlocked ${_formatDate(unlockedAt!)}',
                    key: const Key('profile.achievement.unlockedAt'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    'Locked — keep going to earn this one.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    // Local-time ISO date (no time-of-day) — intentionally coarse so
    // the UX doesn't drift into "earned at 03:14:59".
    final local = d.toLocal();
    final yy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yy-$mm-$dd';
  }
}

/// Map the server's iconKey string to a Material [IconData]. A small
/// hard-coded table rather than reflection — tree-shakes cleanly and
/// fails loudly (`Icons.emoji_events` fallback) when the backend
/// introduces an icon we haven't wired yet.
IconData iconForKey(String key) {
  switch (key) {
    case 'school':
      return Icons.school;
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'whatshot':
      return Icons.whatshot;
    case 'emoji_events':
      return Icons.emoji_events;
    case 'verified':
      return Icons.verified;
    case 'workspace_premium':
      return Icons.workspace_premium;
    case 'military_tech':
      return Icons.military_tech;
    case 'radio_button_checked':
      return Icons.radio_button_checked;
    case 'extension':
      return Icons.extension;
    case 'edit_note':
      return Icons.edit_note;
    default:
      return Icons.emoji_events;
  }
}
