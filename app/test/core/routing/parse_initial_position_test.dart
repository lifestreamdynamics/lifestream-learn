import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/routing/app_router.dart';

void main() {
  group('parseInitialPosition (?t= deep-link query param)', () {
    test('null and empty strings return null (natural start)', () {
      expect(parseInitialPosition(null), isNull);
      expect(parseInitialPosition(''), isNull);
    });

    test('valid ms string returns a Duration', () {
      expect(parseInitialPosition('0'), Duration.zero);
      expect(parseInitialPosition('12345'),
          const Duration(milliseconds: 12345));
    });

    test('malformed / negative values fall back to null — player starts clean',
        () {
      expect(parseInitialPosition('abc'), isNull);
      expect(parseInitialPosition('-1'), isNull);
      expect(parseInitialPosition('1.5'), isNull);
    });
  });
}
