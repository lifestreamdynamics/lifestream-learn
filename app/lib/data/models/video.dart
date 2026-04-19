import 'package:freezed_annotation/freezed_annotation.dart';

part 'video.freezed.dart';
part 'video.g.dart';

/// Status mirror of Prisma `VideoStatus`. Only `READY` is playable; anything
/// else should be treated as "not yet available" by the UI.
enum VideoStatus {
  @JsonValue('UPLOADING')
  uploading,
  @JsonValue('TRANSCODING')
  transcoding,
  @JsonValue('READY')
  ready,
  @JsonValue('FAILED')
  failed,
}

/// Full video metadata returned by `GET /api/videos/:id` and embedded in
/// feed entries (minus `updatedAt`, which the feed omits — defaulted to
/// `createdAt` there). Matches the backend's `PublicVideo` shape.
@freezed
class VideoSummary with _$VideoSummary {
  const factory VideoSummary({
    required String id,
    required String courseId,
    required String title,
    required int orderIndex,
    required VideoStatus status,
    int? durationMs,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _VideoSummary;

  factory VideoSummary.fromJson(Map<String, dynamic> json) =>
      _$VideoSummaryFromJson(json);
}

/// Nested video summary returned inside a course detail response
/// (`GET /api/courses/:id`). No `courseId` or `createdAt` fields — the
/// parent `CourseDetail` carries the course context.
@freezed
class CourseVideoSummary with _$CourseVideoSummary {
  const factory CourseVideoSummary({
    required String id,
    required String title,
    required int orderIndex,
    required VideoStatus status,
    int? durationMs,
  }) = _CourseVideoSummary;

  factory CourseVideoSummary.fromJson(Map<String, dynamic> json) =>
      _$CourseVideoSummaryFromJson(json);
}

/// Signed playback coordinates. `expiresAt` is the absolute instant the
/// master-playlist HMAC token stops validating at nginx; we refresh a
/// minute or two before it with a 5-minute safety margin in
/// `VideoRepository`.
@freezed
class PlaybackInfo with _$PlaybackInfo {
  const factory PlaybackInfo({
    required String masterPlaylistUrl,
    required DateTime expiresAt,
  }) = _PlaybackInfo;

  factory PlaybackInfo.fromJson(Map<String, dynamic> json) =>
      _$PlaybackInfoFromJson(json);
}
