import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/art/brand_empty_state.dart';
import 'package:lifestream_learn_app/data/models/course.dart';
import 'package:lifestream_learn_app/data/repositories/course_repository.dart';
import 'package:lifestream_learn_app/features/courses/available_courses_body.dart';
import 'package:mocktail/mocktail.dart';

class _MockCourseRepository extends Mock implements CourseRepository {}

void main() {
  testWidgets('empty available-courses list renders BrandEmptyState',
      (tester) async {
    final repo = _MockCourseRepository();
    when(() => repo.published(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          owned: any(named: 'owned'),
          publishedFilter: any(named: 'publishedFilter'),
        )).thenAnswer(
        (_) async => const CoursePage(items: [], hasMore: false));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AvailableCoursesBody(courseRepo: repo)),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('courses.empty')), findsOneWidget);
    expect(find.byType(BrandEmptyState), findsOneWidget);
    // Sanity: title from the new branded empty state.
    expect(find.text('No published courses yet'), findsOneWidget);
  });
}
