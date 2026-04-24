import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/analytics/analytics_sinks.dart';
import '../../data/models/cue.dart';
import '../../data/models/video.dart';
import '../../data/repositories/attempt_repository.dart';
import '../../data/repositories/cue_repository.dart';
import '../../data/repositories/enrollment_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../features/cues/cue_overlay_host.dart';
import '../feed/video_controller_cache.dart';
import 'cue_scheduler.dart';
import 'fullscreen_player_page.dart';
import 'learn_video_player.dart';

/// Full-screen "watch with cues" experience. Fetches the video metadata
/// + cue list, constructs a `CueScheduler` once the underlying
/// controller is ready, and renders the player stacked under a
/// `CueOverlayHost`.
///
/// Routed at `/videos/:id/watch`. Used by the feed's tap-to-deep-link
/// path (the feed's inline playback stays lightweight; cue enforcement
/// happens here).
class VideoWithCuesScreen extends StatefulWidget {
  const VideoWithCuesScreen({
    required this.videoId,
    required this.videoRepo,
    required this.cueRepo,
    required this.attemptRepo,
    required this.enrollmentRepo,
    this.initialPosition,
    this.controllerCache,
    this.cueAnalyticsSink = const NoopCueAnalyticsSink(),
    this.videoAnalyticsSink = const NoopVideoAnalyticsSink(),
    super.key,
  });

  final String videoId;
  final VideoRepository videoRepo;
  final CueRepository cueRepo;
  final AttemptRepository attemptRepo;
  final EnrollmentRepository enrollmentRepo;

  /// Slice P2 — when the screen is entered via a Resume deep-link
  /// (`/videos/:id/watch?t=<ms>`), this carries the starting position.
  /// We seek to it once the controller is ready. A null value (the
  /// common case, launched from the feed) means "start from the
  /// natural position the controller already has".
  final Duration? initialPosition;

  /// Optional shared cache so the screen can share controllers with the
  /// feed's cache. If null, a dedicated cache with capacity=1 is used.
  final VideoControllerCache? controllerCache;

  /// Telemetry sinks — passed into the CueScheduler and LearnVideoPlayer.
  /// Default Noop so tests that don't care about analytics keep working.
  final CueAnalyticsSink cueAnalyticsSink;
  final VideoAnalyticsSink videoAnalyticsSink;

  @override
  State<VideoWithCuesScreen> createState() => _VideoWithCuesScreenState();
}

class _VideoWithCuesScreenState extends State<VideoWithCuesScreen>
    with WidgetsBindingObserver {
  VideoSummary? _video;
  List<Cue>? _cues;
  String? _error;
  CueScheduler? _scheduler;

  /// Cached once the underlying player hands us the ready controller.
  /// Used by [_onFullscreenRequested] to pass the same controller to
  /// [FullscreenPlayerPage] without creating a new one.
  VideoPlayerController? _controller;

  late final VideoControllerCache _cache;

  @override
  void initState() {
    super.initState();
    _cache = widget.controllerCache ?? VideoControllerCache(capacity: 1);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduler?.dispose();
    if (widget.controllerCache == null) {
      _cache.evictAll();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = _scheduler;
    if (s == null) return;
    if (state == AppLifecycleState.paused) {
      unawaited(s.onAppPaused());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(s.onAppResumed());
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.videoRepo.get(widget.videoId),
        widget.cueRepo.listForVideo(widget.videoId),
      ]);
      if (!mounted) return;
      setState(() {
        _video = results[0] as VideoSummary;
        _cues = results[1] as List<Cue>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _onControllerReady(VideoPlayerController controller) {
    _controller = controller;
    final cues = _cues;
    if (cues == null) return;
    if (_scheduler != null) return;
    // Slice P2 — seek to the deep-link target (`?t=<ms>`) if one was
    // supplied. We do this BEFORE starting the scheduler so the first
    // cue evaluation happens against the seeked position rather than
    // the natural start. Fire-and-forget: a seek failure shouldn't
    // block playback; worst case the user starts from the top.
    final initial = widget.initialPosition;
    if (initial != null) {
      final duration = controller.value.duration;
      final clamped = (duration > Duration.zero && initial > duration)
          ? duration
          : initial;
      unawaited(controller.seekTo(clamped));
    }
    final scheduler = CueScheduler(
      controller: controller,
      cues: cues,
      videoId: widget.videoId,
      analyticsSink: widget.cueAnalyticsSink,
    );
    scheduler.start();
    setState(() => _scheduler = scheduler);
  }

  /// Pushes [FullscreenPlayerPage] using the already-initialised controller.
  void _onFullscreenRequested() {
    final controller = _controller;
    if (controller == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenPlayerPage(
          controller: controller,
          scheduler: _scheduler,
          attemptRepo: widget.attemptRepo,
          title: _video?.title ?? '',
        ),
      ),
    );
  }

  /// Wraps [child] in a [PopScope] that navigates back via GoRouter's feed
  /// route when there is no route to pop — prevents exiting the app when
  /// arriving cold via a deep-link.
  Widget _wrapWithBackGuard(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/feed');
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final cues = _cues;
    if (_error != null) {
      return _wrapWithBackGuard(
        Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!),
            ),
          ),
        ),
      );
    }
    if (video == null || cues == null) {
      return _wrapWithBackGuard(
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final scheduler = _scheduler;
    final player = _CueAwareLearnPlayer(
      video: video,
      videoRepo: widget.videoRepo,
      enrollmentRepo: widget.enrollmentRepo,
      cache: _cache,
      onControllerReady: _onControllerReady,
      onFullscreenRequested: _onFullscreenRequested,
      videoAnalyticsSink: widget.videoAnalyticsSink,
      cues: cues,
    );
    return _wrapWithBackGuard(
      Scaffold(
        appBar: AppBar(
          title: Text(video.title),
        ),
        body: scheduler == null
            ? player
            : CueOverlayHost(
                scheduler: scheduler,
                attemptRepo: widget.attemptRepo,
                child: player,
              ),
      ),
    );
  }
}

/// Thin wrapper that exposes the `VideoPlayerController` to the parent
/// as soon as `LearnVideoPlayer` has it initialised — `LearnVideoPlayer`
/// doesn't surface its controller directly, so we piggy-back on the
/// `controllerCache` it shares with us: after the player is mounted,
/// we poll the cache until it has an entry for this videoId.
class _CueAwareLearnPlayer extends StatefulWidget {
  const _CueAwareLearnPlayer({
    required this.video,
    required this.videoRepo,
    required this.enrollmentRepo,
    required this.cache,
    required this.onControllerReady,
    required this.videoAnalyticsSink,
    required this.cues,
    this.onFullscreenRequested,
  });

  final VideoSummary video;
  final VideoRepository videoRepo;
  final EnrollmentRepository enrollmentRepo;
  final VideoControllerCache cache;
  final ValueChanged<VideoPlayerController> onControllerReady;
  final VideoAnalyticsSink videoAnalyticsSink;
  final List<Cue> cues;
  final VoidCallback? onFullscreenRequested;

  @override
  State<_CueAwareLearnPlayer> createState() => _CueAwareLearnPlayerState();
}

class _CueAwareLearnPlayerState extends State<_CueAwareLearnPlayer> {
  Timer? _controllerWatcher;

  @override
  void initState() {
    super.initState();
    _controllerWatcher = Timer.periodic(
      const Duration(milliseconds: 100),
      (t) async {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (!widget.cache.contains(widget.video.id)) return;
        // Retrieve controller (no-op create since cache already has it).
        // The URL here is only used if the cache misses — it won't.
        try {
          final controller =
              await widget.cache.getOrCreate(widget.video.id, '');
          if (!mounted) return;
          t.cancel();
          _controllerWatcher = null;
          widget.onControllerReady(controller);
        } catch (_) {
          // Ignore; the cache may have raced an eviction.
        }
      },
    );
  }

  @override
  void dispose() {
    _controllerWatcher?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LearnVideoPlayer(
      video: widget.video,
      courseId: widget.video.courseId,
      videoRepo: widget.videoRepo,
      enrollmentRepo: widget.enrollmentRepo,
      controllerCache: widget.cache,
      analyticsSink: widget.videoAnalyticsSink,
      onFullscreenRequested: widget.onFullscreenRequested,
      cues: widget.cues,
    );
  }
}
