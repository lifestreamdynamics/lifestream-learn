import 'package:flutter/material.dart';

import '../../data/models/cue.dart';

/// Shared chrome for a cue overlay: dimmed backdrop + centered card with
/// an icon+label title bar, a caller-supplied body, and a Submit/Continue
/// button bar. The cue-specific widgets (`McqCueWidget`, etc.) render
/// the body and pass `onSubmit`/`onContinue` callbacks.
///
/// States:
/// - [submitting] = true → Submit button becomes a spinner, Continue is
///   disabled. Overlay swallows pointer events during submission.
/// - [result] != null → Submit is replaced by Continue, and [resultBanner]
///   (caller-rendered "Correct!"/"Incorrect." + explanation) is stacked
///   above the button.
class CueOverlay extends StatelessWidget {
  const CueOverlay({
    required this.cueType,
    required this.body,
    required this.onSubmit,
    required this.onContinue,
    this.submitEnabled = true,
    this.submitting = false,
    this.resultBanner,
    super.key,
  });

  final CueType cueType;
  final Widget body;

  /// When [resultBanner] is null, this is the Submit action. When a
  /// result banner is showing, the button becomes Continue (which calls
  /// [onContinue]), so this callback is only invoked in the pre-result
  /// phase.
  final VoidCallback onSubmit;

  /// Called when the learner dismisses the overlay after grading.
  final VoidCallback onContinue;

  final bool submitEnabled;
  final bool submitting;

  /// If non-null, the overlay is in the "graded" state: the caller-built
  /// banner is shown and the button flips to Continue.
  final Widget? resultBanner;

  @override
  Widget build(BuildContext context) {
    final showingResult = resultBanner != null;
    final theme = Theme.of(context);
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(_iconFor(cueType)),
                        const SizedBox(width: 8),
                        Text(
                          _labelFor(cueType),
                          key: const Key('cue.overlay.label'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    body,
                    if (resultBanner != null) ...[
                      const SizedBox(height: 12),
                      resultBanner!,
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (submitting)
                          const SizedBox(
                            key: Key('cue.overlay.submitting'),
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          ElevatedButton(
                            key: Key(
                              showingResult
                                  ? 'cue.overlay.continue'
                                  : 'cue.overlay.submit',
                            ),
                            onPressed: showingResult
                                ? onContinue
                                : (submitEnabled ? onSubmit : null),
                            child: Text(showingResult ? 'Continue' : 'Submit'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(CueType t) {
    switch (t) {
      case CueType.mcq:
        return Icons.quiz;
      case CueType.blanks:
        return Icons.edit_note;
      case CueType.matching:
        return Icons.compare_arrows;
      case CueType.voice:
        return Icons.mic;
    }
  }

  static String _labelFor(CueType t) {
    switch (t) {
      case CueType.mcq:
        return 'Multiple choice';
      case CueType.blanks:
        return 'Fill in the blanks';
      case CueType.matching:
        return 'Match the pairs';
      case CueType.voice:
        return 'Voice prompt';
    }
  }
}
