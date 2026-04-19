import 'package:flutter/material.dart';

import '../../core/platform/flag_secure.dart';
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
///
/// Also handles two cross-cutting concerns around cue presentation:
/// 1. **FLAG_SECURE** — enabled while a cue overlay is mounted so the
///    quiz answer frames can't be screenshot or screen-recorded, and
///    cleared on dismiss so non-sensitive screens stay capturable.
/// 2. **Analytics** — wires each cue widget's `onAnswered` callback to
///    `scheduler.reportAnswered` so the buffer gets a structural
///    `cue_answered` event (payload: `{cueType, correct}` only). The
///    `cue_shown` event is emitted by the scheduler itself when the
///    notifier flips non-null.
class CueOverlayHost extends StatefulWidget {
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
  State<CueOverlayHost> createState() => _CueOverlayHostState();
}

class _CueOverlayHostState extends State<CueOverlayHost> {
  Cue? _lastCue;

  @override
  void initState() {
    super.initState();
    widget.scheduler.activeCueNotifier.addListener(_onCueChange);
  }

  @override
  void dispose() {
    widget.scheduler.activeCueNotifier.removeListener(_onCueChange);
    // Safety net — if the host is torn down mid-overlay, don't leave
    // the flag set on the window.
    if (_lastCue != null) {
      FlagSecure.disable();
    }
    super.dispose();
  }

  void _onCueChange() {
    final cue = widget.scheduler.activeCueNotifier.value;
    // Transition null → non-null: enable. non-null → null: disable.
    if (cue != null && _lastCue == null) {
      FlagSecure.enable();
    } else if (cue == null && _lastCue != null) {
      FlagSecure.disable();
    }
    _lastCue = cue;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        ValueListenableBuilder<Cue?>(
          valueListenable: widget.scheduler.activeCueNotifier,
          builder: (context, cue, _) {
            if (cue == null) return const SizedBox.shrink();
            return _buildCueWidget(cue);
          },
        ),
      ],
    );
  }

  void _reportAnswered(Cue cue, bool correct) {
    widget.scheduler.reportAnswered(
      cueId: cue.id,
      cueType: cue.type,
      correct: correct,
    );
  }

  Widget _buildCueWidget(Cue cue) {
    switch (cue.type) {
      case CueType.mcq:
        return McqCueWidget(
          key: ValueKey('cue.${cue.id}'),
          cue: cue,
          attemptRepo: widget.attemptRepo,
          onDone: widget.scheduler.resume,
          onAnswered: (correct) => _reportAnswered(cue, correct),
        );
      case CueType.blanks:
        return BlanksCueWidget(
          key: ValueKey('cue.${cue.id}'),
          cue: cue,
          attemptRepo: widget.attemptRepo,
          onDone: widget.scheduler.resume,
          onAnswered: (correct) => _reportAnswered(cue, correct),
        );
      case CueType.matching:
        return MatchingCueWidget(
          key: ValueKey('cue.${cue.id}'),
          cue: cue,
          attemptRepo: widget.attemptRepo,
          onDone: widget.scheduler.resume,
          onAnswered: (correct) => _reportAnswered(cue, correct),
        );
      case CueType.voice:
        // The UI must never surface VOICE cues — the backend rejects
        // creation with 501. If one somehow reaches the client, render
        // a safe fallback so we don't crash; the learner can dismiss it.
        return _UnsupportedCueWidget(onDone: widget.scheduler.resume);
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
