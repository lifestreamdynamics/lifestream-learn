import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/analytics/analytics_sinks.dart';
import '../../core/http/error_envelope.dart';
import '../../core/settings/settings_cubit.dart';
import '../../core/settings/settings_state.dart';
import '../../core/utils/bcp47_labels.dart';
import '../../data/models/video.dart';
import '../../data/repositories/enrollment_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../feed/video_controller_cache.dart';
import 'caption_loader.dart';
import 'caption_picker_sheet.dart';

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
    this.connectivity,
    this.captionLoader,
    super.key,
  });

  final VideoSummary video;
  final String courseId;
  final VideoRepository videoRepo;
  final EnrollmentRepository enrollmentRepo;
  final VideoControllerCache controllerCache;
  final VoidCallback? onError;

  /// Optional `connectivity_plus` injection point. Defaults to a fresh
  /// [Connectivity] instance at first-use. Widget tests swap this for a
  /// deterministic fake so the cellular branch doesn't depend on the
  /// platform channel.
  final Connectivity? connectivity;

  /// When false, the player won't auto-play even if visible. Used by
  /// widget tests and by future (Slice E) designer preview that wants
  /// manual play control.
  final bool autoPlayWhenVisible;

  /// Optional analytics hook. When provided, emits `video_view` on the
  /// first playback start and `video_complete` once per video per
  /// instance at 90% watched. Defaults to no-op — existing tests don't
  /// need to wire it up.
  final VideoAnalyticsSink? analyticsSink;

  /// Optional [CaptionLoader] override. Defaults to a live instance.
  /// Widget tests inject a fake so caption-fetch does not touch the network.
  final CaptionLoader? captionLoader;

  @override
  State<LearnVideoPlayer> createState() => _LearnVideoPlayerState();
}

enum _PlayerErrorKind { processing, unavailable, forbidden, unknown }

/// Intents for keyboard / DPAD shortcuts. Declared as private top-level
/// classes so `Shortcuts`/`Actions` can dispatch them without needing
/// closures that capture state across rebuilds.
class _TogglePlayIntent extends Intent {
  const _TogglePlayIntent();
}

class _SeekBackIntent extends Intent {
  const _SeekBackIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}

class _VolumeUpIntent extends Intent {
  const _VolumeUpIntent();
}

class _VolumeDownIntent extends Intent {
  const _VolumeDownIntent();
}

class _LearnVideoPlayerState extends State<LearnVideoPlayer> {
  VideoPlayerController? _controller;
  _PlayerErrorKind? _errorKind;
  String? _errorMessage;
  bool _loading = true;
  bool _isVisible = false;

  /// The most recent playback info; kept on state so caption reloads can
  /// look up the track list after initial load.
  PlaybackInfo? _playback;

  /// Active caption language. Null means captions are off.
  String? _currentCaptionLanguage;

  /// Caption fetcher — uses widget override when provided, otherwise default.
  CaptionLoader get _captionLoader =>
      widget.captionLoader ?? CaptionLoader();

  /// Latch: when data-saver is on and the device is on cellular, the
  /// player defers auto-play until the user taps. We also surface a
  /// one-shot snackbar so the behaviour is discoverable rather than
  /// mysterious. `video_player` doesn't expose a track-selection API
  /// for ABR capping, so this is the honest user-visible effect —
  /// pausing auto-play saves the user from an unexpected cellular
  /// bitrate spike without pretending to throttle bitrate we can't
  /// actually control.
  bool _dataSaverCellularSuppressed = false;
  bool _dataSaverSnackbarShown = false;

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

  /// Focus node for the keyboard/DPAD shortcut detector. Owned by the
  /// state (not by `FocusableActionDetector(autofocus: true)`) because
  /// the feed preloads 3 players at once — `autofocus` on every mounted
  /// instance lets siblings steal focus from the visible one, which
  /// would route Space / arrow keys to an off-screen video. We request
  /// focus in `_onVisibilityChanged` when this player becomes the one
  /// in view, and drop it when it scrolls out.
  final FocusNode _focusNode = FocusNode(debugLabel: 'learn_video_player');

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

  /// Best-effort lookup of the app-wide [SettingsCubit]. Returns the
  /// current state if the cubit is above this widget in the tree,
  /// otherwise null — widget tests that don't need settings semantics
  /// stay free of a required Provider.
  SettingsState? _readSettings() {
    if (!mounted) return null;
    try {
      return context.read<SettingsCubit>().state;
    } catch (_) {
      return null;
    }
  }

  /// True when the current connection includes cellular. A failure to
  /// resolve connectivity (platform channel hiccup, test environment
  /// without the plugin) is treated as "not cellular" — the conservative
  /// choice here is to NOT suppress auto-play if we can't tell, since
  /// data-saver's purpose is to protect cellular usage, not to break
  /// the player on unknown transports.
  Future<bool> _isOnCellular() async {
    try {
      final connectivity = widget.connectivity ?? Connectivity();
      final result = await connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.mobile);
    } catch (_) {
      return false;
    }
  }

  void _maybeShowDataSaverSnackbar() {
    if (_dataSaverSnackbarShown) return;
    _dataSaverSnackbarShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('player.dataSaver.cellularSnackbar'),
          content: Text('Data saver is on — tap to start on cellular'),
          duration: Duration(seconds: 3),
        ),
      );
    });
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
      // Slice P4 — apply the user's preferred playback speed if a
      // SettingsCubit is in scope. Looked up through `context.read`
      // rather than a required constructor param so existing widget
      // tests (which don't wrap the player in a BlocProvider) keep
      // working at the default 1.0x.
      final settings = _readSettings();
      if (settings != null) {
        try {
          await controller.setPlaybackSpeed(settings.playbackSpeed);
        } catch (_) {
          // Some fvp backends don't accept arbitrary speeds while the
          // player is loading — a failure here is non-fatal (playback
          // still happens at 1.0x). Swallow and move on.
        }
      }

      // Slice C — resolve effective caption language and apply on load.
      // Priority: (1) user preference, (2) video default (only when
      // captionsDefault setting is on), (3) off.
      String? effectiveLanguage;
      if (settings != null && settings.captionsDefault) {
        final userPref = settings.captionLanguage;
        if (userPref != null &&
            playback.captions.any((t) => t.language == userPref)) {
          effectiveLanguage = userPref;
        } else if (playback.defaultCaptionLanguage != null &&
            playback.captions
                .any((t) => t.language == playback.defaultCaptionLanguage)) {
          effectiveLanguage = playback.defaultCaptionLanguage;
        }
      }

      if (effectiveLanguage != null) {
        final track = playback.captions
            .firstWhere((t) => t.language == effectiveLanguage);
        await _applyCaption(controller, track, playback);
      }

      // Slice-H follow-up — honour `settings.dataSaver` on cellular.
      // `video_player` exposes no per-variant track-selection API, so
      // we can't cap ABR bitrate from here. The honest effect is to
      // suppress auto-play on cellular when data-saver is on: the user
      // has to tap to start, which surfaces the cellular cost to them
      // explicitly rather than silently streaming a high-bitrate variant.
      _dataSaverCellularSuppressed = false;
      if (settings?.dataSaver == true) {
        _dataSaverCellularSuppressed = await _isOnCellular();
      }

      setState(() {
        _playback = playback;
        _controller = controller;
        _loading = false;
      });
      if (widget.autoPlayWhenVisible &&
          _isVisible &&
          !_dataSaverCellularSuppressed) {
        await controller.play();
      } else if (_dataSaverCellularSuppressed && _isVisible) {
        _maybeShowDataSaverSnackbar();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      widget.onError?.call();
      setState(() {
        _loading = false;
        _errorMessage = e.message;
        _errorKind = _mapError(e);
      });
      _announceError();
    } catch (e) {
      if (!mounted) return;
      widget.onError?.call();
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
        _errorKind = _PlayerErrorKind.unknown;
      });
      _announceError();
    }
  }

  /// Returns a human-readable description of the current error, suitable
  /// for a screen-reader announcement or a Semantics label.
  String _describeError() {
    switch (_errorKind) {
      case _PlayerErrorKind.processing:
        return 'Video is still processing';
      case _PlayerErrorKind.forbidden:
        return 'Access denied';
      case _PlayerErrorKind.unavailable:
        return 'Video unavailable';
      case _PlayerErrorKind.unknown:
      case null:
        return 'Playback failed — ${_errorMessage ?? ''}'.trimRight();
    }
  }

  void _announceError() {
    if (_errorKind == null) return;
    // Defer until after the current frame so that (a) `initState`'s
    // synchronous error path doesn't crash on `View.maybeOf()` (it's an
    // inherited-widget lookup, illegal before first build), and (b) the
    // error UI is in the tree when the announcement fires so TalkBack
    // associates the two.
    final message = _describeError();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final view = View.maybeOf(context);
      if (view == null) return;
      // Fire-and-forget — a failed announcement must never break playback.
      unawaited(SemanticsService.sendAnnouncement(
        view,
        message,
        TextDirection.ltr,
      ));
    });
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
    _focusNode.dispose();
    // Controllers live in the shared cache — do NOT dispose here.
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final nowVisible = info.visibleFraction >= 0.5;
    if (nowVisible == _isVisible) return;
    _isVisible = nowVisible;
    // Focus moves with visibility so keyboard / DPAD / hardware-keyboard
    // events only ever route to the player the user is actually looking
    // at. Off-screen siblings relinquish focus so they don't steal it.
    if (nowVisible) {
      _focusNode.requestFocus();
    } else if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    final c = _controller;
    if (c == null) return;
    if (nowVisible) {
      if (widget.autoPlayWhenVisible && !_dataSaverCellularSuppressed) {
        unawaited(c.play());
      } else if (_dataSaverCellularSuppressed) {
        _maybeShowDataSaverSnackbar();
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
      // User tapped to start — they've consented to the cellular cost
      // this session. Clear the suppression so visibility changes
      // resume auto-play normally.
      _dataSaverCellularSuppressed = false;
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

  void _adjustVolume(double delta) {
    final c = _controller;
    if (c == null) return;
    final next = (c.value.volume + delta).clamp(0.0, 1.0);
    unawaited(c.setVolume(next));
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

  /// Fetches [track] via [CaptionLoader] and attaches it to [controller].
  /// On a 404, invalidates the playback cache so the next load refetches
  /// the track list. On any other error, logs and continues — captions
  /// failing must never break video playback.
  Future<void> _applyCaption(
    VideoPlayerController controller,
    CaptionTrack track,
    PlaybackInfo playback,
  ) async {
    try {
      final file = await _captionLoader.load(track);
      if (!mounted) return;
      await controller.setClosedCaptionFile(Future.value(file));
      setState(() => _currentCaptionLanguage = track.language);
    } on ApiException catch (e) {
      debugPrint(
        'LearnVideoPlayer: caption load failed '
        '(${e.statusCode}/${e.code}): ${e.message}',
      );
      if (e.statusCode == 404) {
        // The signed URL for this language is gone — invalidate so the
        // next swipe refetches the playback and gets an updated track list.
        widget.videoRepo.invalidate(widget.video.id);
      }
      // captions off — continue without them.
    } catch (e) {
      debugPrint('LearnVideoPlayer: caption load unexpected error: $e');
    }
  }

  /// Handles the CC button tap: shows the picker, applies the result.
  Future<void> _onCcTapped() async {
    final playback = _playback;
    final controller = _controller;
    if (playback == null || controller == null) return;

    final result = await showCaptionPicker(
      context: context,
      tracks: playback.captions,
      currentLanguage: _currentCaptionLanguage,
    );

    if (!mounted) return;

    if (result.cancelled) return;

    try {
      if (result.off) {
        await controller.setClosedCaptionFile(null);
        setState(() => _currentCaptionLanguage = null);
        _readSettingsCubit()?.setCaptionLanguage(null);
        widget.analyticsSink
            ?.onCaptionLanguageSelected(widget.video.id, null);
      } else if (result.language != null) {
        final lang = result.language!;
        final track = playback.captions.firstWhere((t) => t.language == lang);
        await _applyCaption(controller, track, playback);
        _readSettingsCubit()?.setCaptionLanguage(lang);
        widget.analyticsSink
            ?.onCaptionLanguageSelected(widget.video.id, lang);
      }
    } catch (e) {
      debugPrint('LearnVideoPlayer: CC change error: $e');
    }
  }

  /// Best-effort lookup of [SettingsCubit] from the widget tree — same
  /// try/catch pattern as [_readSettings] so tests without a BlocProvider
  /// keep passing.
  SettingsCubit? _readSettingsCubit() {
    try {
      return context.read<SettingsCubit>();
    } catch (_) {
      return null;
    }
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
    return FocusableActionDetector(
      focusNode: _focusNode,
      includeFocusSemantics: false,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): _TogglePlayIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _TogglePlayIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _SeekBackIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _SeekForwardIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp): _VolumeUpIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): _VolumeDownIntent(),
      },
      actions: <Type, Action<Intent>>{
        _TogglePlayIntent: CallbackAction<_TogglePlayIntent>(
          onInvoke: (_) {
            _toggleOverlay();
            return null;
          },
        ),
        _SeekBackIntent: CallbackAction<_SeekBackIntent>(
          onInvoke: (_) {
            _seekBy(const Duration(seconds: -10));
            return null;
          },
        ),
        _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(
          onInvoke: (_) {
            _seekBy(const Duration(seconds: 10));
            return null;
          },
        ),
        _VolumeUpIntent: CallbackAction<_VolumeUpIntent>(
          onInvoke: (_) {
            _adjustVolume(0.1);
            return null;
          },
        ),
        _VolumeDownIntent: CallbackAction<_VolumeDownIntent>(
          onInvoke: (_) {
            _adjustVolume(-0.1);
            return null;
          },
        ),
      },
      child: VisibilityDetector(
        key: ValueKey<String>('learn_video.${widget.video.id}'),
        onVisibilityChanged: _onVisibilityChanged,
        child: _buildBody(context),
      ),
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
    final playback = _playback;
    final hasCaptions = playback != null && playback.captions.isNotEmpty;
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
          // Closed-caption overlay — renders the current VTT cue near the
          // bottom of the video, above the title chrome. For RTL caption
          // languages (ar/he/fa/ur) the text direction flips so cues render
          // with the correct alignment.
          Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: IgnorePointer(
              child: Directionality(
                textDirection: _currentCaptionLanguage != null &&
                        isRtlCaptionLanguage(_currentCaptionLanguage!)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: ClosedCaption(
                  text: c.value.caption.text,
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    backgroundColor: Color(0xAA000000),
                  ),
                ),
              ),
            ),
          ),
          // Double-tap seek — full-height left / right zones on top of
          // the player but below the overlay.
          Row(children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Rewind 10 seconds',
                onTap: () => _seekBy(const Duration(seconds: -10)),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => _seekBy(const Duration(seconds: -10)),
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Skip forward 10 seconds',
                onTap: () => _seekBy(const Duration(seconds: 10)),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => _seekBy(const Duration(seconds: 10)),
                ),
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
                  c.value.isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          // Invisible semantics layer for screen readers. The outer
          // GestureDetector above handles the actual tap — this just
          // exposes a labelled "Play"/"Pause" button to TalkBack.
          Positioned.fill(
            child: Semantics(
              button: true,
              label: c.value.isPlaying ? 'Pause' : 'Play',
              onTap: _toggleOverlay,
              child: const IgnorePointer(child: SizedBox.expand()),
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
          // CC (captions) button — top-right corner, only when tracks exist.
          if (hasCaptions)
            Positioned(
              top: 8,
              right: 8,
              child: Semantics(
                button: true,
                label: 'Caption language',
                child: IconButton(
                  key: const Key('player.cc'),
                  icon: Icon(
                    _currentCaptionLanguage != null
                        ? Icons.closed_caption_rounded
                        : Icons.closed_caption_outlined,
                    color: Colors.white,
                  ),
                  tooltip: 'Caption language',
                  onPressed: _onCcTapped,
                ),
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
          // Gradient playback progress strip at the very bottom of the
          // player surface. Non-interactive; indicates position only.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFF38BDF8)],
              ).createShader(rect),
              child: LinearProgressIndicator(
                key: const Key('player.progressBar'),
                value: duration > 0
                    ? (c.value.position.inMilliseconds / duration).clamp(
                        0.0,
                        1.0,
                      )
                    : 0.0,
                minHeight: 3,
                backgroundColor: Colors.white24,
                color: Colors.white, // replaced by ShaderMask gradient
              ),
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
            child: Semantics(
              liveRegion: true,
              container: true,
              label: 'Video is still processing',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_empty_rounded,
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
          ),
        );
      case _PlayerErrorKind.forbidden:
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: Semantics(
              liveRegion: true,
              container: true,
              label: 'Access denied',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 48),
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
          ),
        );
      case _PlayerErrorKind.unavailable:
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: Semantics(
              liveRegion: true,
              container: true,
              label: 'Video unavailable',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_rounded,
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
          ),
        );
      case _PlayerErrorKind.unknown:
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: Semantics(
              liveRegion: true,
              container: true,
              label: 'Playback failed — ${_errorMessage ?? ''}'.trimRight(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ?? 'Playback failed',
                    key: const Key('player.error'),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        key: const Key('player.error.back'),
                        onPressed: () => _exitOnError(context),
                        child: const Text('Back',
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _retryLoad,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  /// Leave a failed player. Prefer popping the current route when one
  /// exists (embedded-in-feed and deep-linked-watch screens both have a
  /// parent to fall back to); otherwise land on the Courses tab so the
  /// user isn't stranded on a black screen.
  void _exitOnError(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go('/courses');
    }
  }
}
