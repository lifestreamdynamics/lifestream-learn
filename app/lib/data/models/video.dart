import 'package:freezed_annotation/freezed_annotation.dart';

part 'video.freezed.dart';
part 'video.g.dart';

/// A single caption track returned as part of [PlaybackInfo].
/// Represents a signed URL for a specific BCP-47 language track.
@freezed
class CaptionTrack with _$CaptionTrack {
  const factory CaptionTrack({
    required String language,
    required String url,
    required DateTime expiresAt,
  }) = _CaptionTrack;

  factory CaptionTrack.fromJson(Map<String, dynamic> json) =>
      _$CaptionTrackFromJson(json);
}

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
    @Default(<CaptionTrack>[]) List<CaptionTrack> captions,
    String? defaultCaptionLanguage,
  }) = _PlaybackInfo;

  factory PlaybackInfo.fromJson(Map<String, dynamic> json) =>
      _$PlaybackInfoFromJson(json);
}

/// Tusd upload coordinates returned by `POST /api/videos`. The `uploadUrl`
/// is the shared tusd endpoint; the `uploadHeaders` contain the
/// pre-baked `Upload-Metadata` line tusd's pre-finish hook decodes to
/// recover the `videoId`. The client may use `uploadHeaders` directly or,
/// equivalently, pass `{'videoId': videoId}` through the tus client's
/// `metadata:` param — tusd's permissive base64 decoder tolerates padded
/// and unpadded values alike.
///
/// Never log any field of this shape — the signed upload URL is bound to
/// the caller's bearer token until finalised.
@freezed
class VideoUploadTicket with _$VideoUploadTicket {
  const factory VideoUploadTicket({
    required String videoId,
    required VideoSummary video,
    required String uploadUrl,
    required Map<String, String> uploadHeaders,
    required String sourceKey,
  }) = _VideoUploadTicket;

  factory VideoUploadTicket.fromJson(Map<String, dynamic> json) =>
      _$VideoUploadTicketFromJson(json);
}
