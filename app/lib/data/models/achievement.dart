import 'package:freezed_annotation/freezed_annotation.dart';

part 'achievement.freezed.dart';
part 'achievement.g.dart';

/// Slice P3 — a single achievement row from `GET /api/me/achievements`.
///
/// `criteriaJson` is a discriminated-union map driven by `type`:
/// - `{"type":"lessons_completed","count":1}`
/// - `{"type":"streak","days":7}`
/// - `{"type":"perfect_lesson"}`
/// - `{"type":"course_complete"}`
/// - `{"type":"cues_correct","count":100}`
/// - `{"type":"cues_correct_by_type","cueType":"MCQ","count":25}`
///
/// The client does not render criteria directly today; the value is kept
/// on the model so a future slice can show a progress hint ("3 more
/// cues") without another API call.
///
/// `iconKey` is a Material icon identifier the widget layer maps to an
/// [IconData] — we avoid sending glyphs over the wire.
@freezed
class Achievement with _$Achievement {
  const factory Achievement({
    required String id,
    required String title,
    required String description,
    required String iconKey,
    required Map<String, dynamic> criteriaJson,
  }) = _Achievement;

  factory Achievement.fromJson(Map<String, dynamic> json) =>
      _$AchievementFromJson(json);
}

/// Full response of `GET /api/me/achievements` — the static catalog
/// partitioned by the caller's unlock set, plus a `unlockedAt` lookup.
@freezed
class AchievementsResponse with _$AchievementsResponse {
  const factory AchievementsResponse({
    required List<Achievement> unlocked,
    required List<Achievement> locked,
    // Server sends `{ [slug]: ISO-8601 }`; freezed+json_serializable
    // decode to `DateTime` per-value. Map<String, DateTime> on the client.
    required Map<String, DateTime> unlockedAtByAchievementId,
  }) = _AchievementsResponse;

  factory AchievementsResponse.fromJson(Map<String, dynamic> json) =>
      _$AchievementsResponseFromJson(json);
}

/// Compact achievement pointer used by `OverallProgress.recentlyUnlocked`.
/// Distinct from [Achievement] because the progress endpoint returns a
/// *slimmer* payload — just what's needed for the SnackBar toast.
@freezed
class AchievementSummary with _$AchievementSummary {
  const factory AchievementSummary({
    required String id,
    required String title,
    required String iconKey,
    required DateTime unlockedAt,
  }) = _AchievementSummary;

  factory AchievementSummary.fromJson(Map<String, dynamic> json) =>
      _$AchievementSummaryFromJson(json);
}
