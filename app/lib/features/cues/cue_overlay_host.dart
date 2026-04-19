import 'package:flutter/material.dart';

import '../../data/models/cue.dart';
import '../../data/repositories/attempt_repository.dart';
import '../player/cue_scheduler.dart';
import 'blanks_cue_widget.dart';
import 'matching_cue_widget.dart';
import 'mcq_cue_widget.dart';

/// Overlays the cue UI on top of a child (usually the video player).
///
/// Listens to `scheduler.activeCueNotifier`: when non-null, renders the
/// corresponding cue widget. On "Continue" (dismiss), the scheduler
/// advances past the cue and resumes playback.
class CueOverlayHost extends StatelessWidget {
  const CueOverlayHost({
    required this.scheduler,
    required this.attemptRepo,
    required this.child,
    super.key,
  });

  final CueScheduler scheduler;
  final AttemptRepository attemptRepo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ValueListenableBuilder<Cue?>(
          valueListenable: scheduler.activeCueNotifier,
          builder: (context, cue, _) {
            if (cue == null) return const SizedBox.shrink();
            return _buildCueWidget(cue);
          },
        ),
      ],
    );
  }

  Widget _buildCueWidget(Cue cue) {
    switch (cue.type) {
      case CueType.mcq:
        return McqCueWidget(
          key: ValueKey('cue.${cue.id}'),
          cue: cue,
          attemptRepo: attemptRepo,
          onDone: scheduler.resume,
        );
      case CueType.blanks:
        return BlanksCueWidget(
          key: ValueKey('cue.${cue.id}'),
          cue: cue,
          attemptRepo: attemptRepo,
          onDone: scheduler.resume,
        );
      case CueType.matching:
        return MatchingCueWidget(
          key: ValueKey('cue.${cue.id}'),
          cue: cue,
          attemptRepo: attemptRepo,
          onDone: scheduler.resume,
        );
      case CueType.voice:
        // The UI must never surface VOICE cues — the backend rejects
        // creation with 501. If one somehow reaches the client, render
        // a safe fallback so we don't crash; the learner can dismiss it.
        return _UnsupportedCueWidget(onDone: scheduler.resume);
    }
  }
}

class _UnsupportedCueWidget extends StatelessWidget {
  const _UnsupportedCueWidget({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This cue type is not yet supported.'),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: onDone, child: const Text('Skip')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
