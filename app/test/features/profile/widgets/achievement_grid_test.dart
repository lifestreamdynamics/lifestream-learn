import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/achievement.dart';
import 'package:lifestream_learn_app/data/repositories/progress_repository.dart';
import 'package:lifestream_learn_app/features/profile/widgets/achievement_grid.dart';
import 'package:mocktail/mocktail.dart';

class _MockProgressRepo extends Mock implements ProgressRepository {}

Achievement _a(String id, String title, String iconKey) => Achievement(
      id: id,
      title: title,
      description: 'Do the thing for $id',
      iconKey: iconKey,
      criteriaJson: const {'type': 'lessons_completed', 'count': 1},
    );

AchievementsResponse _response({
  List<Achievement> unlocked = const [],
  List<Achievement> locked = const [],
  Map<String, DateTime> unlockedAt = const {},
}) =>
    AchievementsResponse(
      unlocked: unlocked,
      locked: locked,
      unlockedAtByAchievementId: unlockedAt,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late _MockProgressRepo repo;

  setUp(() {
    repo = _MockProgressRepo();
  });

  testWidgets('renders a tile per achievement, unlocked and locked',
      (tester) async {
    when(() => repo.fetchAchievements()).thenAnswer(
      (_) async => _response(
        unlocked: [_a('first_lesson', 'First Lesson', 'school')],
        locked: [_a('streak_7', 'Week-Long Streak', 'whatshot')],
        unlockedAt: {
          'first_lesson': DateTime.utc(2026, 4, 15, 10),
        },
      ),
    );

    await tester.pumpWidget(_wrap(AchievementGrid(progressRepo: repo)));
    // Allow the initState load() to resolve.
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profile.achievement.first_lesson')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile.achievement.streak_7')),
      findsOneWidget,
    );
    expect(find.text('First Lesson'), findsOneWidget);
    expect(find.text('Week-Long Streak'), findsOneWidget);
  });

  testWidgets('locked tile renders with greyed colour vs unlocked primary',
      (tester) async {
    when(() => repo.fetchAchievements()).thenAnswer(
      (_) async => _response(
        unlocked: [_a('first_lesson', 'First Lesson', 'school')],
        locked: [_a('streak_7', 'Week-Long Streak', 'whatshot')],
        unlockedAt: {
          'first_lesson': DateTime.utc(2026, 4, 15, 10),
        },
      ),
    );

    await tester.pumpWidget(_wrap(AchievementGrid(progressRepo: repo)));
    await tester.pumpAndSettle();

    // Drill into both Icon widgets and compare colours. Unlocked should
    // be brighter (higher alpha) than locked.
    final unlockedIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('profile.achievement.first_lesson')),
        matching: find.byType(Icon),
      ),
    );
    final lockedIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('profile.achievement.streak_7')),
        matching: find.byType(Icon),
      ),
    );
    // Different colour refs — don't assert exact values; the service
    // maps unlocked → primary, locked → muted with alpha 0.45.
    expect(unlockedIcon.color, isNot(equals(lockedIcon.color)));
    // Locked colour has explicit alpha < 1.
    expect(lockedIcon.color!.a, lessThan(1.0));
  });

  testWidgets('tapping a tile opens the bottom sheet with the description',
      (tester) async {
    when(() => repo.fetchAchievements()).thenAnswer(
      (_) async => _response(
        unlocked: [_a('first_lesson', 'First Lesson', 'school')],
        unlockedAt: {
          'first_lesson': DateTime.utc(2026, 4, 15, 10),
        },
      ),
    );

    await tester.pumpWidget(_wrap(AchievementGrid(progressRepo: repo)));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('profile.achievement.first_lesson')),
    );
    await tester.pumpAndSettle();

    // Sheet reveals the description and the unlockedAt line.
    expect(find.text('Do the thing for first_lesson'), findsOneWidget);
    expect(
      find.byKey(const Key('profile.achievement.unlockedAt')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a locked tile shows the "keep going" message',
      (tester) async {
    when(() => repo.fetchAchievements()).thenAnswer(
      (_) async => _response(
        locked: [_a('streak_7', 'Week-Long Streak', 'whatshot')],
      ),
    );

    await tester.pumpWidget(_wrap(AchievementGrid(progressRepo: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile.achievement.streak_7')));
    await tester.pumpAndSettle();

    expect(
      find.text('Locked — keep going to earn this one.'),
      findsOneWidget,
    );
  });

  testWidgets('empty catalog → renders "No achievements yet."',
      (tester) async {
    when(() => repo.fetchAchievements())
        .thenAnswer((_) async => _response());
    await tester.pumpWidget(_wrap(AchievementGrid(progressRepo: repo)));
    await tester.pumpAndSettle();
    expect(find.text('No achievements yet.'), findsOneWidget);
  });
}
