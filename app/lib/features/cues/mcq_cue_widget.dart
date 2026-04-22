import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/widgets/cue_submission_mixin.dart';
import '../../data/models/cue.dart';
import '../../data/repositories/attempt_repository.dart';
import 'cue_overlay.dart';

/// Multiple-choice cue widget. Renders the question + up to 4 radio
/// choices from `cue.payload`, collects the learner's selection, and on
/// submit POSTs to `/api/attempts`. The server's `{correct, explanation}`
/// reply drives the post-submission result banner.
///
/// **Security invariant:** the UI never renders `payload.answerIndex` —
/// it only forwards `choiceIndex` to the server and consumes the server's
/// graded reply. The backend grader echoes the learner's `selected` back
/// in `scoreJson.selected` for analytics; that's not the correct answer.
class McqCueWidget extends StatefulWidget {
  const McqCueWidget({
    required this.cue,
    required this.attemptRepo,
    required this.onDone,
    this.onAnswered,
    super.key,
  });

  final Cue cue;
  final AttemptRepository attemptRepo;
  final VoidCallback onDone;

  /// Optional telemetry hook — fires once per cue, with the server-
  /// graded correctness. The overlay host wires this to
  /// `CueScheduler.reportAnswered` so analytics get an event per
  /// completed attempt. Never exposed to the grading path.
  final void Function(bool correct)? onAnswered;

  @override
  State<McqCueWidget> createState() => _McqCueWidgetState();
}

class _McqCueWidgetState extends State<McqCueWidget>
    with CueSubmissionMixin<McqCueWidget> {
  int? _selected;

  String get _question => (widget.cue.payload['question'] as String?) ?? '';
  List<String> get _choices =>
      ((widget.cue.payload['choices'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);

  Future<void> _submit() async {
    final sel = _selected;
    if (sel == null) return;
    Haptics.light();
    await runSubmission(
      () => widget.attemptRepo.submit(
        cueId: widget.cue.id,
        response: <String, dynamic>{'choiceIndex': sel},
      ),
      onAnswered: widget.onAnswered,
    );
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    final res = result;
    final explanation = res?.explanation;
    return CueOverlay(
      cueType: widget.cue.type,
      submitEnabled: _selected != null,
      submitting: submitting,
      onSubmit: _submit,
      onContinue: widget.onDone,
      resultBanner: res == null
          ? null
          : buildResultBanner(
              result: res,
              correctText: 'Correct!',
              incorrectText: 'Incorrect.',
              key: const Key('mcq.result'),
              trailing: (explanation != null && explanation.isNotEmpty)
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(explanation),
                    )
                  : null,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _question,
            key: const Key('mcq.question'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < choices.length; i++)
            // ignore: deprecated_member_use
            RadioListTile<int>(
              key: Key('mcq.choice.$i'),
              value: i,
              // ignore: deprecated_member_use
              groupValue: _selected,
              // ignore: deprecated_member_use
              onChanged: res == null && !submitting
                  ? (v) => setState(() => _selected = v)
                  : null,
              title: Text(choices[i]),
            ),
          if (submitError != null) ...[
            const SizedBox(height: 8),
            Text(
              submitError!,
              key: const Key('mcq.error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
