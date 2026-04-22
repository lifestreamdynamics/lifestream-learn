import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/art/brand_empty_state.dart';

Widget _wrap(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    themeMode: themeMode,
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  group('BrandEmptyState', () {
    testWidgets('renders title in light theme without errors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BrandEmptyState(
            painter: CircuitSwirlPainter(
              scheme: ThemeData.light(useMaterial3: true).colorScheme,
            ),
            title: 'Nothing here yet',
            subtitle: 'Try adding something.',
          ),
        ),
      );

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Try adding something.'), findsOneWidget);
      // No exceptions thrown — the custom painter ran without error.
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders title in dark theme without errors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BrandEmptyState(
            painter: CircuitSwirlPainter(
              scheme: ThemeData.dark(useMaterial3: true).colorScheme,
            ),
            title: 'Dark empty',
            subtitle: 'Dark subtitle.',
          ),
          themeMode: ThemeMode.dark,
        ),
      );

      expect(find.text('Dark empty'), findsOneWidget);
      expect(find.text('Dark subtitle.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders optional action widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BrandEmptyState(
            painter: CircuitSwirlPainter(
              scheme: ThemeData.light(useMaterial3: true).colorScheme,
            ),
            title: 'Empty',
            action: ElevatedButton(
              onPressed: () {},
              child: const Text('Do something'),
            ),
          ),
        ),
      );

      expect(find.text('Do something'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('omits subtitle when not provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BrandEmptyState(
            painter: CircuitSwirlPainter(
              scheme: ThemeData.light(useMaterial3: true).colorScheme,
            ),
            title: 'Just a title',
          ),
        ),
      );

      expect(find.text('Just a title'), findsOneWidget);
      // No second text widget from subtitle
      expect(find.byType(Text), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EmptyFeedPainter paints without errors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BrandEmptyState(
            painter: EmptyFeedPainter(
              scheme: ThemeData.light(useMaterial3: true).colorScheme,
            ),
            title: 'Feed empty',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('EmptyEnrollmentsPainter paints without errors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BrandEmptyState(
            painter: EmptyEnrollmentsPainter(
              scheme: ThemeData.light(useMaterial3: true).colorScheme,
            ),
            title: 'No enrollments',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('EmptySearchPainter paints without errors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BrandEmptyState(
            painter: EmptySearchPainter(
              scheme: ThemeData.light(useMaterial3: true).colorScheme,
            ),
            title: 'No results',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
