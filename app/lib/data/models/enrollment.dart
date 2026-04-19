import 'package:freezed_annotation/freezed_annotation.dart';

part 'enrollment.freezed.dart';
part 'enrollment.g.dart';

/// Raw enrollment row returned by `POST /api/enrollments`.
@freezed
class Enrollment with _$Enrollment {
  const factory Enrollment({
    required String id,
    required String userId,
    required String courseId,
    required DateTime startedAt,
    String? lastVideoId,
    int? lastPosMs,
  }) = _Enrollment;

  factory Enrollment.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentFromJson(json);
}

/// Nested course tile the enrollment-list endpoint embeds inside each
/// row. Slimmer than `Course` — enough to render a card.
@freezed
class EnrolledCourseSummary with _$EnrolledCourseSummary {
  const factory EnrolledCourseSummary({
    required String id,
    required String title,
    required String slug,
    String? coverImageUrl,
  }) = _EnrolledCourseSummary;

  factory EnrolledCourseSummary.fromJson(Map<String, dynamic> json) =>
      _$EnrolledCourseSummaryFromJson(json);
}

/// `GET /api/enrollments` row — enrollment metadata + the embedded course
/// tile.
@freezed
class EnrollmentWithCourse with _$EnrollmentWithCourse {
  const factory EnrollmentWithCourse({
    required String id,
    required String userId,
    required String courseId,
    required DateTime startedAt,
    String? lastVideoId,
    int? lastPosMs,
    required EnrolledCourseSummary course,
  }) = _EnrollmentWithCourse;

  factory EnrollmentWithCourse.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentWithCourseFromJson(json);
}
