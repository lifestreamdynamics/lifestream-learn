import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';

/// Polls `GET /api/videos/:id` until the status is terminal (READY or
/// FAILED). Intended lifetime: wrap with a `ValueListenableBuilder` in
/// the designer UI, dispose when the caller no longer needs updates.
///
/// Default poll interval is 3s — matches the roadmap. Exposed as a
/// parameter for tests.
class VideoStatusPoller extends ChangeNotifier {
  VideoStatusPoller({
    required this.videoId,
    required this.videoRepo,
    this.interval = const Duration(seconds: 3),
  });

  final String videoId;
  final VideoRepository videoRepo;
  final Duration interval;

  VideoSummary? _current;
  VideoSummary? get current => _current;

  Object? _error;
  Object? get error => _error;

  Timer? _timer;
  bool _disposed = false;

  bool get isTerminal {
    final s = _current?.status;
    return s == VideoStatus.ready || s == VideoStatus.failed;
  }

  void start() {
    if (_disposed) return;
    _timer ??= Timer.periodic(interval, (_) => _tick());
    // Prime the pump immediately so the UI shows something before the
    // first interval elapses.
    unawaited(_tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_disposed) return;
    try {
      final v = await videoRepo.get(videoId);
      if (_disposed) return;
      _current = v;
      _error = null;
      notifyListeners();
      if (isTerminal) {
        stop();
      }
    } catch (e) {
      if (_disposed) return;
      _error = e;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
