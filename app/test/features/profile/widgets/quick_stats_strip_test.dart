import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/features/profile/widgets/quick_stats_strip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets(
      'renders dash placeholders when all values null (loading/error state)',
      (tester) async {
    await tester.pumpWidget(_wrap(const QuickStatsStrip()));
    expect(find.byKey(const Key('profile.stat.courses')), findsOneWidget);
    expect(find.byKey(const Key('profile.stat.lessons')), findsOneWidget);
    expect(find.byKey(const Key('profile.stat.streak')), findsOneWidget);
    expect(find.byKey(const Key('profile.stat.accuracy')), findsOneWidget);
    // Each tile shows the em-dash placeholder.
    expect(find.text('—'), findsNWidgets(4));
  });

  testWidgets('renders real values from /api/me/progress when loaded',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const QuickStatsStrip(
        courses: 3,
        lessons: 17,
        streakDays: 5,
        accuracyPct: 87.5,
      ),
    ));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('5 d'), findsOneWidget);
    // Accuracy renders as a whole-percent string (fixed 0 decimals).
    expect(find.text('88%'), findsOneWidget);
    // No em-dash placeholders when everything is non-null.
    expect(find.text('—'), findsNothing);
  });

  testWidgets('mixes real values and dashes when partially populated',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const QuickStatsStrip(
        courses: 0,
        lessons: 0,
        // streak + accuracy still loading
      ),
    ));
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('renders 0 accuracy as 0% (not as the dash placeholder)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const QuickStatsStrip(
        courses: 1,
        lessons: 1,
        streakDays: 0,
        accuracyPct: 0.0,
      ),
    ));
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 d'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });
}
