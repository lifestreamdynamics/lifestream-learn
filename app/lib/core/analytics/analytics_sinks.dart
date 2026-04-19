import 'analytics_buffer.dart';
import 'analytics_event.dart';

/// Narrow hook the CueScheduler / cue widgets use to emit telemetry.
///
/// The scheduler/player code is wire-compatible with a no-op sink
/// (`NoopCueAnalyticsSink`), so existing unit tests keep passing without
/// changes. The `AnalyticsBufferSink` implementation in production wires
/// each hook to a structural-only `AnalyticsEvent` and hands it to the
/// buffer.
///
/// Contracts:
/// - Payloads are STRUCTURAL ONLY. No free text.
/// - Failures swallow cleanly; telemetry never blocks UX.
abstract class CueAnalyticsSink {
  /// Called when a cue overlay is mounted (scheduler's `activeCueNotifier`
  /// just flipped non-null).
  void onCueShown(String cueId, String cueType);

  /// Called when the learner submits a response. `correct` comes from
  /// the server's grading reply — the client never decides correctness.
  void onCueAnswered(String cueId, String cueType, bool correct);
}

abstract class VideoAnalyticsSink {
  /// Called exactly once, when the underlying player begins actually
  /// playing for the first time after the video is ready.
  void onVideoView(String videoId);

  /// Called exactly once per video per session, when the learner has
  /// reached 90% of the clip. `durationMs` is the video duration at the
  /// moment of detection (so the backend can disambiguate partial
  /// watches later if we want).
  void onVideoComplete(String videoId, int durationMs);
}

class NoopCueAnalyticsSink implements CueAnalyticsSink {
  const NoopCueAnalyticsSink();
  @override
  void onCueShown(String cueId, String cueType) {}
  @override
  void onCueAnswered(String cueId, String cueType, bool correct) {}
}

class NoopVideoAnalyticsSink implements VideoAnalyticsSink {
  const NoopVideoAnalyticsSink();
  @override
  void onVideoView(String videoId) {}
  @override
  void onVideoComplete(String videoId, int durationMs) {}
}

/// Production sink — emits events into an [AnalyticsBuffer].
class AnalyticsBufferCueSink implements CueAnalyticsSink {
  const AnalyticsBufferCueSink(this._buffer);
  final AnalyticsBuffer _buffer;

  @override
  void onCueShown(String cueId, String cueType) {
    _buffer.log(AnalyticsEvent(
      eventType: AnalyticsEventTypes.cueShown,
      occurredAt: DateTime.now().toUtc().toIso8601String(),
      cueId: cueId,
      payload: <String, dynamic>{'cueType': cueType},
    ));
  }

  @override
  void onCueAnswered(String cueId, String cueType, bool correct) {
    _buffer.log(AnalyticsEvent(
      eventType: AnalyticsEventTypes.cueAnswered,
      occurredAt: DateTime.now().toUtc().toIso8601String(),
      cueId: cueId,
      payload: <String, dynamic>{'cueType': cueType, 'correct': correct},
    ));
  }
}

class AnalyticsBufferVideoSink implements VideoAnalyticsSink {
  const AnalyticsBufferVideoSink(this._buffer);
  final AnalyticsBuffer _buffer;

  @override
  void onVideoView(String videoId) {
    _buffer.log(AnalyticsEvent(
      eventType: AnalyticsEventTypes.videoView,
      occurredAt: DateTime.now().toUtc().toIso8601String(),
      videoId: videoId,
      payload: const <String, dynamic>{},
    ));
  }

  @override
  void onVideoComplete(String videoId, int durationMs) {
    _buffer.log(AnalyticsEvent(
      eventType: AnalyticsEventTypes.videoComplete,
      occurredAt: DateTime.now().toUtc().toIso8601String(),
      videoId: videoId,
      payload: <String, dynamic>{'durationMs': durationMs},
    ));
  }
}
