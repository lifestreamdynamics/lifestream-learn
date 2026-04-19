import 'package:flutter/material.dart';

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
    super.key,
  });

  final Cue cue;
  final AttemptRepository attemptRepo;
  final VoidCallback onDone;

  @override
  State<McqCueWidget> createState() => _McqCueWidgetState();
}

class _McqCueWidgetState extends State<McqCueWidget> {
  int? _selected;
  bool _submitting = false;
  AttemptResult? _result;
  String? _submitError;

  String get _question => (widget.cue.payload['question'] as String?) ?? '';
  List<String> get _choices =>
      ((widget.cue.payload['choices'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);

  Future<void> _submit() async {
    final sel = _selected;
    if (sel == null) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await widget.attemptRepo.submit(
        cueId: widget.cue.id,
        response: <String, dynamic>{'choiceIndex': sel},
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    final result = _result;
    return CueOverlay(
      cueType: widget.cue.type,
      submitEnabled: _selected != null,
      submitting: _submitting,
      onSubmit: _submit,
      onContinue: widget.onDone,
      resultBanner: result == null ? null : _buildResultBanner(result),
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
              onChanged: result == null && !_submitting
                  ? (v) => setState(() => _selected = v)
                  : null,
              title: Text(choices[i]),
            ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(
              _submitError!,
              key: const Key('mcq.error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultBanner(AttemptResult result) {
    return Column(
      key: const Key('mcq.result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              result.correct ? Icons.check_circle : Icons.cancel,
              color: result.correct ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              result.correct ? 'Correct!' : 'Incorrect.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (result.explanation != null && result.explanation!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(result.explanation!),
        ],
      ],
    );
  }
}
