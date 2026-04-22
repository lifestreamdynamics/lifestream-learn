import 'package:flutter/material.dart';

import '../../data/models/cue.dart';

/// Shared submission state machine for cue widgets.
///
/// MCQ / BLANKS / MATCHING all follow the same shape: (1) the learner
/// builds a response in local state, (2) taps submit, (3) the widget
/// POSTs to `/api/attempts` via [AttemptRepository], (4) the server's
/// `{correct, explanation}` reply drives a result banner. This mixin
/// owns the `_submitting / _result / _submitError` trio plus the
/// post-await `!mounted` guard that every cue widget needs, and
/// provides a parameterisable result-banner builder.
///
/// Widgets mix in via `with CueSubmissionMixin<MyCueWidget>` on their
/// `State<T>` class. The grading contract (`correct` comes from the
/// server, never computed on the client) is unchanged — the mixin is
/// mechanical plumbing only.
mixin CueSubmissionMixin<T extends StatefulWidget> on State<T> {
  /// True while a submit() is in flight.
  bool get submitting => _submitting;
  bool _submitting = false;

  /// Non-null once the server has graded the attempt.
  AttemptResult? get result => _result;
  AttemptResult? _result;

  /// Human-readable error captured from the last failed submit(). Null
  /// in success and pre-submit states.
  String? get submitError => _submitError;
  String? _submitError;

  /// Runs an attempt submission through the shared state machine.
  ///
  /// [submit] should perform the `attemptRepo.submit(...)` call and
  /// return the server's [AttemptResult]. [onAnswered] fires once on
  /// success with the server-graded `correct` flag — the cue overlay
  /// host uses this to emit analytics.
  Future<void> runSubmission(
    Future<AttemptResult> Function() submit, {
    void Function(bool correct)? onAnswered,
  }) async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final res = await submit();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = res;
      });
      onAnswered?.call(res.correct);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.toString();
      });
    }
  }

  /// Builds the shared result banner used by all three cue types.
  ///
  /// [correctText] / [incorrectText] are the per-type headline strings
  /// (e.g. "Correct!" vs "Some blanks are wrong."). [trailing] is an
  /// optional per-type addendum — BLANKS passes nothing, MCQ passes the
  /// server `explanation`, MATCHING passes "N / M pairs matched."
  Widget buildResultBanner({
    required AttemptResult result,
    required String correctText,
    required String incorrectText,
    Widget? trailing,
    Key? key,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              result.correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: result.correct ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              result.correct ? correctText : incorrectText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
