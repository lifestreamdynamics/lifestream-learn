import 'package:freezed_annotation/freezed_annotation.dart';

import 'achievement.dart';
import 'cue.dart';

part 'progress.freezed.dart';
part 'progress.g.dart';

/// Server-side grade letter. The API is the single source of truth for
/// the accuracy -> letter mapping (A ≥90%, B ≥80%, C ≥70%, D ≥60%,
/// else F). The client never re-derives it. `null` on the wire = "no
/// attempts yet" — we keep the Dart type as `Grade?` and treat `null`
/// as the empty state.
enum Grade {
  @JsonValue('A')
  a,
  @JsonValue('B')
  b,
  @JsonValue('C')
  c,
  @JsonValue('D')
  d,
  @JsonValue('F')
  f,
}

extension GradeX on Grade {
  /// Uppercase single-letter label — what we display in chips.
  String get label {
    switch (this) {
      case Grade.a:
        return 'A';
      case Grade.b:
        return 'B';
      case Grade.c:
        return 'C';
      case Grade.d:
        return 'D';
      case Grade.f:
        return 'F';
    }
  }
}

/// Top-level numbers for the profile dashboard's "overview" card.
@freezed
class ProgressSummary with _$ProgressSummary {
  const factory ProgressSummary({
    required int coursesEnrolled,
    required int lessonsCompleted,
    required int totalCuesAttempted,
    required int totalCuesCorrect,
    double? overallAccuracy,
    Grade? overallGrade,
    required int totalWatchTimeMs,
    // Slice P3 — streak counts in the learner's local timezone. Defaults
    // accommodate older cached payloads / older API builds that don't
    // yet emit these fields (rolling-deploy safety).
    @Default(0) int currentStreak,
    @Default(0) int longestStreak,
  }) = _ProgressSummary;

  factory ProgressSummary.fromJson(Map<String, dynamic> json) =>
      _$ProgressSummaryFromJson(json);
}

/// Nested course-progress tile — same shape as `CourseProgressDetail`
/// minus the `lessons` array. The overall-progress endpoint embeds this
/// per enrollment.
@freezed
class CourseProgressSummary with _$CourseProgressSummary {
  const factory CourseProgressSummary({
    required CourseTile course,
    required int videosTotal,
    required int videosCompleted,
    required double completionPct,
    required int cuesAttempted,
    required int cuesCorrect,
    double? accuracy,
    Grade? grade,
    String? lastVideoId,
    int? lastPosMs,
  }) = _CourseProgressSummary;

  factory CourseProgressSummary.fromJson(Map<String, dynamic> json) =>
      _$CourseProgressSummaryFromJson(json);
}

/// Minimal course chip for progress views. Matches the backend's inlined
/// shape (slimmer than `CourseDetail`).
@freezed
class CourseTile with _$CourseTile {
  const factory CourseTile({
    required String id,
    required String title,
    required String slug,
    String? coverImageUrl,
  }) = _CourseTile;

  factory CourseTile.fromJson(Map<String, dynamic> json) =>
      _$CourseTileFromJson(json);
}

/// Per-lesson row inside a `CourseProgressDetail`.
@freezed
class LessonProgressSummary with _$LessonProgressSummary {
  const factory LessonProgressSummary({
    required String videoId,
    required String title,
    required int orderIndex,
    int? durationMs,
    required int cueCount,
    required int cuesAttempted,
    required int cuesCorrect,
    double? accuracy,
    Grade? grade,
    required bool completed,
  }) = _LessonProgressSummary;

  factory LessonProgressSummary.fromJson(Map<String, dynamic> json) =>
      _$LessonProgressSummaryFromJson(json);
}

/// Detail view for a single course (headline numbers + lesson breakdown).
/// Shares the common `CourseProgressSummary` fields plus a `lessons` list.
@freezed
class CourseProgressDetail with _$CourseProgressDetail {
  const factory CourseProgressDetail({
    required CourseTile course,
    required int videosTotal,
    required int videosCompleted,
    required double completionPct,
    required int cuesAttempted,
    required int cuesCorrect,
    double? accuracy,
    Grade? grade,
    String? lastVideoId,
    int? lastPosMs,
    required List<LessonProgressSummary> lessons,
  }) = _CourseProgressDetail;

  factory CourseProgressDetail.fromJson(Map<String, dynamic> json) =>
      _$CourseProgressDetailFromJson(json);
}

/// Full overview returned by `GET /api/me/progress`.
@freezed
class OverallProgress with _$OverallProgress {
  const factory OverallProgress({
    required ProgressSummary summary,
    required List<CourseProgressSummary> perCourse,
    // Slice P3 — achievements that newly unlocked on THIS response. The
    // client pops a SnackBar per entry then drops the field; it is not
    // a persistent list. Defaulted so older API builds that don't yet
    // emit the field don't crash the decoder.
    @Default(<AchievementSummary>[])
    List<AchievementSummary> recentlyUnlocked,
  }) = _OverallProgress;

  factory OverallProgress.fromJson(Map<String, dynamic> json) =>
      _$OverallProgressFromJson(json);
}

/// Compact video reference used in the lesson review view.
@freezed
class LessonVideoRef with _$LessonVideoRef {
  const factory LessonVideoRef({
    required String id,
    required String title,
    required int orderIndex,
    int? durationMs,
    required String courseId,
  }) = _LessonVideoRef;

  factory LessonVideoRef.fromJson(Map<String, dynamic> json) =>
      _$LessonVideoRefFromJson(json);
}

/// Lesson-review score summary (the top-of-screen header on the review
/// page).
@freezed
class LessonScore with _$LessonScore {
  const factory LessonScore({
    required int cuesAttempted,
    required int cuesCorrect,
    double? accuracy,
    Grade? grade,
  }) = _LessonScore;

  factory LessonScore.fromJson(Map<String, dynamic> json) =>
      _$LessonScoreFromJson(json);
}

/// Per-cue outcome the review screen renders one tile per.
///
/// SECURITY: the server only populates [correctAnswerSummary] for cues
/// the learner has already attempted. The client MUST NOT speculatively
/// render a correct answer when [attempted] is false — the CueOutcomeTile
/// widget belts-and-braces this with an explicit null check, but the
/// invariant lives on the server.
@freezed
class CueOutcome with _$CueOutcome {
  const factory CueOutcome({
    required String cueId,
    required int atMs,
    required CueType type,
    required String prompt,
    required bool attempted,
    bool? correct,
    Map<String, dynamic>? scoreJson,
    DateTime? submittedAt,
    String? explanation,
    String? yourAnswerSummary,
    String? correctAnswerSummary,
  }) = _CueOutcome;

  factory CueOutcome.fromJson(Map<String, dynamic> json) =>
      _$CueOutcomeFromJson(json);
}

/// Response of `GET /api/me/progress/lessons/:videoId`.
@freezed
class LessonReview with _$LessonReview {
  const factory LessonReview({
    required LessonVideoRef video,
    required CourseTile course,
    required LessonScore score,
    required List<CueOutcome> cues,
  }) = _LessonReview;

  factory LessonReview.fromJson(Map<String, dynamic> json) =>
      _$LessonReviewFromJson(json);
}
