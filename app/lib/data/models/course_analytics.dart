import 'package:freezed_annotation/freezed_annotation.dart';

part 'course_analytics.freezed.dart';
part 'course_analytics.g.dart';

/// Per-cue-type accuracy bucket. `null` means "no attempts recorded yet"
/// — the admin screen renders that distinct from "0% accuracy".
///
/// Serialized key = backend `CueType` enum value (`MCQ`, `BLANKS`,
/// `MATCHING`). We intentionally omit `VOICE` here because the backend
/// rejects VOICE writes (ADR 0004) — if one ever lands in the wire
/// payload we ignore it.
@freezed
class PerCueTypeAccuracy with _$PerCueTypeAccuracy {
  const factory PerCueTypeAccuracy({
    @JsonKey(name: 'MCQ') double? mcq,
    @JsonKey(name: 'BLANKS') double? blanks,
    @JsonKey(name: 'MATCHING') double? matching,
  }) = _PerCueTypeAccuracy;

  factory PerCueTypeAccuracy.fromJson(Map<String, dynamic> json) =>
      _$PerCueTypeAccuracyFromJson(json);
}

/// `GET /api/admin/analytics/courses/:id` response.
///
/// `completionRate` is a 0..1 fraction (MVP approximation — see
/// `analytics.service.ts` in the backend for the exact definition).
@freezed
class CourseAnalytics with _$CourseAnalytics {
  const factory CourseAnalytics({
    required int totalViews,
    required double completionRate,
    required PerCueTypeAccuracy perCueTypeAccuracy,
  }) = _CourseAnalytics;

  factory CourseAnalytics.fromJson(Map<String, dynamic> json) =>
      _$CourseAnalyticsFromJson(json);
}
