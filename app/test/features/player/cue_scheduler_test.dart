import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/cue.dart';
import 'package:lifestream_learn_app/features/player/cue_scheduler.dart';
import 'package:video_player/video_player.dart';

/// Hand-rolled `VideoPlayerController` stub. `mocktail` can't stub
/// `value` via the usual `when(...)` path because `value` is a getter
/// that returns a `VideoPlayerValue`; we also need to observe calls to
/// `pause()`, `play()`, and `seekTo()` and settle the async boundary
/// deterministically under `FakeAsync`.
class _FakeVideoPlayerController implements VideoPlayerController {
  _FakeVideoPlayerController();

  Duration _position = Duration.zero;
  bool isPlaying = true;
  int pauseCalls = 0;
  int playCalls = 0;
  final List<Duration> seekCalls = <Duration>[];

  set positionMs(int ms) => _position = Duration(milliseconds: ms);

  void disposeController() {
    // Simulate what a disposed controller does when value is read: throw.
    _disposed = true;
  }

  bool _disposed = false;

  @override
  VideoPlayerValue get value {
    if (_disposed) throw StateError('Controller disposed');
    return VideoPlayerValue(
      duration: const Duration(seconds: 30),
      position: _position,
      isPlaying: isPlaying,
      isLooping: false,
      volume: 1.0,
    );
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    isPlaying = false;
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    isPlaying = true;
  }

  @override
  Future<void> seekTo(Duration position) async {
    seekCalls.add(position);
    _position = position;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Cue _cue({
  required String id,
  required int atMs,
  bool pause = true,
  CueType type = CueType.mcq,
}) {
  return Cue(
    id: id,
    videoId: 'v1',
    atMs: atMs,
    pause: pause,
    type: type,
    payload: const <String, dynamic>{},
    orderIndex: 0,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('CueScheduler', () {
    test('fires cue at atMs - 200 (within the 50ms poll)', () {
      fakeAsync((fa) {
        final controller = _FakeVideoPlayerController();
        final cues = [_cue(id: 'c1', atMs: 1000)];
        final scheduler = CueScheduler(
          controller: controller,
          cues: cues,
          videoId: 'v1',
        )..start();

        // Well before the lead time: no cue.
        controller.positionMs = 500;
        fa.elapse(const Duration(milliseconds: 50));
        expect(scheduler.activeCue, isNull);
        expect(controller.pauseCalls, 0);

        // Cross lead threshold (atMs - 200 = 800): cue should fire.
        controller.positionMs = 820;
        fa.elapse(const Duration(milliseconds: 50));
        // Let the pause/seek futures flush.
        fa.flushMicrotasks();
        expect(scheduler.activeCue, isNotNull);
        expect(scheduler.activeCue!.id, 'c1');
        expect(controller.pauseCalls, 1);
        expect(controller.seekCalls, [const Duration(milliseconds: 1000)]);
        scheduler.dispose();
      });
    });

    test('pause=false path fires notifier but does NOT pause controller', () {
      fakeAsync((fa) {
        final controller = _FakeVideoPlayerController();
        final cues = [_cue(id: 'c1', atMs: 500, pause: false)];
        final scheduler = CueScheduler(
          controller: controller,
          cues: cues,
          videoId: 'v1',
        )..start();

        controller.positionMs = 310;
        fa.elapse(const Duration(milliseconds: 50));
        fa.flushMicrotasks();

        expect(scheduler.activeCue, isNotNull);
        expect(controller.pauseCalls, 0);
        expect(controller.seekCalls, isEmpty);
        scheduler.dispose();
      });
    });

    test('rapid seek past multiple cues advances nextCueIndex without '
        'firing the skipped cues', () {
      fakeAsync((fa) {
        final controller = _FakeVideoPlayerController();
        final cues = [
          _cue(id: 'c1', atMs: 1000),
          _cue(id: 'c2', atMs: 2000),
          _cue(id: 'c3', atMs: 3000),
          _cue(id: 'c4', atMs: 4000),
        ];
        final scheduler = CueScheduler(
          controller: controller,
          cues: cues,
          videoId: 'v1',
        )..start();

        // Jump the position beyond c1/c2/c3 in one tick. Only c4 should
        // surface (and only once the lead window is reached).
        controller.positionMs = 3500;
        fa.elapse(const Duration(milliseconds: 50));
        fa.flushMicrotasks();
        // Not yet within c4's lead window (c4.atMs - 200 = 3800).
        expect(scheduler.activeCue, isNull);
        expect(scheduler.nextCueIndex, 3);

        // Advance into c4's lead window.
        controller.positionMs = 3820;
        fa.elapse(const Duration(milliseconds: 50));
        fa.flushMicrotasks();
        expect(scheduler.activeCue, isNotNull);
        expect(scheduler.activeCue!.id, 'c4');
        scheduler.dispose();
      });
    });

    test('resume clears notifier, advances index, and calls play() iff paused',
        () {
      fakeAsync((fa) {
        final controller = _FakeVideoPlayerController();
        final cues = [
          _cue(id: 'c1', atMs: 1000, pause: true),
          _cue(id: 'c2', atMs: 2000, pause: false),
        ];
        final scheduler = CueScheduler(
          controller: controller,
          cues: cues,
          videoId: 'v1',
        )..start();

        controller.positionMs = 820;
        fa.elapse(const Duration(milliseconds: 50));
        fa.flushMicrotasks();
        expect(scheduler.activeCue!.id, 'c1');

        // Resume — play should be called and index advance.
        scheduler.resume();
        fa.flushMicrotasks();
        expect(scheduler.activeCue, isNull);
        expect(scheduler.nextCueIndex, 1);
        expect(controller.playCalls, 1);

        // c2 has pause=false. Move into its window and ensure we don't
        // pause the controller when it fires.
        controller.positionMs = 1820;
        fa.elapse(const Duration(milliseconds: 50));
        fa.flushMicrotasks();
        expect(scheduler.activeCue!.id, 'c2');

        final pausesBeforeResume = controller.pauseCalls;
        final playsBeforeResume = controller.playCalls;
        scheduler.resume();
        fa.flushMicrotasks();
        expect(controller.pauseCalls, pausesBeforeResume,
            reason: 'pause=false cue should not have called pause on resume');
        expect(controller.playCalls, playsBeforeResume,
            reason: 'pause=false cue should not call play on resume');
        expect(scheduler.activeCue, isNull);
        expect(scheduler.nextCueIndex, 2);
        scheduler.dispose();
      });
    });

    test('lifecycle: onAppPaused persists active cue; onAppResumed restores',
        () async {
      final controller = _FakeVideoPlayerController();
      final cues = [_cue(id: 'c1', atMs: 1000)];
      final store = _RecordingCheckpointStore();
      final scheduler = CueScheduler(
        controller: controller,
        cues: cues,
        videoId: 'v1',
        checkpointStore: store,
      );

      // Simulate a cue firing by poking internal state via start + elapse.
      scheduler.start();
      controller.positionMs = 820;
      // Let one tick happen.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(scheduler.activeCue?.id, 'c1');

      // Stop polling first so onAppPaused's save is the last one.
      scheduler.stop();
      await scheduler.onAppPaused();
      final latest = store.saves.last;
      expect(latest.cueId, 'c1');
      expect(latest.videoId, 'v1');
      scheduler.dispose();

      // New scheduler for the same video on resume — should restore the
      // cue from the checkpoint.
      final fresh = CueScheduler(
        controller: _FakeVideoPlayerController(),
        cues: cues,
        videoId: 'v1',
        checkpointStore: store,
      );
      await fresh.onAppResumed();
      expect(fresh.activeCue?.id, 'c1');
      fresh.dispose();
    });

    test('lifecycle: onAppResumed with mismatched videoId is a no-op',
        () async {
      final store = _RecordingCheckpointStore();
      await store.save(const CueCheckpoint(cueId: 'c1', videoId: 'other'));
      final scheduler = CueScheduler(
        controller: _FakeVideoPlayerController(),
        cues: [_cue(id: 'c1', atMs: 1000)],
        videoId: 'v1',
        checkpointStore: store,
      );
      await scheduler.onAppResumed();
      expect(scheduler.activeCue, isNull);
      scheduler.dispose();
    });

    test('dispose is idempotent and cancels the timer', () {
      fakeAsync((fa) {
        final controller = _FakeVideoPlayerController();
        final scheduler = CueScheduler(
          controller: controller,
          cues: [_cue(id: 'c1', atMs: 1000)],
          videoId: 'v1',
        )..start();
        expect(scheduler.isRunning, isTrue);

        scheduler.dispose();
        scheduler.dispose(); // idempotent
        expect(scheduler.isRunning, isFalse);

        // Further ticks do nothing (no timer to elapse into).
        controller.positionMs = 820;
        fa.elapse(const Duration(milliseconds: 200));
        expect(scheduler.activeCue, isNull);
      });
    });

    test('stop does not clear active cue; start after stop resumes polling',
        () {
      fakeAsync((fa) {
        final controller = _FakeVideoPlayerController();
        final scheduler = CueScheduler(
          controller: controller,
          cues: [_cue(id: 'c1', atMs: 1000)],
          videoId: 'v1',
        )..start();

        controller.positionMs = 820;
        fa.elapse(const Duration(milliseconds: 50));
        fa.flushMicrotasks();
        expect(scheduler.activeCue?.id, 'c1');

        scheduler.stop();
        expect(scheduler.isRunning, isFalse);
        // Still active.
        expect(scheduler.activeCue, isNotNull);

        scheduler.start();
        expect(scheduler.isRunning, isTrue);
        scheduler.dispose();
      });
    });

    test('cues passed unsorted are sorted internally', () {
      final scheduler = CueScheduler(
        controller: _FakeVideoPlayerController(),
        cues: [
          _cue(id: 'c3', atMs: 3000),
          _cue(id: 'c1', atMs: 1000),
          _cue(id: 'c2', atMs: 2000),
        ],
        videoId: 'v1',
      );
      expect(scheduler.cueCount, 3);
      scheduler.dispose();
    });
  });
}

class _RecordingCheckpointStore implements CueCheckpointStore {
  CueCheckpoint? _current;
  final List<CueCheckpoint> saves = <CueCheckpoint>[];

  @override
  Future<void> save(CueCheckpoint checkpoint) async {
    saves.add(checkpoint);
    _current = checkpoint;
  }

  @override
  Future<CueCheckpoint?> load() async => _current;

  @override
  Future<void> clear() async {
    _current = null;
  }
}
