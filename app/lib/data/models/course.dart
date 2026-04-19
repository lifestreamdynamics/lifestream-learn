import 'package:freezed_annotation/freezed_annotation.dart';

import 'video.dart';

part 'course.freezed.dart';
part 'course.g.dart';

/// Published / unpublished course record matching the backend's `Course`
/// Prisma row projected through `courseService.listCourses`.
@freezed
class Course with _$Course {
  const factory Course({
    required String id,
    required String slug,
    required String title,
    required String description,
    String? coverImageUrl,
    required String ownerId,
    required bool published,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Course;

  factory Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);
}

/// Course + its videos, returned by `GET /api/courses/:id`. Videos come in
/// the course-scoped shape (no `courseId` repeated on each row).
@freezed
class CourseDetail with _$CourseDetail {
  const factory CourseDetail({
    required String id,
    required String slug,
    required String title,
    required String description,
    String? coverImageUrl,
    required String ownerId,
    required bool published,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(<CourseVideoSummary>[]) List<CourseVideoSummary> videos,
  }) = _CourseDetail;

  factory CourseDetail.fromJson(Map<String, dynamic> json) =>
      _$CourseDetailFromJson(json);
}

/// Tiny course summary the feed embeds beside each video entry.
@freezed
class CourseSummary with _$CourseSummary {
  const factory CourseSummary({
    required String id,
    required String title,
    String? coverImageUrl,
  }) = _CourseSummary;

  factory CourseSummary.fromJson(Map<String, dynamic> json) =>
      _$CourseSummaryFromJson(json);
}

/// A page in the course list. One of two typed page shapes in the app —
/// chose this over `Page<T>` with a freezed generic + converter because
/// the freezed generic dance is more boilerplate than two small classes.
@freezed
class CoursePage with _$CoursePage {
  const factory CoursePage({
    required List<Course> items,
    String? nextCursor,
    required bool hasMore,
  }) = _CoursePage;

  factory CoursePage.fromJson(Map<String, dynamic> json) =>
      _$CoursePageFromJson(json);
}
