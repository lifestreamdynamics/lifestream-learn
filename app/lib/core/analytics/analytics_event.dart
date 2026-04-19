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
    String? videoId,
    String? cueId,
    Map<String, dynamic>? payload,
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
}
