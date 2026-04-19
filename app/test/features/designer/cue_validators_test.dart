import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/features/designer/cue_validators.dart';

void main() {
  group('extractPlaceholderIndices', () {
    test('returns empty for no placeholders', () {
      expect(extractPlaceholderIndices('hello world'), <int>[]);
    });

    test('returns single index', () {
      expect(extractPlaceholderIndices('say {{0}} now'), [0]);
    });

    test('returns distinct indices in order of first appearance', () {
      expect(
        extractPlaceholderIndices('{{1}} before {{0}}'),
        [1, 0],
      );
    });

    test('deduplicates repeated placeholders', () {
      expect(
        extractPlaceholderIndices('{{0}} {{0}} {{1}}'),
        [0, 1],
      );
    });
  });

  group('validateMcq', () {
    test('valid case passes with no errors', () {
      final errs = validateMcq(const McqInput(
        question: 'Which planet?',
        choices: ['Mercury', 'Venus', 'Earth', 'Mars'],
        answerIndex: 2,
      ));
      expect(errs, isEmpty);
    });

    test('valid with 2 choices', () {
      final errs = validateMcq(const McqInput(
        question: 'A or B?',
        choices: ['A', 'B'],
        answerIndex: 0,
      ));
      expect(errs, isEmpty);
    });

    test('empty question fails', () {
      final errs = validateMcq(const McqInput(
        question: '   ',
        choices: ['A', 'B'],
        answerIndex: 0,
      ));
      expect(errs, contains('Question must not be empty.'));
    });

    test('too few choices fails', () {
      final errs = validateMcq(const McqInput(
        question: 'Q',
        choices: ['A'],
        answerIndex: 0,
      ));
      expect(errs, contains('Provide between 2 and 4 choices.'));
    });

    test('too many choices fails', () {
      final errs = validateMcq(const McqInput(
        question: 'Q',
        choices: ['A', 'B', 'C', 'D', 'E'],
        answerIndex: 0,
      ));
      expect(errs, contains('Provide between 2 and 4 choices.'));
    });

    test('empty choice text fails', () {
      final errs = validateMcq(const McqInput(
        question: 'Q',
        choices: ['A', ' '],
        answerIndex: 0,
      ));
      expect(errs.any((e) => e.contains('Choice 2')), isTrue);
    });

    test('answerIndex out of range high fails', () {
      final errs = validateMcq(const McqInput(
        question: 'Q',
        choices: ['A', 'B'],
        answerIndex: 2,
      ));
      expect(errs, contains('Select a correct answer from the choices.'));
    });

    test('answerIndex negative fails', () {
      final errs = validateMcq(const McqInput(
        question: 'Q',
        choices: ['A', 'B'],
        answerIndex: -1,
      ));
      expect(errs, contains('Select a correct answer from the choices.'));
    });
  });

  group('validateBlanks', () {
    test('valid single blank', () {
      final errs = validateBlanks(const BlanksInput(
        sentenceTemplate: 'The capital is {{0}}.',
        blanks: [BlanksSpec(accept: ['Paris'])],
      ));
      expect(errs, isEmpty);
    });

    test('valid two blanks', () {
      final errs = validateBlanks(const BlanksInput(
        sentenceTemplate: '{{0}} + {{1}} = 3',
        blanks: [
          BlanksSpec(accept: ['1']),
          BlanksSpec(accept: ['2']),
        ],
      ));
      expect(errs, isEmpty);
    });

    test('empty template fails', () {
      final errs = validateBlanks(const BlanksInput(
        sentenceTemplate: '',
        blanks: [BlanksSpec(accept: ['x'])],
      ));
      expect(errs, contains('Sentence template must not be empty.'));
    });

    test('template without placeholders fails', () {
      final errs = validateBlanks(const BlanksInput(
        sentenceTemplate: 'no placeholders',
        blanks: [BlanksSpec(accept: ['x'])],
      ));
      expect(
        errs,
        contains('Sentence template must contain at least one {{N}} placeholder.'),
      );
    });

    test('placeholder count mismatch fails', () {
      final errs = validateBlanks(const BlanksInput(
        sentenceTemplate: '{{0}} {{1}}',
        blanks: [BlanksSpec(accept: ['x'])],
      ));
      expect(
        errs.any((e) => e.contains('2 distinct placeholders but 1 blanks')),
        isTrue,
      );
    });

    test('non-sequential placeholders (skip 0) fails', () {
      final errs = validateBlanks(const BlanksInput(
        sentenceTemplate: '{{1}} {{2}}',
        blanks: [
          BlanksSpec(accept: ['x']),
          BlanksSpec(accept: ['y']),
        ],
      ));
      expect(
        errs.any((e) => e.contains('{{0}}..{{1}} exactly once')),
        isTrue,
      );
    });

    test('empty blanks list is flagged', () {
      final errs = validateBlanks(const BlanksInput(
        sentenceTemplate: '{{0}}',
        blanks: [],
      ));
      expect(errs, contains('At least one blank is required.'));
    });

    test('blank with no accept list fails', () {
      final errs = validateBlanks(const BlanksInput(
        sentenceTemplate: '{{0}}',
        blanks: [BlanksSpec(accept: [])],
      ));
      expect(errs.any((e) => e.contains('at least one accepted answer')),
          isTrue);
    });

    test('blank with empty accept string fails', () {
      final errs = validateBlanks(const BlanksInput(
        sentenceTemplate: '{{0}}',
        blanks: [BlanksSpec(accept: ['  '])],
      ));
      expect(errs.any((e) => e.contains('accepted answer 1 is empty')),
          isTrue);
    });
  });

  group('validateMatching', () {
    test('valid 2x2 with 1 pair', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'Match',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [
          [0, 0],
        ],
      ));
      expect(errs, isEmpty);
    });

    test('empty prompt fails', () {
      final errs = validateMatching(MatchingInput(
        prompt: ' ',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [
          [0, 0],
        ],
      ));
      expect(errs, contains('Prompt must not be empty.'));
    });

    test('too few left/right items fails', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a'],
        right: const ['1'],
        pairs: [
          [0, 0],
        ],
      ));
      expect(errs, contains('Left column needs at least 2 items.'));
      expect(errs, contains('Right column needs at least 2 items.'));
    });

    test('empty item text fails', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a', ''],
        right: const ['1', ' '],
        pairs: [
          [0, 0],
        ],
      ));
      expect(errs.any((e) => e.contains('Left item 2')), isTrue);
      expect(errs.any((e) => e.contains('Right item 2')), isTrue);
    });

    test('no pairs fails', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [],
      ));
      expect(errs, contains('Create at least one pair.'));
    });

    test('malformed pair length != 2 fails', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [
          [0],
        ],
      ));
      expect(errs.any((e) => e.contains('must have exactly [left, right]')),
          isTrue);
    });

    test('left index out of range fails', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [
          [5, 0],
        ],
      ));
      expect(errs.any((e) => e.contains('left index 5 out of range')), isTrue);
    });

    test('right index out of range fails', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [
          [0, 5],
        ],
      ));
      expect(errs.any((e) => e.contains('right index 5 out of range')), isTrue);
    });

    test('duplicate pair fails', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [
          [0, 0],
          [0, 0],
        ],
      ));
      expect(errs.any((e) => e.contains('is a duplicate')), isTrue);
    });

    test('left appearing in two pairs fails (1:1 violation)', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [
          [0, 0],
          [0, 1],
        ],
      ));
      expect(errs.any((e) => e.contains('Left item 1 appears in more than one pair')),
          isTrue);
    });

    test('right appearing in two pairs fails (1:1 violation)', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [
          [0, 0],
          [1, 0],
        ],
      ));
      expect(errs.any((e) => e.contains('Right item 1 appears in more than one pair')),
          isTrue);
    });

    test('negative indices flagged', () {
      final errs = validateMatching(MatchingInput(
        prompt: 'p',
        left: const ['a', 'b'],
        right: const ['1', '2'],
        pairs: [
          [-1, -1],
        ],
      ));
      expect(errs.any((e) => e.contains('out of range')), isTrue);
    });
  });
}
