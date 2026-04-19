import 'package:flutter/material.dart';

import '../../data/models/cue.dart';
import 'cue_validators.dart';

/// Result returned from the cue-form bottom sheet when the designer
/// submits. The enclosing `VideoEditorScreen` turns this into either a
/// `CueRepository.create` or `.update` call.
class CueFormResult {
  const CueFormResult({
    required this.type,
    required this.payload,
    required this.pause,
  });
  final CueType type;
  final Map<String, dynamic> payload;
  final bool pause;
}

/// Bottom-sheet form for creating or editing a cue. Handles all three
/// supported cue types (MCQ, BLANKS, MATCHING). VOICE is deliberately
/// absent from the picker — see CLAUDE.md / ADR 0004.
///
/// [existing] seeds the form when editing an existing cue.
class CueFormSheet extends StatefulWidget {
  const CueFormSheet({this.existing, super.key});

  final Cue? existing;

  @override
  State<CueFormSheet> createState() => _CueFormSheetState();
}

class _CueFormSheetState extends State<CueFormSheet> {
  late CueType _type;
  late bool _pause;

  // MCQ state
  final _mcqQuestion = TextEditingController();
  final _mcqExplanation = TextEditingController();
  final List<TextEditingController> _mcqChoices = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _mcqAnswer = 0;

  // BLANKS state
  final _blanksTemplate = TextEditingController();
  final List<List<TextEditingController>> _blanksAccept = [
    [TextEditingController()],
  ];
  final List<bool> _blanksCaseSensitive = [false];

  // MATCHING state
  final _matchingPrompt = TextEditingController();
  final List<TextEditingController> _matchingLeft = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _matchingRight = [
    TextEditingController(),
    TextEditingController(),
  ];
  final Map<int, int> _matchingPairs = {};
  int? _selectedLeft;

  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? CueType.mcq;
    _pause = existing?.pause ?? true;
    if (existing != null) {
      _seedFromExisting(existing);
    }
  }

  void _seedFromExisting(Cue cue) {
    final p = cue.payload;
    switch (cue.type) {
      case CueType.mcq:
        _mcqQuestion.text = (p['question'] as String?) ?? '';
        _mcqExplanation.text = (p['explanation'] as String?) ?? '';
        final choices = (p['choices'] as List?) ?? const [];
        _mcqChoices
          ..clear()
          ..addAll(choices.map((c) => TextEditingController(text: '$c')));
        if (_mcqChoices.length < 2) {
          while (_mcqChoices.length < 2) {
            _mcqChoices.add(TextEditingController());
          }
        }
        _mcqAnswer = (p['answerIndex'] as int?) ?? 0;
        break;
      case CueType.blanks:
        _blanksTemplate.text = (p['sentenceTemplate'] as String?) ?? '';
        final blanks = (p['blanks'] as List?) ?? const [];
        _blanksAccept.clear();
        _blanksCaseSensitive.clear();
        for (final b in blanks) {
          final m = b as Map<String, dynamic>;
          final accept = (m['accept'] as List?) ?? const [];
          _blanksAccept.add(
            accept.map((a) => TextEditingController(text: '$a')).toList(),
          );
          _blanksCaseSensitive.add((m['caseSensitive'] as bool?) ?? false);
        }
        if (_blanksAccept.isEmpty) {
          _blanksAccept.add([TextEditingController()]);
          _blanksCaseSensitive.add(false);
        }
        break;
      case CueType.matching:
        _matchingPrompt.text = (p['prompt'] as String?) ?? '';
        final left = (p['left'] as List?) ?? const [];
        final right = (p['right'] as List?) ?? const [];
        _matchingLeft
          ..clear()
          ..addAll(left.map((e) => TextEditingController(text: '$e')));
        _matchingRight
          ..clear()
          ..addAll(right.map((e) => TextEditingController(text: '$e')));
        final pairs = (p['pairs'] as List?) ?? const [];
        for (final pair in pairs) {
          final l = pair as List;
          _matchingPairs[l[0] as int] = l[1] as int;
        }
        break;
      case CueType.voice:
        // Unreachable in the UI (picker omits VOICE), but be safe.
        break;
    }
  }

  @override
  void dispose() {
    _mcqQuestion.dispose();
    _mcqExplanation.dispose();
    for (final c in _mcqChoices) {
      c.dispose();
    }
    _blanksTemplate.dispose();
    for (final row in _blanksAccept) {
      for (final c in row) {
        c.dispose();
      }
    }
    _matchingPrompt.dispose();
    for (final c in _matchingLeft) {
      c.dispose();
    }
    for (final c in _matchingRight) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final CueFormResult? out;
    switch (_type) {
      case CueType.mcq:
        final input = McqInput(
          question: _mcqQuestion.text.trim(),
          choices: _mcqChoices.map((c) => c.text.trim()).toList(),
          answerIndex: _mcqAnswer,
          explanation: _mcqExplanation.text.trim().isEmpty
              ? null
              : _mcqExplanation.text.trim(),
        );
        final errs = validateMcq(input);
        if (errs.isNotEmpty) {
          setState(() => _errors = errs);
          return;
        }
        out = CueFormResult(
          type: CueType.mcq,
          pause: _pause,
          payload: <String, dynamic>{
            'question': input.question,
            'choices': input.choices,
            'answerIndex': input.answerIndex,
            if (input.explanation != null) 'explanation': input.explanation,
          },
        );
        break;
      case CueType.blanks:
        final input = BlanksInput(
          sentenceTemplate: _blanksTemplate.text,
          blanks: [
            for (var i = 0; i < _blanksAccept.length; i++)
              BlanksSpec(
                accept: _blanksAccept[i]
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList(),
                caseSensitive: _blanksCaseSensitive[i],
              ),
          ],
        );
        final errs = validateBlanks(input);
        if (errs.isNotEmpty) {
          setState(() => _errors = errs);
          return;
        }
        out = CueFormResult(
          type: CueType.blanks,
          pause: _pause,
          payload: <String, dynamic>{
            'sentenceTemplate': input.sentenceTemplate,
            'blanks': [
              for (final b in input.blanks)
                <String, dynamic>{
                  'accept': b.accept,
                  if (b.caseSensitive) 'caseSensitive': true,
                },
            ],
          },
        );
        break;
      case CueType.matching:
        final input = MatchingInput(
          prompt: _matchingPrompt.text.trim(),
          left: _matchingLeft.map((c) => c.text.trim()).toList(),
          right: _matchingRight.map((c) => c.text.trim()).toList(),
          pairs: _matchingPairs.entries
              .map((e) => <int>[e.key, e.value])
              .toList(),
        );
        final errs = validateMatching(input);
        if (errs.isNotEmpty) {
          setState(() => _errors = errs);
          return;
        }
        out = CueFormResult(
          type: CueType.matching,
          pause: _pause,
          payload: <String, dynamic>{
            'prompt': input.prompt,
            'left': input.left,
            'right': input.right,
            'pairs': input.pairs,
          },
        );
        break;
      case CueType.voice:
        return; // unreachable
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'New cue' : 'Edit cue',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (widget.existing == null)
                Row(
                  children: [
                    const Text('Type: '),
                    DropdownButton<CueType>(
                      key: const Key('cueform.type'),
                      value: _type,
                      items: const [
                        DropdownMenuItem(
                            value: CueType.mcq, child: Text('Multiple choice')),
                        DropdownMenuItem(
                            value: CueType.blanks,
                            child: Text('Fill in the blanks')),
                        DropdownMenuItem(
                            value: CueType.matching, child: Text('Matching')),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? _type),
                    ),
                  ],
                ),
              CheckboxListTile(
                key: const Key('cueform.pause'),
                value: _pause,
                onChanged: (v) => setState(() => _pause = v ?? true),
                title: const Text('Pause video when cue appears'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(),
              if (_type == CueType.mcq) ..._mcqBody(),
              if (_type == CueType.blanks) ..._blanksBody(),
              if (_type == CueType.matching) ..._matchingBody(),
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('cueform.errors'),
                  padding: const EdgeInsets.all(8),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final e in _errors) Text('- $e')],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('cueform.submit'),
                onPressed: _submit,
                child: const Text('Save cue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _mcqBody() {
    return [
      TextField(
        key: const Key('cueform.mcq.question'),
        controller: _mcqQuestion,
        decoration: const InputDecoration(labelText: 'Question'),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _mcqChoices.length; i++)
        Row(
          children: [
            // ignore: deprecated_member_use
            Radio<int>(
              key: Key('cueform.mcq.answer.$i'),
              value: i,
              // ignore: deprecated_member_use
              groupValue: _mcqAnswer,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _mcqAnswer = v ?? 0),
            ),
            Expanded(
              child: TextField(
                key: Key('cueform.mcq.choice.$i'),
                controller: _mcqChoices[i],
                decoration:
                    InputDecoration(labelText: 'Choice ${i + 1}'),
              ),
            ),
            if (_mcqChoices.length > 2)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() {
                  _mcqChoices.removeAt(i).dispose();
                  if (_mcqAnswer >= _mcqChoices.length) {
                    _mcqAnswer = _mcqChoices.length - 1;
                  }
                }),
              ),
          ],
        ),
      if (_mcqChoices.length < 4)
        TextButton.icon(
          key: const Key('cueform.mcq.addChoice'),
          onPressed: () => setState(() {
            _mcqChoices.add(TextEditingController());
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add choice'),
        ),
      const SizedBox(height: 8),
      TextField(
        key: const Key('cueform.mcq.explanation'),
        controller: _mcqExplanation,
        decoration: const InputDecoration(
          labelText: 'Explanation (optional)',
        ),
      ),
    ];
  }

  List<Widget> _blanksBody() {
    return [
      TextField(
        key: const Key('cueform.blanks.template'),
        controller: _blanksTemplate,
        decoration: const InputDecoration(
          labelText: 'Sentence template (use {{0}}, {{1}}, ...)',
        ),
        minLines: 2,
        maxLines: 4,
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _blanksAccept.length; i++) ...[
        Row(
          children: [
            Text('Blank ${i + 1}'),
            const Spacer(),
            Checkbox(
              key: Key('cueform.blanks.caseSensitive.$i'),
              value: _blanksCaseSensitive[i],
              onChanged: (v) =>
                  setState(() => _blanksCaseSensitive[i] = v ?? false),
            ),
            const Text('Case sensitive'),
            if (_blanksAccept.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() {
                  final row = _blanksAccept.removeAt(i);
                  for (final c in row) {
                    c.dispose();
                  }
                  _blanksCaseSensitive.removeAt(i);
                }),
              ),
          ],
        ),
        for (var j = 0; j < _blanksAccept[i].length; j++)
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('cueform.blanks.accept.$i.$j'),
                  controller: _blanksAccept[i][j],
                  decoration: InputDecoration(
                    labelText: 'Accepted answer ${j + 1}',
                  ),
                ),
              ),
              if (_blanksAccept[i].length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() {
                    _blanksAccept[i].removeAt(j).dispose();
                  }),
                ),
            ],
          ),
        TextButton.icon(
          key: Key('cueform.blanks.addAccept.$i'),
          onPressed: () => setState(() {
            _blanksAccept[i].add(TextEditingController());
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add synonym'),
        ),
      ],
      TextButton.icon(
        key: const Key('cueform.blanks.addBlank'),
        onPressed: () => setState(() {
          _blanksAccept.add([TextEditingController()]);
          _blanksCaseSensitive.add(false);
        }),
        icon: const Icon(Icons.add),
        label: const Text('Add blank'),
      ),
    ];
  }

  List<Widget> _matchingBody() {
    return [
      TextField(
        key: const Key('cueform.matching.prompt'),
        controller: _matchingPrompt,
        decoration: const InputDecoration(labelText: 'Prompt'),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _matchingColumn('Left', _matchingLeft, true)),
          const SizedBox(width: 12),
          Expanded(child: _matchingColumn('Right', _matchingRight, false)),
        ],
      ),
      const SizedBox(height: 8),
      const Text('Tap a left item, then a right item to create a pair.'),
      Wrap(
        spacing: 4,
        children: [
          for (final entry in _matchingPairs.entries)
            Chip(
              key: Key('cueform.matching.pair.${entry.key}-${entry.value}'),
              label: Text(
                '${entry.key + 1} → ${entry.value + 1}',
              ),
              onDeleted: () => setState(() {
                _matchingPairs.remove(entry.key);
              }),
            ),
        ],
      ),
    ];
  }

  Widget _matchingColumn(
    String label,
    List<TextEditingController> items,
    bool isLeft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        for (var i = 0; i < items.length; i++)
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('cueform.matching.${isLeft ? "left" : "right"}.$i'),
                  controller: items[i],
                  decoration: InputDecoration(
                    labelText: '$label ${i + 1}',
                  ),
                ),
              ),
              if (isLeft)
                IconButton(
                  key: Key('cueform.matching.selectLeft.$i'),
                  icon: Icon(
                    _selectedLeft == i
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onPressed: () => setState(() {
                    _selectedLeft = _selectedLeft == i ? null : i;
                  }),
                )
              else
                IconButton(
                  key: Key('cueform.matching.pairRight.$i'),
                  icon: const Icon(Icons.link),
                  onPressed: _selectedLeft == null
                      ? null
                      : () => setState(() {
                            _matchingPairs[_selectedLeft!] = i;
                            _selectedLeft = null;
                          }),
                ),
              if (items.length > 2)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() {
                    items.removeAt(i).dispose();
                    // Clean any pair referencing the removed index.
                    if (isLeft) {
                      _matchingPairs.remove(i);
                    } else {
                      _matchingPairs
                          .removeWhere((_, rightIdx) => rightIdx == i);
                    }
                  }),
                ),
            ],
          ),
        TextButton.icon(
          key: Key('cueform.matching.${isLeft ? "addLeft" : "addRight"}'),
          onPressed: () => setState(() {
            items.add(TextEditingController());
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }
}
