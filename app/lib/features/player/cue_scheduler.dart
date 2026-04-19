import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../core/analytics/analytics_sinks.dart';
import '../../data/models/cue.dart';

/// Persistent checkpoint for a cue that was active when the app went to
/// background. Stored via [CueCheckpointStore] so the overlay can be
/// restored after the OS kills and resurrects the process mid-quiz.
@immutable
class CueCheckpoint {
  const CueCheckpoint({required this.cueId, required this.videoId});
  final String cueId;
  final String videoId;
}

/// Abstract seam for persisting an in-flight cue across app lifecycle
/// events. Production wires this to `flutter_secure_storage`; tests
/// substitute an in-memory fake.
abstract class CueCheckpointStore {
  Future<void> save(CueCheckpoint checkpoint);
  Future<CueCheckpoint?> load();
  Future<void> clear();
}

/// In-memory fake — default if no store is provided. Safe for release
/// builds too, because losing an in-flight cue across a process death is
/// a degraded-but-correct behavior (the next poll tick will surface the
/// cue again on its own if the learner hadn't yet progressed past it).
class InMemoryCueCheckpointStore implements CueCheckpointStore {
  CueCheckpoint? _checkpoint;

  @override
  Future<void> save(CueCheckpoint checkpoint) async {
    _checkpoint = checkpoint;
  }

  @override
  Future<CueCheckpoint?> load() async => _checkpoint;

  @override
  Future<void> clear() async {
    _checkpoint = null;
  }
}

/// Polls a `VideoPlayerController`'s position on a 50ms cadence and fires
/// an overlay cue at `cue.atMs - 200ms` (the 200ms lead-time absorbs the
/// async pause + seek round-trip; the 50ms poll keeps worst-case trigger
/// jitter under ±50ms even on low-end Android hardware).
///
/// **The 50ms poll interval + 200ms lead time is load-bearing.** Bumping
/// the poll to 100ms worst-cases the trigger at `atMs+50ms` (overshoot
/// the intended moment); dropping the lead below 200ms means the pause
/// hasn't taken effect by the time the overlay shows, so the learner
/// sees a frame or two of post-cue content.
///
/// Ownership: the scheduler does NOT own the `VideoPlayerController`
/// (that comes from `VideoControllerCache`) — the parent widget must
/// call `dispose()` on the scheduler BEFORE disposing the controller,
/// otherwise a Timer tick can dereference a disposed controller.
class CueScheduler with WidgetsBindingObserverMixin {
  CueScheduler({
    required VideoPlayerController controller,
    required List<Cue> cues,
    required this.videoId,
    ValueNotifier<Cue?>? activeCueNotifier,
    CueCheckpointStore? checkpointStore,
    CueAnalyticsSink? analyticsSink,
    Duration pollInterval = const Duration(milliseconds: 50),
    // 50ms poll + 200ms lead time gives ±50ms worst-case cue-trigger
    // jitter on low-end devices. Don't bump either without testing.
    Duration leadTime = const Duration(milliseconds: 200),
  })  : _controller = controller,
        _cues = List<Cue>.unmodifiable(_sortedByAtMs(cues)),
        _pollInterval = pollInterval,
        _leadTime = leadTime,
        activeCueNotifier = activeCueNotifier ?? ValueNotifier<Cue?>(null),
        _checkpointStore = checkpointStore ?? InMemoryCueCheckpointStore(),
        analyticsSink = analyticsSink ?? const NoopCueAnalyticsSink();

  static List<Cue> _sortedByAtMs(List<Cue> cues) {
    final list = List<Cue>.of(cues);
    list.sort((a, b) => a.atMs.compareTo(b.atMs));
    return list;
  }

  final VideoPlayerController _controller;
  final List<Cue> _cues;
  final Duration _pollInterval;
  final Duration _leadTime;
  final CueCheckpointStore _checkpointStore;

  /// Analytics hook — fires `cue_shown` when an overlay mounts and
  /// `cue_answered` when [onCueAnswered] is invoked by the widget host.
  /// Defaults to a no-op so existing tests don't need to pass one.
  final CueAnalyticsSink analyticsSink;

  /// Which video this scheduler is bound to. Lifecycle restore is only
  /// performed when the persisted checkpoint's `videoId` matches — swap
  /// a schedule to a different video and the stale checkpoint is dropped.
  final String videoId;

  /// The learner-facing reactive handle. Drives the `AnimatedSwitcher` in
  /// the player wrapper: `null` → no overlay; non-null → show the
  /// appropriate cue widget.
  ///
  /// Only the cue's *payload* travels through here. The backend already
  /// redacts graded answers from `Cue.payload` that the `/api/videos/:id/cues`
  /// endpoint returns to enrolled learners: the MCQ payload still has
  /// `answerIndex`, etc., because server-side grading still needs it —
  /// **do not** build UI that relies on that; always submit to
  /// `/api/attempts` and trust the server's `{correct, scoreJson,
  /// explanation}` reply.
  final ValueNotifier<Cue?> activeCueNotifier;

  int _nextCueIndex = 0;
  Cue? _activeCue;
  Timer? _poller;
  bool _disposed = false;

  /// Whether a poll cycle is currently running — used to block re-entry
  /// under the controller-callback async boundary.
  bool _ticking = false;

  /// True between [start] and [stop]. Exposed for tests.
  bool get isRunning => _poller != null;

  /// The cue currently shown in the overlay, if any.
  Cue? get activeCue => _activeCue;

  /// Index of the next cue to evaluate. Exposed for tests.
  @visibleForTesting
  int get nextCueIndex => _nextCueIndex;

  /// Number of cues configured.
  int get cueCount => _cues.length;

  /// Start polling. Idempotent.
  void start() {
    if (_disposed) return;
    if (_poller != null) return;
    _poller = Timer.periodic(_pollInterval, (_) => _tick());
  }

  /// Stop polling. Safe to call multiple times. Does NOT clear the active
  /// cue — the overlay stays up so the learner keeps what they were
  /// working on.
  void stop() {
    _poller?.cancel();
    _poller = null;
  }

  /// Resume playback after a cue overlay is dismissed (learner tapped
  /// "Continue"). Advances `_nextCueIndex` past the current cue,
  /// `controller.play()`s iff the cue paused, and clears the notifier.
  ///
  /// Safe to call when no cue is active (no-op).
  Future<void> resume() async {
    if (_disposed) return;
    final active = _activeCue;
    if (active == null) return;
    _nextCueIndex += 1;
    _activeCue = null;
    activeCueNotifier.value = null;
    await _checkpointStore.clear();
    if (active.pause) {
      try {
        await _controller.play();
      } catch (e) {
        // Playback resume can fail on a backgrounded controller — log
        // but keep scheduler state consistent so the next cue still
        // fires correctly.
        if (kDebugMode) debugPrint('CueScheduler.resume play() failed: $e');
      }
    }
  }

  /// Tear down. Cancels the timer and clears listeners. **Idempotent.**
  /// Callers MUST invoke before disposing the `VideoPlayerController`.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    activeCueNotifier.dispose();
  }

  Future<void> _tick() async {
    if (_disposed) return;
    if (_ticking) return;
    _ticking = true;
    try {
      if (_activeCue != null) return;
      if (_nextCueIndex >= _cues.length) return;

      final posMs = _safePositionMs();
      if (posMs == null) return;

      // Scrub-ahead skip: if we've blown past the next cue(s), advance
      // the index so we never retroactively surface a skipped cue.
      while (_nextCueIndex < _cues.length &&
          posMs > _cues[_nextCueIndex].atMs + _pollInterval.inMilliseconds) {
        _nextCueIndex += 1;
      }
      if (_nextCueIndex >= _cues.length) return;

      final cue = _cues[_nextCueIndex];
      if (posMs < cue.atMs - _leadTime.inMilliseconds) return;

      // Claim the cue BEFORE awaiting pause/seek — otherwise a second
      // tick racing on this one could re-fire. Setting _activeCue first
      // is the mutex.
      _activeCue = cue;
      if (cue.pause) {
        try {
          await _controller.pause();
          await _controller.seekTo(Duration(milliseconds: cue.atMs));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('CueScheduler pause/seek failed: $e');
          }
        }
      }
      await _checkpointStore.save(
        CueCheckpoint(cueId: cue.id, videoId: videoId),
      );
      activeCueNotifier.value = cue;
      // Fire telemetry AFTER the notifier flip so that any exception
      // from the sink can't prevent the overlay from showing.
      try {
        analyticsSink.onCueShown(cue.id, _cueTypeString(cue.type));
      } catch (e) {
        if (kDebugMode) debugPrint('cue_shown sink failed: $e');
      }
    } finally {
      _ticking = false;
    }
  }

  /// Called by the cue widget host when the learner submits and the
  /// server returns a graded attempt. Forwards to the analytics sink.
  /// `correct` comes from the server, never from the client.
  void reportAnswered({
    required String cueId,
    required CueType cueType,
    required bool correct,
  }) {
    try {
      analyticsSink.onCueAnswered(cueId, _cueTypeString(cueType), correct);
    } catch (e) {
      if (kDebugMode) debugPrint('cue_answered sink failed: $e');
    }
  }

  String _cueTypeString(CueType t) {
    switch (t) {
      case CueType.mcq:
        return 'MCQ';
      case CueType.blanks:
        return 'BLANKS';
      case CueType.matching:
        return 'MATCHING';
      case CueType.voice:
        return 'VOICE';
    }
  }

  int? _safePositionMs() {
    try {
      return _controller.value.position.inMilliseconds;
    } catch (_) {
      // `value` can throw if the controller was disposed between the
      // timer tick and this read. Treat as a no-op.
      return null;
    }
  }

  /// Called by the owning widget on `AppLifecycleState.paused`. Persists
  /// the current active cue (if any) via the checkpoint store.
  Future<void> onAppPaused() async {
    final active = _activeCue;
    if (active == null) return;
    await _checkpointStore.save(
      CueCheckpoint(cueId: active.id, videoId: videoId),
    );
  }

  /// Called by the owning widget on `AppLifecycleState.resumed`. Loads
  /// the checkpoint and, if it matches this scheduler's video, restores
  /// the active cue so the overlay re-appears.
  Future<void> onAppResumed() async {
    if (_disposed) return;
    final checkpoint = await _checkpointStore.load();
    if (checkpoint == null) return;
    if (checkpoint.videoId != videoId) return;
    // Find the cue by id in our configured list.
    final idx = _cues.indexWhere((c) => c.id == checkpoint.cueId);
    if (idx < 0) return;
    final cue = _cues[idx];
    _nextCueIndex = idx;
    _activeCue = cue;
    activeCueNotifier.value = cue;
  }
}

/// Placeholder mixin: some older Flutter SDKs require a separate
/// `WidgetsBindingObserver` subclass for lifecycle callbacks. We don't
/// subscribe directly — the *parent widget* owns the observer so that
/// testing and hot-reload don't leak subscriptions — but retaining this
/// empty mixin lets future integrations subclass the scheduler for
/// lifecycle events without a breaking API change.
mixin WidgetsBindingObserverMixin {}
