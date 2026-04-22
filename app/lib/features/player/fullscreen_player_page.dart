import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../data/repositories/attempt_repository.dart';
import '../../features/cues/cue_overlay_host.dart';
import 'cue_scheduler.dart';

/// Full-screen landscape player page.
///
/// Receives an already-initialised [VideoPlayerController] and an optional
/// [CueScheduler] from the parent — it does NOT create or dispose either,
/// since both are owned by [VideoWithCuesScreen].
///
/// On entry, forces landscape orientation + immersive sticky UI mode.
/// On exit (pop), restores portrait orientation + system overlays.
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
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _exit() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final videoWidget = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: widget.controller.value.size.width,
          height: widget.controller.value.size.height,
          child: VideoPlayer(widget.controller),
        ),
      ),
    );

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

    final scheduler = widget.scheduler;
    final attemptRepo = widget.attemptRepo;

    Widget body = Stack(
      children: [
        videoWidget,
        exitButton,
      ],
    );

    if (scheduler != null && attemptRepo != null) {
      body = CueOverlayHost(
        scheduler: scheduler,
        attemptRepo: attemptRepo,
        child: body,
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
