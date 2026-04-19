import 'package:flutter/material.dart';

import '../../data/models/cue.dart';
import '../../data/repositories/attempt_repository.dart';
import 'cue_overlay.dart';

/// Matching cue widget. Two columns of `Card`s (left + right). Tap a
/// left card to select it, then tap a right card to create a pair. Tap
/// an already-paired card to unpair. Submit posts
/// `{userPairs: [[l, r], ...]}` to the server.
///
/// Bipartite-matching invariant (1:1): tapping a left that's already
/// paired replaces the pair; tapping a right that's already paired
/// replaces the pair. Duplicate pairs are impossible from the UI.
class MatchingCueWidget extends StatefulWidget {
  const MatchingCueWidget({
    required this.cue,
    required this.attemptRepo,
    required this.onDone,
    super.key,
  });

  final Cue cue;
  final AttemptRepository attemptRepo;
  final VoidCallback onDone;

  @override
  State<MatchingCueWidget> createState() => _MatchingCueWidgetState();
}

class _MatchingCueWidgetState extends State<MatchingCueWidget> {
  /// Map of left-index → right-index. The 1:1 invariant is enforced by
  /// construction: a left can only map to one right (Map), and we
  /// explicitly evict any prior owner of a selected right.
  final Map<int, int> _pairs = <int, int>{};
  int? _selectedLeft;

  bool _submitting = false;
  AttemptResult? _result;
  String? _submitError;

  List<String> get _left => ((widget.cue.payload['left'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList(growable: false);
  List<String> get _right =>
      ((widget.cue.payload['right'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);
  String get _prompt => (widget.cue.payload['prompt'] as String?) ?? '';

  bool get _hasPairs => _pairs.isNotEmpty;

  void _onLeftTap(int i) {
    if (_result != null || _submitting) return;
    setState(() {
      // Tapping a left card that already has a pair: unpair + select.
      if (_pairs.containsKey(i)) {
        _pairs.remove(i);
        _selectedLeft = i;
      } else if (_selectedLeft == i) {
        _selectedLeft = null;
      } else {
        _selectedLeft = i;
      }
    });
  }

  void _onRightTap(int j) {
    if (_result != null || _submitting) return;
    // Tapping a right card that's already paired unpairs it (regardless
    // of whether we have a left selected).
    final owner =
        _pairs.entries.firstWhere((e) => e.value == j, orElse: () => MapEntry(-1, -1));
    if (owner.key >= 0) {
      setState(() {
        _pairs.remove(owner.key);
      });
      return;
    }
    final left = _selectedLeft;
    if (left == null) return;
    setState(() {
      _pairs[left] = j;
      _selectedLeft = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final userPairs = _pairs.entries
          .map((e) => <int>[e.key, e.value])
          .toList(growable: false);
      final result = await widget.attemptRepo.submit(
        cueId: widget.cue.id,
        response: <String, dynamic>{'userPairs': userPairs},
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
    final result = _result;
    return CueOverlay(
      cueType: widget.cue.type,
      submitEnabled: _hasPairs,
      submitting: _submitting,
      onSubmit: _submit,
      onContinue: widget.onDone,
      resultBanner: result == null ? null : _buildResultBanner(result),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _prompt,
            key: const Key('matching.prompt'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < _left.length; i++)
                      _buildCard(
                        key: Key('matching.left.$i'),
                        text: _left[i],
                        selected: _selectedLeft == i,
                        paired: _pairs.containsKey(i),
                        onTap: () => _onLeftTap(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (var j = 0; j < _right.length; j++)
                      _buildCard(
                        key: Key('matching.right.$j'),
                        text: _right[j],
                        selected: false,
                        paired: _pairs.values.contains(j),
                        onTap: () => _onRightTap(j),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(
              _submitError!,
              key: const Key('matching.error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({
    required Key key,
    required String text,
    required bool selected,
    required bool paired,
    required VoidCallback onTap,
  }) {
    final Color? bg;
    if (selected) {
      bg = Colors.blue.withValues(alpha: 0.25);
    } else if (paired) {
      bg = Colors.green.withValues(alpha: 0.15);
    } else {
      bg = null;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        key: key,
        color: bg,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner(AttemptResult result) {
    final correctPairs = result.scoreJson?['correctPairs'];
    final totalPairs = result.scoreJson?['totalPairs'];
    return Column(
      key: const Key('matching.result'),
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
              result.correct ? 'Correct!' : 'Not quite.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (correctPairs != null && totalPairs != null) ...[
          const SizedBox(height: 4),
          Text('$correctPairs / $totalPairs pairs matched.'),
        ],
      ],
    );
  }
}
