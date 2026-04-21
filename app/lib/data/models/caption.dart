import 'package:freezed_annotation/freezed_annotation.dart';

part 'caption.freezed.dart';
part 'caption.g.dart';

/// Designer-side view of an uploaded caption track, returned by
/// `GET /api/videos/:videoId/captions`.
@freezed
class CaptionSummary with _$CaptionSummary {
  const factory CaptionSummary({
    required String language,
    required int bytes,
    required DateTime uploadedAt,
  }) = _CaptionSummary;

  factory CaptionSummary.fromJson(Map<String, dynamic> json) =>
      _$CaptionSummaryFromJson(json);
}

/// Confirmation payload returned by
/// `POST /api/videos/:videoId/captions`.
@freezed
class CaptionUploadResult with _$CaptionUploadResult {
  const factory CaptionUploadResult({
    required String language,
    required int bytes,
    required DateTime uploadedAt,
  }) = _CaptionUploadResult;

  factory CaptionUploadResult.fromJson(Map<String, dynamic> json) =>
      _$CaptionUploadResultFromJson(json);
}
