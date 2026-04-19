// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_analytics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PerCueTypeAccuracyImpl _$$PerCueTypeAccuracyImplFromJson(
  Map<String, dynamic> json,
) => _$PerCueTypeAccuracyImpl(
  mcq: (json['MCQ'] as num?)?.toDouble(),
  blanks: (json['BLANKS'] as num?)?.toDouble(),
  matching: (json['MATCHING'] as num?)?.toDouble(),
);

Map<String, dynamic> _$$PerCueTypeAccuracyImplToJson(
  _$PerCueTypeAccuracyImpl instance,
) => <String, dynamic>{
  'MCQ': instance.mcq,
  'BLANKS': instance.blanks,
  'MATCHING': instance.matching,
};

_$CourseAnalyticsImpl _$$CourseAnalyticsImplFromJson(
  Map<String, dynamic> json,
) => _$CourseAnalyticsImpl(
  totalViews: (json['totalViews'] as num).toInt(),
  completionRate: (json['completionRate'] as num).toDouble(),
  perCueTypeAccuracy: PerCueTypeAccuracy.fromJson(
    json['perCueTypeAccuracy'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$$CourseAnalyticsImplToJson(
  _$CourseAnalyticsImpl instance,
) => <String, dynamic>{
  'totalViews': instance.totalViews,
  'completionRate': instance.completionRate,
  'perCueTypeAccuracy': instance.perCueTypeAccuracy,
};
