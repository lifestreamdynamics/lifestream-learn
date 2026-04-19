// Client-side cue-payload validators.
//
// These MUST mirror `api/src/validators/cue-payloads.ts` exactly.
// The server rejects invalid payloads with 400 already, but catching
// them client-side keeps the authoring UX tight (inline field errors
// instead of a form-level "validation failed").
//
// Each validator returns a list of human-readable error messages; an
// empty list means the payload is valid. The caller renders these near
// the offending field or at the top of the form.

/// Extracts distinct `{{N}}` placeholder indices from a BLANKS template
/// in order of first appearance. Mirrors `extractPlaceholderIndices` in
/// the TS validator — **keep the regex identical** so a sentence template
/// that passes client-side parses the same way server-side.
List<int> extractPlaceholderIndices(String template) {
  final re = RegExp(r'\{\{(\d+)\}\}');
  final seen = <int>{};
  final out = <int>[];
  for (final m in re.allMatches(template)) {
    final idx = int.parse(m.group(1)!);
    if (seen.add(idx)) {
      out.add(idx);
    }
  }
  return out;
}

// ---------- MCQ ----------

class McqInput {
  const McqInput({
    required this.question,
    required this.choices,
    required this.answerIndex,
    this.explanation,
  });
  final String question;
  final List<String> choices;
  final int answerIndex;
  final String? explanation;
}

List<String> validateMcq(McqInput input) {
  final errors = <String>[];
  if (input.question.trim().isEmpty) {
    errors.add('Question must not be empty.');
  }
  if (input.choices.length < 2 || input.choices.length > 4) {
    errors.add('Provide between 2 and 4 choices.');
  }
  for (var i = 0; i < input.choices.length; i++) {
    if (input.choices[i].trim().isEmpty) {
      errors.add('Choice ${i + 1} must not be empty.');
    }
  }
  if (input.answerIndex < 0 || input.answerIndex >= input.choices.length) {
    errors.add('Select a correct answer from the choices.');
  }
  // `answerIndex <= 3` is enforced server-side; implied by choices
  // length ≤ 4 here so no separate check needed.
  return errors;
}

// ---------- BLANKS ----------

class BlanksSpec {
  const BlanksSpec({
    required this.accept,
    this.caseSensitive = false,
  });
  final List<String> accept;
  final bool caseSensitive;
}

class BlanksInput {
  const BlanksInput({
    required this.sentenceTemplate,
    required this.blanks,
  });
  final String sentenceTemplate;
  final List<BlanksSpec> blanks;
}

List<String> validateBlanks(BlanksInput input) {
  final errors = <String>[];
  if (input.sentenceTemplate.trim().isEmpty) {
    errors.add('Sentence template must not be empty.');
    return errors;
  }
  if (input.blanks.isEmpty) {
    errors.add('At least one blank is required.');
  }
  final indices = extractPlaceholderIndices(input.sentenceTemplate);
  if (indices.isEmpty) {
    errors.add(
      'Sentence template must contain at least one {{N}} placeholder.',
    );
    return errors;
  }
  if (indices.length != input.blanks.length) {
    errors.add(
      'Template has ${indices.length} distinct placeholders but ${input.blanks.length} blanks.',
    );
    return errors;
  }
  // Must be exactly {{0}}..{{N-1}} once each.
  final sorted = List<int>.of(indices)..sort();
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i] != i) {
      errors.add(
        'Placeholders must be {{0}}..{{${input.blanks.length - 1}}} exactly once.',
      );
      return errors;
    }
  }
  for (var i = 0; i < input.blanks.length; i++) {
    final blank = input.blanks[i];
    if (blank.accept.isEmpty) {
      errors.add('Blank ${i + 1} needs at least one accepted answer.');
      continue;
    }
    for (var j = 0; j < blank.accept.length; j++) {
      if (blank.accept[j].trim().isEmpty) {
        errors.add('Blank ${i + 1} accepted answer ${j + 1} is empty.');
      }
    }
  }
  return errors;
}

// ---------- MATCHING ----------

class MatchingInput {
  const MatchingInput({
    required this.prompt,
    required this.left,
    required this.right,
    required this.pairs,
  });
  final String prompt;
  final List<String> left;
  final List<String> right;

  /// Each pair is `[leftIdx, rightIdx]`. Must be a 1:1 bipartite matching
  /// (each left and each right appears in at most one pair).
  final List<List<int>> pairs;
}

List<String> validateMatching(MatchingInput input) {
  final errors = <String>[];
  if (input.prompt.trim().isEmpty) {
    errors.add('Prompt must not be empty.');
  }
  if (input.left.length < 2) {
    errors.add('Left column needs at least 2 items.');
  }
  if (input.right.length < 2) {
    errors.add('Right column needs at least 2 items.');
  }
  for (var i = 0; i < input.left.length; i++) {
    if (input.left[i].trim().isEmpty) {
      errors.add('Left item ${i + 1} must not be empty.');
    }
  }
  for (var i = 0; i < input.right.length; i++) {
    if (input.right[i].trim().isEmpty) {
      errors.add('Right item ${i + 1} must not be empty.');
    }
  }
  if (input.pairs.isEmpty) {
    errors.add('Create at least one pair.');
  }
  final seenLeft = <int>{};
  final seenRight = <int>{};
  final seenPair = <String>{};
  for (var i = 0; i < input.pairs.length; i++) {
    final p = input.pairs[i];
    if (p.length != 2) {
      errors.add('Pair ${i + 1} must have exactly [left, right].');
      continue;
    }
    final l = p[0];
    final r = p[1];
    if (l < 0 || l >= input.left.length) {
      errors.add(
        'Pair ${i + 1}: left index $l out of range.',
      );
    }
    if (r < 0 || r >= input.right.length) {
      errors.add(
        'Pair ${i + 1}: right index $r out of range.',
      );
    }
    final key = '$l:$r';
    if (!seenPair.add(key)) {
      errors.add('Pair ${i + 1} is a duplicate.');
    }
    if (!seenLeft.add(l)) {
      errors.add(
        'Left item ${l + 1} appears in more than one pair (must be 1:1).',
      );
    }
    if (!seenRight.add(r)) {
      errors.add(
        'Right item ${r + 1} appears in more than one pair (must be 1:1).',
      );
    }
  }
  return errors;
}
