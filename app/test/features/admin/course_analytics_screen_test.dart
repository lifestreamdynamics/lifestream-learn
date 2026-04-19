import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/platform/flag_secure.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/models/course_analytics.dart';
import 'package:lifestream_learn_app/data/repositories/admin_analytics_repository.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';
import 'package:lifestream_learn_app/features/admin/course_analytics_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AdminAnalyticsRepository {}

class _MockCourseRepo extends Mock implements CourseRepository {}

Course _course(String id) => Course(
      id: id,
      slug: 'c-$id',
      title: 'Course $id',
      description: 'd',
      ownerId: 'o1',
      published: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

Widget _wrap(
        AdminAnalyticsRepository analytics, CourseRepository courseRepo) =>
    MaterialApp(
      home: Scaffold(
        body: CourseAnalyticsScreen(
          analyticsRepo: analytics,
          courseRepo: courseRepo,
        ),
      ),
    );

void main() {
  setUp(() {
    final channel = MethodChannel('com.lifestream.learn/flag_secure');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    FlagSecure.testChannel = channel;
  });

  tearDown(() {
    FlagSecure.testChannel = null;
  });

  testWidgets('renders picker, then analytics card after selecting a course',
      (tester) async {
    final analytics = _MockAnalytics();
    final courseRepo = _MockCourseRepo();

    when(() => courseRepo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          owned: any(named: 'owned'),
          publishedFilter: any(named: 'publishedFilter'),
        )).thenAnswer((_) async => CoursePage(
          items: [_course('a'), _course('b')],
          hasMore: false,
        ));

    when(() => analytics.course('a')).thenAnswer((_) async =>
        const CourseAnalytics(
          totalViews: 7,
          completionRate: 0.42,
          perCueTypeAccuracy: PerCueTypeAccuracy(
            mcq: 0.81,
            blanks: null,
            matching: 0.5,
          ),
        ));

    await tester.pumpWidget(_wrap(analytics, courseRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin.analytics.picker')), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin.analytics.picker')));
    await tester.pumpAndSettle();
    // Select the first course's text in the dropdown menu.
    await tester.tap(find.text('Course a').last);
    await tester.pumpAndSettle();

    // Card + stat tiles + accuracy rows are present.
    expect(find.byKey(const Key('admin.analytics.card')), findsOneWidget);
    expect(find.byKey(const Key('admin.analytics.totalViews')), findsOneWidget);
    expect(
      find.byKey(const Key('admin.analytics.completionRate')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('admin.analytics.accuracy')), findsOneWidget);

    // totalViews rendered exactly; completion rate as a percentage.
    expect(find.text('7'), findsOneWidget);
    expect(find.text('42.0%'), findsOneWidget);

    // MCQ accuracy 0.81 → 81.0%; BLANKS null → "No attempts yet".
    expect(find.text('81.0%'), findsOneWidget);
    expect(find.text('No attempts yet'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
  });

  testWidgets('empty course list renders the "no courses" card',
      (tester) async {
    final analytics = _MockAnalytics();
    final courseRepo = _MockCourseRepo();
    when(() => courseRepo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          owned: any(named: 'owned'),
          publishedFilter: any(named: 'publishedFilter'),
        )).thenAnswer(
        (_) async => const CoursePage(items: [], hasMore: false));

    await tester.pumpWidget(_wrap(analytics, courseRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin.analytics.noCourses')), findsOneWidget);
  });
}
