import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/analytics/analytics_sinks.dart';
import '../../core/http/error_envelope.dart';
import '../../data/models/video.dart';
import '../../data/repositories/enrollment_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../feed/video_controller_cache.dart';

/// Vertical-feed video player. Owns:
/// - Resolving the signed playback URL (via `VideoRepository`, cached).
/// - Getting / creating a `VideoPlayerController` via the shared cache.
/// - Visibility-driven play/pause (`visibleFraction >= 0.5` plays).
/// - Tap toggle / double-tap seek / long-press scrubber overlay.
/// - 5-second debounced progress ping (fire-and-forget).
/// - Error taxonomy: CONFLICT (not READY) → inline processing;
///   UNAUTHORIZED/FORBIDDEN → full-screen with "go home" CTA;
///   404 → inline "unavailable" with back button.
///
/// Not owned: cue scheduling (Slice E) — the constructor takes an
/// optional `cueScheduler` slot to make that retrofit trivial.
class LearnVideoPlayer extends StatefulWidget {
  const LearnVideoPlayer({
    required this.video,
    required this.courseId,
    required this.videoRepo,
    required this.enrollmentRepo,
    required this.controllerCache,
    this.onError,
    this.autoPlayWhenVisible = true,
    this.analyticsSink,
    super.key,
  });

  final VideoSummary video;
  final String courseId;
  final VideoRepository videoRepo;
  final EnrollmentRepository enrollmentRepo;
  final VideoControllerCache controllerCache;
  final VoidCallback? onError;

  /// When false, the player won't auto-play even if visible. Used by
  /// widget tests and by future (Slice E) designer preview that wants
  /// manual play control.
  final bool autoPlayWhenVisible;

  /// Optional analytics hook. When provided, emits `video_view` on the
  /// first playback start and `video_complete` once per video per
  /// instance at 90% watched. Defaults to no-op — existing tests don't
  /// need to wire it up.
  final VideoAnalyticsSink? analyticsSink;

  @override
  State<LearnVideoPlayer> createState() => _LearnVideoPlayerState();
}

enum _PlayerErrorKind { processing, unavailable, forbidden, unknown }

class _LearnVideoPlayerState extends State<LearnVideoPlayer> {
  VideoPlayerController? _controller;
  _PlayerErrorKind? _errorKind;
  String? _errorMessage;
  bool _loading = true;
  bool _isVisible = false;

  /// Overlay play/pause fade.
  double _overlayOpacity = 0;
  Timer? _overlayHideTimer;

  /// Long-press scrubber overlay.
  bool _scrubberVisible = false;
  Timer? _scrubberTick;
  double _scrubberPos = 0;

  /// Debounced progress ping.
  DateTime _lastProgressSent = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _progressInterval = Duration(seconds: 5);

  /// Latch: fire `video_view` exactly once per mount, on the first tick
  /// where the controller reports `isPlaying` true.
  bool _viewLogged = false;

  /// Latch: fire `video_complete` exactly once per mount, at 90%.
  bool _completeLogged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LearnVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _tearDownListener();
      setState(() {
        _controller = null;
        _loading = true;
        _errorKind = null;
        _errorMessage = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final playback = await widget.videoRepo.playback(widget.video.id);
      final controller = await widget.controllerCache
          .getOrCreate(widget.video.id, playback.masterPlaylistUrl);
      if (!mounted) return;
      controller.addListener(_onControllerTick);
      if (!controller.value.isInitialized) {
        // getOrCreate awaits initialize(); a false here means creation
        // raced with eviction — bail gracefully.
        setState(() {
          _loading = false;
          _errorKind = _PlayerErrorKind.unknown;
          _errorMessage = 'Player failed to initialise';
        });
        return;
      }
      controller.setLooping(true);
      setState(() {
        _controller = controller;
        _loading = false;
      });
      if (widget.autoPlayWhenVisible && _isVisible) {
        await controller.play();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      widget.onError?.call();
      setState(() {
        _loading = false;
        _errorMessage = e.message;
        _errorKind = _mapError(e);
      });
    } catch (e) {
      if (!mounted) return;
      widget.onError?.call();
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
        _errorKind = _PlayerErrorKind.unknown;
      });
    }
  }

  _PlayerErrorKind _mapError(ApiException e) {
    switch (e.code) {
      case 'CONFLICT':
        return _PlayerErrorKind.processing;
      case 'UNAUTHORIZED':
      case 'FORBIDDEN':
        return _PlayerErrorKind.forbidden;
      case 'NOT_FOUND':
        return _PlayerErrorKind.unavailable;
      default:
        return _PlayerErrorKind.unknown;
    }
  }

  void _onControllerTick() {
    final c = _controller;
    if (c == null) return;
    final value = c.value;
    if (_scrubberVisible) {
      _scrubberPos = value.position.inMilliseconds.toDouble();
    }
    if (value.isPlaying) {
      // One-shot view log on the first tick that reports playing.
      if (!_viewLogged) {
        _viewLogged = true;
        try {
          widget.analyticsSink?.onVideoView(widget.video.id);
        } catch (_) {
          /* telemetry never breaks playback */
        }
      }
      final now = DateTime.now();
      if (now.difference(_lastProgressSent) >= _progressInterval) {
        _lastProgressSent = now;
        // Fire-and-forget; repo swallows errors.
        unawaited(widget.enrollmentRepo.updateProgress(
          widget.courseId,
          widget.video.id,
          value.position.inMilliseconds,
        ));
      }
    }
    // video_complete at >= 90%, debounced to once per mount.
    if (!_completeLogged) {
      final durMs = value.duration.inMilliseconds;
      final posMs = value.position.inMilliseconds;
      if (durMs > 0 && posMs >= (durMs * 0.9).floor()) {
        _completeLogged = true;
        try {
          widget.analyticsSink?.onVideoComplete(widget.video.id, durMs);
        } catch (_) {
          /* telemetry never breaks playback */
        }
      }
    }
  }

  void _tearDownListener() {
    _controller?.removeListener(_onControllerTick);
  }

  @override
  void dispose() {
    _tearDownListener();
    _overlayHideTimer?.cancel();
    _scrubberTick?.cancel();
    // Controllers live in the shared cache — do NOT dispose here.
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final nowVisible = info.visibleFraction >= 0.5;
    if (nowVisible == _isVisible) return;
    _isVisible = nowVisible;
    final c = _controller;
    if (c == null) return;
    if (nowVisible) {
      if (widget.autoPlayWhenVisible) {
        unawaited(c.play());
      }
    } else {
      unawaited(c.pause());
    }
  }

  void _toggleOverlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      unawaited(c.pause());
    } else {
      unawaited(c.play());
    }
    setState(() => _overlayOpacity = 1);
    _overlayHideTimer?.cancel();
    _overlayHideTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _overlayOpacity = 0);
    });
  }

  void _seekBy(Duration delta) {
    final c = _controller;
    if (c == null) return;
    final current = c.value.position;
    final target = current + delta;
    final duration = c.value.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    unawaited(c.seekTo(clamped));
  }

  void _showScrubber() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      _scrubberVisible = true;
      _scrubberPos = c.value.position.inMilliseconds.toDouble();
    });
    _scrubberTick?.cancel();
    _scrubberTick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_scrubberVisible) return;
      final ctrl = _controller;
      if (ctrl == null) return;
      setState(() {
        _scrubberPos = ctrl.value.position.inMilliseconds.toDouble();
      });
    });
  }

  void _hideScrubber() {
    _scrubberTick?.cancel();
    if (!mounted) return;
    setState(() => _scrubberVisible = false);
  }

  void _onScrubberChanged(double valueMs) {
    _scrubberPos = valueMs;
    unawaited(_controller?.seekTo(Duration(milliseconds: valueMs.toInt())));
  }

  Future<void> _retryLoad() async {
    widget.videoRepo.invalidate(widget.video.id);
    await widget.controllerCache.evict(widget.video.id);
    setState(() {
      _loading = true;
      _errorKind = null;
      _errorMessage = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey<String>('learn_video.${widget.video.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorKind != null) {
      return _buildError(context);
    }
    final c = _controller;
    if (c == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final duration = c.value.duration.inMilliseconds.toDouble();
    return GestureDetector(
      onTap: _toggleOverlay,
      onLongPressStart: (_) => _showScrubber(),
      onLongPressEnd: (_) => _hideScrubber(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          // Double-tap seek — full-height left / right zones on top of
          // the player but below the overlay.
          Row(children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: () => _seekBy(const Duration(seconds: -10)),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: () => _seekBy(const Duration(seconds: 10)),
              ),
            ),
          ]),
          // Play/pause overlay fade.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _overlayOpacity,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Icon(
                  c.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          // Title / course chrome.
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.video.title,
                  key: const Key('player.title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Long-press scrubber.
          if (_scrubberVisible && duration > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 72,
              child: Slider(
                key: const Key('player.scrubber'),
                min: 0,
                max: duration,
                value: _scrubberPos.clamp(0, duration).toDouble(),
                onChanged: _onScrubberChanged,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    switch (_errorKind!) {
      case _PlayerErrorKind.processing:
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_empty,
                    color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Processing…',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  key: const Key('player.retry'),
                  onPressed: _retryLoad,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),
        );
      case _PlayerErrorKind.forbidden:
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'You do not have access to this video',
                  key: const Key('player.forbidden'),
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => GoRouter.of(context).go('/feed'),
                  child: const Text('Go home',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      case _PlayerErrorKind.unavailable:
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off,
                    color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Video unavailable',
                  key: Key('player.unavailable'),
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      case _PlayerErrorKind.unknown:
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Playback failed',
                  key: const Key('player.error'),
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _retryLoad,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
    }
  }
}
