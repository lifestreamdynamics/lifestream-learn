import 'package:flutter/material.dart';

import '../../data/models/cue.dart';
import '../../data/repositories/attempt_repository.dart';
import 'cue_overlay.dart';

/// Fill-in-the-blanks cue widget. Parses the `sentenceTemplate` around
/// its `{{N}}` placeholders, interleaves `Text` runs with per-blank
/// `TextField`s, and on submit POSTs the answers list to `/api/attempts`.
/// The server's `scoreJson.perBlank: List<bool>` drives the per-blank
/// red/green highlighting shown in the result banner.
class BlanksCueWidget extends StatefulWidget {
  const BlanksCueWidget({
    required this.cue,
    required this.attemptRepo,
    required this.onDone,
    this.onAnswered,
    super.key,
  });

  final Cue cue;
  final AttemptRepository attemptRepo;
  final VoidCallback onDone;

  /// See `McqCueWidget.onAnswered`. Fires once with server-graded
  /// correctness so the overlay host can ping analytics.
  final void Function(bool correct)? onAnswered;

  @override
  State<BlanksCueWidget> createState() => _BlanksCueWidgetState();
}

class _BlanksCueWidgetState extends State<BlanksCueWidget> {
  late final List<TextEditingController> _fields;
  late final List<_TemplateSegment> _segments;
  late final int _blankCount;
  bool _submitting = false;
  AttemptResult? _result;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final template =
        (widget.cue.payload['sentenceTemplate'] as String?) ?? '';
    _segments = parseTemplate(template);
    _blankCount =
        _segments.whereType<_BlankSegment>().map((s) => s.index).toSet().length;
    _fields = List.generate(_blankCount, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final answers = _fields.map((c) => c.text).toList(growable: false);
      final result = await widget.attemptRepo.submit(
        cueId: widget.cue.id,
        response: <String, dynamic>{'answers': answers},
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = result;
      });
      widget.onAnswered?.call(result.correct);
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
    final perBlank = result?.scoreJson?['perBlank'] as List<dynamic>? ?? [];
    return CueOverlay(
      cueType: widget.cue.type,
      submitting: _submitting,
      onSubmit: _submit,
      onContinue: widget.onDone,
      resultBanner: result == null ? null : _buildResultBanner(result),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            key: const Key('blanks.template'),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final seg in _segments) _renderSegment(seg, perBlank),
            ],
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(
              _submitError!,
              key: const Key('blanks.error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderSegment(_TemplateSegment seg, List<dynamic> perBlank) {
    if (seg is _TextSegment) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(seg.text),
      );
    }
    final bSeg = seg as _BlankSegment;
    final result = _result;
    Color? borderColor;
    if (result != null && bSeg.index < perBlank.length) {
      final ok = perBlank[bSeg.index] == true;
      borderColor = ok ? Colors.green : Colors.red;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SizedBox(
        width: 120,
        child: TextField(
          key: Key('blanks.field.${bSeg.index}'),
          controller: _fields[bSeg.index],
          enabled: result == null && !_submitting,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            border: OutlineInputBorder(
              borderSide: borderColor != null
                  ? BorderSide(color: borderColor, width: 2)
                  : const BorderSide(),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: borderColor != null
                  ? BorderSide(color: borderColor, width: 2)
                  : const BorderSide(),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: borderColor != null
                  ? BorderSide(color: borderColor, width: 2)
                  : const BorderSide(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner(AttemptResult result) {
    return Column(
      key: const Key('blanks.result'),
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
              result.correct ? 'Correct!' : 'Some blanks are wrong.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

/// Parsed segment of a BLANKS sentenceTemplate.
sealed class _TemplateSegment {
  const _TemplateSegment();
}

class _TextSegment extends _TemplateSegment {
  const _TextSegment(this.text);
  final String text;
}

class _BlankSegment extends _TemplateSegment {
  const _BlankSegment(this.index);
  final int index;
}

/// Parse a sentenceTemplate into an interleaved list of `text | blank`
/// segments. Pure function — exposed for unit tests via
/// [debugParseTemplate] + [describeSegment]. Private element types keep
/// the parsed nodes internal so the widget can evolve the shape without
/// a breaking API change.
// ignore: library_private_types_in_public_api
List<_TemplateSegment> parseTemplate(String template) {
  final re = RegExp(r'\{\{(\d+)\}\}');
  final out = <_TemplateSegment>[];
  var cursor = 0;
  for (final m in re.allMatches(template)) {
    if (m.start > cursor) {
      out.add(_TextSegment(template.substring(cursor, m.start)));
    }
    out.add(_BlankSegment(int.parse(m.group(1)!)));
    cursor = m.end;
  }
  if (cursor < template.length) {
    out.add(_TextSegment(template.substring(cursor)));
  }
  return out;
}

/// Test-only description of a parsed segment. Widget tests import
/// `describeSegment` and `debugParseTemplate` to assert on the parser
/// output without touching the private _TemplateSegment types.
@visibleForTesting
({String? text, int? blankIndex}) describeSegment(Object seg) {
  if (seg is _TextSegment) return (text: seg.text, blankIndex: null);
  if (seg is _BlankSegment) return (text: null, blankIndex: seg.index);
  throw ArgumentError('Unknown segment type');
}

@visibleForTesting
List<Object> debugParseTemplate(String template) =>
    parseTemplate(template).cast<Object>();
