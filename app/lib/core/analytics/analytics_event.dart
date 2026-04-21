import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_event.freezed.dart';
part 'analytics_event.g.dart';

/// Client-side shape of an analytics event before it's POSTed to
/// `/api/events`. Matches the backend's `AnalyticsEventInput` zod schema:
/// - `eventType`: required, max 64 chars; unknown values are accepted by
///   the backend so the client can introduce new kinds without a deploy.
/// - `occurredAt`: ISO8601 string. **Client clock** — the backend's
///   `receivedAt` column records the server clock separately. Analytics
///   queries prefer `occurredAt` (see ADR / data model notes).
/// - `videoId`, `cueId`: optional correlation ids.
/// - `payload`: structural-only. **Must never contain free-text learner
///   responses** — the buffer's privacy guard rejects such events.
@freezed
class AnalyticsEvent with _$AnalyticsEvent {
  const factory AnalyticsEvent({
    required String eventType,
    required String occurredAt,
    // Null-valued optional fields must be OMITTED from the JSON, not
    // serialized as `null`. The backend's Zod schema is `.strict()` and
    // its `.uuid().optional()` rejects an explicit `null` — `.optional()`
    // admits "key missing" / `undefined`, not `null`. Without this flag,
    // every session_start / session_end event 400s.
    @JsonKey(includeIfNull: false) String? videoId,
    @JsonKey(includeIfNull: false) String? cueId,
    @JsonKey(includeIfNull: false) Map<String, dynamic>? payload,
  }) = _AnalyticsEvent;

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsEventFromJson(json);
}

/// Known event kinds the Flutter app emits. Using constants (not an
/// enum) so the backend can accept new values we haven't modelled yet
/// without a breaking change.
class AnalyticsEventTypes {
  const AnalyticsEventTypes._();
  static const String sessionStart = 'session_start';
  static const String sessionEnd = 'session_end';
  static const String videoView = 'video_view';
  static const String videoComplete = 'video_complete';
  static const String cueShown = 'cue_shown';
  static const String cueAnswered = 'cue_answered';
  static const String captionLanguageSelected = 'caption_language_selected';
}
