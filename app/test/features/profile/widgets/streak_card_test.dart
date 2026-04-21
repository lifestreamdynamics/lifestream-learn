import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/features/profile/widgets/streak_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders "Start a streak today" when currentStreak is 0',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const StreakCard(currentStreak: 0, longestStreak: 0)),
    );
    expect(find.text('Start a streak today'), findsOneWidget);
    expect(
      find.text('Watch a lesson or answer a cue to begin.'),
      findsOneWidget,
    );
    // Icon is rendered in the muted "not streaking" colour. We don't
    // assert the exact colour value — the primary signal is the title
    // text and the subtitle change. Icon presence is enough here.
    expect(find.byKey(const Key('profile.streak.icon')), findsOneWidget);
  });

  testWidgets('shows singular day form on a 1-day streak', (tester) async {
    await tester.pumpWidget(
      _wrap(const StreakCard(currentStreak: 1, longestStreak: 1)),
    );
    expect(find.text('1 day streak'), findsOneWidget);
    expect(find.text('Longest: 1 day'), findsOneWidget);
  });

  testWidgets('shows plural day form on a multi-day streak', (tester) async {
    await tester.pumpWidget(
      _wrap(const StreakCard(currentStreak: 7, longestStreak: 14)),
    );
    expect(find.text('7 days streak'), findsOneWidget);
    expect(find.text('Longest: 14 days'), findsOneWidget);
  });

  testWidgets('icon + title tiles have stable keys for screen tests',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const StreakCard(currentStreak: 3, longestStreak: 5)),
    );
    expect(find.byKey(const Key('profile.streak')), findsOneWidget);
    expect(find.byKey(const Key('profile.streak.icon')), findsOneWidget);
    expect(find.byKey(const Key('profile.streak.title')), findsOneWidget);
    expect(find.byKey(const Key('profile.streak.subtitle')), findsOneWidget);
  });
}
