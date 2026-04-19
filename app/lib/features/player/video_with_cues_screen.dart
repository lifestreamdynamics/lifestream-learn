import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/cue.dart';
import '../../data/models/video.dart';
import '../../data/repositories/attempt_repository.dart';
import '../../data/repositories/cue_repository.dart';
import '../../data/repositories/enrollment_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../features/cues/cue_overlay_host.dart';
import '../feed/video_controller_cache.dart';
import 'cue_scheduler.dart';
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
    this.controllerCache,
    super.key,
  });

  final String videoId;
  final VideoRepository videoRepo;
  final CueRepository cueRepo;
  final AttemptRepository attemptRepo;
  final EnrollmentRepository enrollmentRepo;

  /// Optional shared cache so the screen can share controllers with the
  /// feed's cache. If null, a dedicated cache with capacity=1 is used.
  final VideoControllerCache? controllerCache;

  @override
  State<VideoWithCuesScreen> createState() => _VideoWithCuesScreenState();
}

class _VideoWithCuesScreenState extends State<VideoWithCuesScreen>
    with WidgetsBindingObserver {
  VideoSummary? _video;
  List<Cue>? _cues;
  String? _error;
  CueScheduler? _scheduler;
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
    final cues = _cues;
    if (cues == null) return;
    if (_scheduler != null) return;
    final scheduler = CueScheduler(
      controller: controller,
      cues: cues,
      videoId: widget.videoId,
    );
    scheduler.start();
    setState(() => _scheduler = scheduler);
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final cues = _cues;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!),
          ),
        ),
      );
    }
    if (video == null || cues == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scheduler = _scheduler;
    final player = _CueAwareLearnPlayer(
      video: video,
      videoRepo: widget.videoRepo,
      enrollmentRepo: widget.enrollmentRepo,
      cache: _cache,
      onControllerReady: _onControllerReady,
    );
    return Scaffold(
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
  });

  final VideoSummary video;
  final VideoRepository videoRepo;
  final EnrollmentRepository enrollmentRepo;
  final VideoControllerCache cache;
  final ValueChanged<VideoPlayerController> onControllerReady;

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
    );
  }
}
