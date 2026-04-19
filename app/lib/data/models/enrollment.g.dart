// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enrollment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EnrollmentImpl _$$EnrollmentImplFromJson(Map<String, dynamic> json) =>
    _$EnrollmentImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      courseId: json['courseId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      lastVideoId: json['lastVideoId'] as String?,
      lastPosMs: (json['lastPosMs'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$EnrollmentImplToJson(_$EnrollmentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'courseId': instance.courseId,
      'startedAt': instance.startedAt.toIso8601String(),
      'lastVideoId': instance.lastVideoId,
      'lastPosMs': instance.lastPosMs,
    };

_$EnrolledCourseSummaryImpl _$$EnrolledCourseSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$EnrolledCourseSummaryImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  slug: json['slug'] as String,
  coverImageUrl: json['coverImageUrl'] as String?,
);

Map<String, dynamic> _$$EnrolledCourseSummaryImplToJson(
  _$EnrolledCourseSummaryImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'slug': instance.slug,
  'coverImageUrl': instance.coverImageUrl,
};

_$EnrollmentWithCourseImpl _$$EnrollmentWithCourseImplFromJson(
  Map<String, dynamic> json,
) => _$EnrollmentWithCourseImpl(
  id: json['id'] as String,
  userId: json['userId'] as String,
  courseId: json['courseId'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  lastVideoId: json['lastVideoId'] as String?,
  lastPosMs: (json['lastPosMs'] as num?)?.toInt(),
  course: EnrolledCourseSummary.fromJson(
    json['course'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$$EnrollmentWithCourseImplToJson(
  _$EnrollmentWithCourseImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'courseId': instance.courseId,
  'startedAt': instance.startedAt.toIso8601String(),
  'lastVideoId': instance.lastVideoId,
  'lastPosMs': instance.lastPosMs,
  'course': instance.course,
};
