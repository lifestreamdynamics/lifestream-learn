import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/analytics/analytics_sinks.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/data/repositories/attempt_repository.dart';
import 'package:lifestream_learn_app/data/repositories/cue_repository.dart';
import 'package:lifestream_learn_app/data/repositories/enrollment_repository.dart';
import 'package:lifestream_learn_app/data/repositories/video_repository.dart';
import 'package:lifestream_learn_app/features/feed/feed_screen.dart';
import 'package:lifestream_learn_app/features/feed/video_controller_cache.dart';
import 'package:lifestream_learn_app/features/player/learn_video_player.dart';
import 'package:lifestream_learn_app/features/player/video_with_cues_screen.dart';
import 'package:mocktail/mocktail.dart';

// Regression guard for the plan-validation finding:
// AnalyticsBufferCueSink / AnalyticsBufferVideoSink were defined but
// never plumbed into the playback/cue stack — cue_shown / cue_answered /
// video_view / video_complete silently landed in a NoopSink. These tests
// lock in the constructor contract so a future refactor that drops a sink
// parameter fails here instead of silently going dead.

class _VR extends Mock implements VideoRepository {}

class _ER extends Mock implements EnrollmentRepository {}

class _CR extends Mock implements CueRepository {}

class _AR extends Mock implements AttemptRepository {}

class _RecordingCueSink implements CueAnalyticsSink {
  final List<String> shown = [];
  final List<(String, String, bool)> answered = [];

  @override
  void onCueShown(String cueId, String cueType) => shown.add(cueId);

  @override
  void onCueAnswered(String cueId, String cueType, bool correct) =>
      answered.add((cueId, cueType, correct));
}

class _RecordingVideoSink implements VideoAnalyticsSink {
  final List<String> views = [];
  final List<(String, int)> completes = [];

  @override
  void onVideoView(String videoId) => views.add(videoId);

  @override
  void onVideoComplete(String videoId, int durationMs) =>
      completes.add((videoId, durationMs));
}

void main() {
  final fakeVideo = VideoSummary(
    id: 'v1',
    courseId: 'c1',
    title: 't',
    orderIndex: 0,
    status: VideoStatus.ready,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  test('LearnVideoPlayer accepts a VideoAnalyticsSink and stores it', () {
    final sink = _RecordingVideoSink();
    final player = LearnVideoPlayer(
      video: fakeVideo,
      courseId: 'c1',
      videoRepo: _VR(),
      enrollmentRepo: _ER(),
      controllerCache: VideoControllerCache(capacity: 1),
      analyticsSink: sink,
    );
    // The field is final; reading it confirms the constructor wired it.
    expect(identical(player.analyticsSink, sink), isTrue);
  });

  test('FeedScreen accepts a VideoAnalyticsSink (default Noop)', () {
    final sink = _RecordingVideoSink();
    final screen = FeedScreen(
      videoRepo: _VR(),
      enrollmentRepo: _ER(),
      videoAnalyticsSink: sink,
    );
    expect(identical(screen.videoAnalyticsSink, sink), isTrue);

    final defaultScreen = FeedScreen(
      videoRepo: _VR(),
      enrollmentRepo: _ER(),
    );
    expect(defaultScreen.videoAnalyticsSink, isA<NoopVideoAnalyticsSink>());
  });

  test('VideoWithCuesScreen accepts both sinks (default Noop)', () {
    final cueSink = _RecordingCueSink();
    final videoSink = _RecordingVideoSink();
    final screen = VideoWithCuesScreen(
      videoId: 'v1',
      videoRepo: _VR(),
      cueRepo: _CR(),
      attemptRepo: _AR(),
      enrollmentRepo: _ER(),
      cueAnalyticsSink: cueSink,
      videoAnalyticsSink: videoSink,
    );
    expect(identical(screen.cueAnalyticsSink, cueSink), isTrue);
    expect(identical(screen.videoAnalyticsSink, videoSink), isTrue);

    final defaultScreen = VideoWithCuesScreen(
      videoId: 'v1',
      videoRepo: _VR(),
      cueRepo: _CR(),
      attemptRepo: _AR(),
      enrollmentRepo: _ER(),
    );
    expect(defaultScreen.cueAnalyticsSink, isA<NoopCueAnalyticsSink>());
    expect(defaultScreen.videoAnalyticsSink, isA<NoopVideoAnalyticsSink>());
  });
}
