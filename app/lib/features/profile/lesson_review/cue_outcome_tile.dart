import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/duration_formatters.dart';
import '../../../data/models/cue.dart';
import '../../../data/models/progress.dart';

/// Slice P2 — per-cue tile on the lesson-review screen.
///
/// Semantics:
/// - The `attempted=false` branch MUST NOT render `correctAnswerSummary`.
///   The server already enforces this (null-out unattempted cues); this
///   widget belt-and-braces with an explicit null check so a future
///   regression wouldn't leak the answer.
/// - A "Watch from MM:SS" chip deep-links back to the player at
///   `atMs` so the learner can re-watch the context around a missed cue.
class CueOutcomeTile extends StatelessWidget {
  const CueOutcomeTile({
    required this.outcome,
    required this.videoId,
    super.key,
  });

  final CueOutcome outcome;
  final String videoId;

  IconData get _cueIcon {
    switch (outcome.type) {
      case CueType.mcq:
        return Icons.help_outline;
      case CueType.blanks:
        return Icons.edit_outlined;
      case CueType.matching:
        return Icons.extension_outlined;
      case CueType.voice:
        return Icons.mic_none_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileKey = Key('review.cue.${outcome.cueId}');
    // Belt-and-braces null check. The server already returns null for
    // unattempted cues, but we also gate on `outcome.attempted` here so
    // a UI regression can't leak through. `outcome.correctAnswerSummary`
    // should never be non-null when `!outcome.attempted`.
    final canShowCorrect =
        outcome.attempted && outcome.correctAnswerSummary != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        key: tileKey,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_cueIcon, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      outcome.prompt,
                      style: theme.textTheme.titleSmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusIcon(outcome: outcome),
                ],
              ),
              const SizedBox(height: 12),
              if (!outcome.attempted)
                Text(
                  'Not attempted yet',
                  key: Key('review.cue.${outcome.cueId}.unattempted'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else ...[
                if (outcome.yourAnswerSummary != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Your answer: ${outcome.yourAnswerSummary}',
                      key: Key('review.cue.${outcome.cueId}.yourAnswer'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (canShowCorrect)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Correct: ${outcome.correctAnswerSummary}',
                      key: Key('review.cue.${outcome.cueId}.correctAnswer'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                if (outcome.explanation != null &&
                    outcome.explanation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      outcome.explanation!,
                      key: Key('review.cue.${outcome.cueId}.explanation'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ActionChip(
                  key: Key('review.cue.${outcome.cueId}.watchFrom'),
                  avatar: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text('Watch from ${formatDurationMs(outcome.atMs)}'),
                  onPressed: () => context.push(
                    '/videos/$videoId/watch?t=${outcome.atMs}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.outcome});
  final CueOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!outcome.attempted) {
      return Semantics(
        liveRegion: true,
        label: 'Not attempted',
        child: Icon(
          Icons.radio_button_unchecked_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final isCorrect = outcome.correct == true;
    // Icon choice always pairs with per-tile text ("Your answer:
    // ..."/"Correct: ...") so colour is never the sole signal.
    // liveRegion: true ensures TalkBack announces the result when this
    // widget first appears after the learner submits a cue response.
    return Semantics(
      liveRegion: true,
      label: isCorrect ? 'Correct' : 'Incorrect',
      child: Icon(
        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: isCorrect
            ? theme.colorScheme.primary
            : theme.colorScheme.error,
      ),
    );
  }
}
