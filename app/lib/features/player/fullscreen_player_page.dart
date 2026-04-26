import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../data/repositories/attempt_repository.dart';
import '../../features/cues/cue_overlay_host.dart';
import 'cue_scheduler.dart';
import 'learn_video_player.dart' show ZoomMode, decideZoomFromScale;

/// Full-screen player page.
///
/// Receives an already-initialised [VideoPlayerController] and an optional
/// [CueScheduler] from the parent — it does NOT create or dispose either,
/// since both are owned by [VideoWithCuesScreen].
///
/// Orientation behaviour:
/// - Landscape source (aspectRatio > 1): forces landscape on entry, and
///   auto-exits when the device is rotated back to portrait (after the OS has
///   had a chance to apply the initial landscape preference).
/// - Portrait source (aspectRatio ≤ 1): forces portraitUp on entry; device
///   rotation is unrestricted while fullscreen.
///
/// On dispose, all four orientations are restored so the normal player can
/// rotate freely.
class FullscreenPlayerPage extends StatefulWidget {
  const FullscreenPlayerPage({
    required this.controller,
    required this.title,
    this.scheduler,
    this.attemptRepo,
    super.key,
  });

  /// The already-initialised controller owned by the parent screen.
  final VideoPlayerController controller;

  /// The active cue scheduler, if any. When non-null the cue overlay is
  /// rendered on top of the video. Must be the same instance used by the
  /// parent — do NOT restart it here.
  final CueScheduler? scheduler;

  /// Required when [scheduler] is non-null so [CueOverlayHost] can submit
  /// attempts. May be null when there is no scheduler.
  final AttemptRepository? attemptRepo;

  /// Used for the exit button tooltip and accessibility label.
  final String title;

  @override
  State<FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<FullscreenPlayerPage> {
  /// True when the video source is portrait (width <= height).
  late final bool _isPortraitSource;

  /// Set to true the first time we observe a landscape frame, guarding against
  /// the early-pop race where the OS hasn't applied our landscape preference yet.
  bool _hasEnteredLandscape = false;

  /// Latched once `_exit()` has been dispatched from the OrientationBuilder
  /// auto-exit path so we don't schedule multiple `maybePop` calls while the
  /// route is in the process of tearing down.
  bool _exiting = false;

  // Pinch-to-zoom state.
  ZoomMode _zoomMode = ZoomMode.fit;
  double _pendingScale = 1.0;
  bool _zoomFlashVisible = false;
  String _zoomFlashLabel = '';
  Timer? _zoomFlashTimer;

  @override
  void initState() {
    super.initState();
    _isPortraitSource = widget.controller.value.aspectRatio <= 1.0;

    if (_isPortraitSource) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _pendingScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    _pendingScale = details.scale;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_pendingScale == 1.0) return;
    final next = decideZoomFromScale(_pendingScale, _zoomMode);
    _pendingScale = 1.0;
    if (next == _zoomMode) return;
    final label = next == ZoomMode.fill ? 'Zoom to fill' : 'Zoom to fit';
    _zoomFlashTimer?.cancel();
    setState(() {
      _zoomMode = next;
      _zoomFlashLabel = label;
      _zoomFlashVisible = true;
    });
    _zoomFlashTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _zoomFlashVisible = false);
    });
  }

  /// Builds the video surface with the current zoom mode applied.
  Widget _buildVideoSurface() {
    final c = widget.controller;
    if (_zoomMode == ZoomMode.fill) {
      return ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c.value.size.width == 0 ? 1 : c.value.size.width,
              height: c.value.size.height == 0 ? 1 : c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: c.value.size.width == 0 ? 1 : c.value.size.width,
          height: c.value.size.height == 0 ? 1 : c.value.size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _zoomFlashTimer?.cancel();
    // Restore all four orientations so the regular player can rotate freely.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _exit() {
    // Use pop() directly, not maybePop(): the parent `PopScope` has
    // `canPop: false`, so `maybePop` would re-invoke `onPopInvokedWithResult`
    // → `_exit()` and infinite-loop. The PopScope's only job is to
    // intercept the OS back-press and route it through here; the explicit
    // pop is what the user-driven exit button (and the OrientationBuilder
    // auto-exit, gated by `_exiting`) want.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final videoWidget = _buildVideoSurface();

    final exitButton = SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Semantics(
          button: true,
          label: 'Exit fullscreen',
          child: IconButton(
            key: const Key('fullscreen.exit'),
            icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
            tooltip: 'Exit fullscreen',
            onPressed: _exit,
          ),
        ),
      ),
    );

    final zoomFlash = IgnorePointer(
      child: AnimatedOpacity(
        opacity: _zoomFlashVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xAA000000),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _zoomFlashLabel,
              key: const Key('fullscreen.zoomFlash'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    final scheduler = widget.scheduler;
    final attemptRepo = widget.attemptRepo;

    Widget body = GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Stack(
        children: [
          videoWidget,
          zoomFlash,
          exitButton,
        ],
      ),
    );

    if (scheduler != null && attemptRepo != null) {
      body = CueOverlayHost(
        scheduler: scheduler,
        attemptRepo: attemptRepo,
        child: body,
      );
    }

    // For landscape sources, wrap in OrientationBuilder to auto-exit when the
    // device is rotated back to portrait — but only after we've confirmed the
    // OS actually applied the landscape preference (_hasEnteredLandscape).
    // The builder captures `inner` by value rather than reassigning `body`
    // itself, which would create a recursive widget reference.
    if (!_isPortraitSource) {
      final inner = body;
      body = OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            _hasEnteredLandscape = true;
          } else if (_hasEnteredLandscape && !_exiting) {
            _exiting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _exit();
            });
          }
          return inner;
        },
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _exit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: body,
      ),
    );
  }
}
