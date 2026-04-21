import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/http/error_envelope.dart';
import '../../data/repositories/events_repository.dart';
import 'analytics_event.dart';

/// Keys in `payload` that signal the caller is about to send a raw
/// learner response — we reject those events. The set is deliberately
/// conservative and compile-time; extending it is a follow-up.
///
/// The design contract is that payloads are STRUCTURAL only (things like
/// `{cueType: 'MCQ', correct: true}`). Free text belongs in the backend's
/// `Attempt.scoreJson` — never in telemetry.
///
/// This guard is a seatbelt, not a primary defense. Callers must never
/// rely on it to catch a bug; the *design* must never require it to fire.
const Set<String> _piiKeys = <String>{
  'answer',
  'response',
  'input',
  'text',
  'content',
};

/// Any string value longer than this length is treated as free text and
/// the whole event is rejected. 128 chars is generous enough for
/// structural enum values ("BLANKS", "cue_answered", a uuid, etc.) but
/// short enough that a user-typed MCQ response can't hide in here.
const int _maxStringValueLength = 128;

/// Capacity threshold that triggers an immediate flush (in addition to
/// the 30s periodic and lifecycle-paused flushes). 50 events keeps the
/// on-disk buffer bounded during a burst (e.g. a fast-paced cue quiz)
/// without hammering the backend on every single event.
const int _flushSoftLimit = 50;

/// Periodic flush cadence. 30s is a deliberate trade between fresh
/// dashboards and battery: each flush is a single HTTPS round-trip and
/// the batch pays for itself at ~3 events or more. Don't bump this
/// without considering the admin-dashboard freshness contract.
const Duration _flushInterval = Duration(seconds: 30);

/// Initial retry delay after a 5xx / network error. Doubles on each
/// subsequent failure up to [_retryCap]. The first retry fires on the
/// next periodic tick at-or-after `lastFailureAt + currentBackoff`.
const Duration _retryInitial = Duration(seconds: 10);

/// Retry delay cap. Matches the roadmap spec.
const Duration _retryCap = Duration(minutes: 5);

/// Hard cap on events submitted per POST (backend accepts 1..100).
const int _maxBatchSize = 100;

/// Abstract path source so tests can inject a temp directory without
/// touching the real `path_provider` plugin.
typedef DocsDirResolver = Future<Directory> Function();

/// Predicate consulted before each flush. Returns `true` when the buffer
/// is allowed to POST — typically "is the user authenticated". When
/// `false`, the flush short-circuits WITHOUT consuming or dropping any
/// queued events; they stay on disk until the next tick finds the gate
/// open. The default predicate (`() => true`) is a no-op gate used by
/// tests and by callers that don't need auth-gating.
typedef FlushGate = bool Function();

/// Offline-survivable analytics buffer.
///
/// The buffer's central invariant: **every event the app asks to log is
/// either POSTed to the backend or persisted on disk in the app's
/// private documents directory.** Nothing is kept only in RAM. The
/// JSON file is the single source of truth; the in-memory queue is a
/// cache that's rebuilt from the file on [hydrate].
///
/// Flush triggers:
/// 1. [startPeriodic] installs a 30s `Timer.periodic`.
/// 2. [log] triggers an immediate flush when the queue crosses
///    [_flushSoftLimit] events.
/// 3. The owning widget calls [flush] on `AppLifecycleState.paused`.
///
/// Retry policy (5xx / network):
/// - Exponential backoff starting at 10s, doubling, capped at 5m.
/// - `_retryAfter` records the earliest time the next flush is
///   permitted. Earlier flushes short-circuit with a warning.
///
/// Privacy guard: [log] inspects `payload` for [_piiKeys] or over-long
/// string values and rejects matching events with `debugPrint`.
class AnalyticsBuffer {
  AnalyticsBuffer({
    required EventsRepository repo,
    DocsDirResolver? docsDirResolver,
    String fileName = 'analytics_buffer.json',
    FlushGate? canFlush,
  })  : _repo = repo,
        _docsDirResolver =
            docsDirResolver ?? getApplicationDocumentsDirectory,
        _fileName = fileName,
        _canFlush = canFlush ?? _alwaysOpen;

  static bool _alwaysOpen() => true;

  final EventsRepository _repo;
  final DocsDirResolver _docsDirResolver;
  final String _fileName;
  final FlushGate _canFlush;

  final List<AnalyticsEvent> _queue = <AnalyticsEvent>[];
  Timer? _periodic;
  DateTime? _retryAfter;
  Duration _currentBackoff = _retryInitial;
  bool _flushing = false;
  bool _disposed = false;

  /// Exposed for tests — size of the in-memory queue.
  @visibleForTesting
  int get queueLength => _queue.length;

  /// Exposed for tests — earliest time a future flush is permitted.
  @visibleForTesting
  DateTime? get retryAfter => _retryAfter;

  /// Exposed for tests — current backoff (doubles on each failure).
  @visibleForTesting
  Duration get currentBackoff => _currentBackoff;

  /// Exposed for tests — whether the periodic timer is installed.
  @visibleForTesting
  bool get isPeriodic => _periodic != null;

  /// Read the persistent store and append its contents to the in-memory
  /// queue. Call once at app startup *before* [startPeriodic]; a
  /// subsequent [flush] will drain the persisted events.
  ///
  /// Missing / empty / malformed files are treated as "empty buffer" —
  /// there's no sane recovery from a corrupted analytics buffer and we'd
  /// rather lose that telemetry than crash the app.
  Future<void> hydrate() async {
    if (_disposed) return;
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      if (raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          _queue.add(AnalyticsEvent.fromJson(item));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('AnalyticsBuffer.hydrate: skipping bad row: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AnalyticsBuffer.hydrate failed: $e');
      }
    }
  }

  /// Queue an event for flushing. Validates the privacy guard first —
  /// rejected events are DROPPED (logged via debugPrint in debug mode).
  /// On accept, the event is appended to both the in-memory queue and
  /// the persistent file. If the queue crosses [_flushSoftLimit], a
  /// non-blocking flush is kicked off.
  Future<void> log(AnalyticsEvent event) async {
    if (_disposed) return;
    if (!_passesPrivacyGuard(event)) {
      if (kDebugMode) {
        debugPrint(
          'AnalyticsBuffer: privacy guard rejected event '
          '(${event.eventType}) — payload contained banned key or '
          'over-long string',
        );
      }
      return;
    }
    _queue.add(event);
    await _persist();
    if (_queue.length >= _flushSoftLimit) {
      // Don't await: callers log from UI code paths and we never want
      // the UI thread to block on an HTTP round-trip.
      unawaited(flush());
    }
  }

  /// Start the 30s periodic flush. Idempotent — calling twice installs
  /// just one timer.
  void startPeriodic() {
    if (_disposed) return;
    if (_periodic != null) return;
    _periodic = Timer.periodic(_flushInterval, (_) => flush());
  }

  /// Pop up to [_maxBatchSize] events and POST them. Called by the
  /// periodic timer, by the soft-limit trigger in [log], and by the
  /// owning widget's `AppLifecycleState.paused` handler.
  ///
  /// Concurrency: re-entrant calls short-circuit (single-flight). This
  /// avoids double-draining the queue on the rare case where a
  /// capacity-triggered flush races a periodic tick.
  Future<void> flush() async {
    if (_disposed) return;
    if (_flushing) return;
    if (_queue.isEmpty) return;
    if (!_canFlush()) {
      // Gate closed (typically: user not authenticated). Leave the queue
      // intact on disk — no retry scheduled, no events dropped — and
      // return. When the gate opens, the next tick (or an explicit
      // flush()) will drain.
      if (kDebugMode) {
        debugPrint(
          'AnalyticsBuffer.flush skipped — flush gate closed '
          '(queueLen=${_queue.length})',
        );
      }
      return;
    }
    final now = DateTime.now();
    if (_retryAfter != null && now.isBefore(_retryAfter!)) {
      if (kDebugMode) {
        debugPrint(
          'AnalyticsBuffer.flush skipped — retry gate until $_retryAfter',
        );
      }
      return;
    }
    _flushing = true;
    try {
      final batch = _queue.take(_maxBatchSize).toList(growable: false);
      try {
        await _repo.submitBatch(batch);
        // Success — drop the submitted events and reset backoff.
        _queue.removeRange(0, batch.length);
        await _persist();
        _retryAfter = null;
        _currentBackoff = _retryInitial;
      } on ApiException catch (e) {
        if (e.statusCode >= 400 && e.statusCode < 500) {
          // 4xx — batch is bad (validation error, auth, etc). Drop it
          // and log; keep subsequent events going. Per roadmap: do NOT
          // schedule a retry on 4xx.
          if (kDebugMode) {
            debugPrint(
              'AnalyticsBuffer: dropping ${batch.length} events — '
              'server rejected (${e.statusCode} ${e.code}: ${e.message})',
            );
          }
          _queue.removeRange(0, batch.length);
          await _persist();
          _retryAfter = null;
          _currentBackoff = _retryInitial;
        } else {
          // 5xx or network error — keep the queue, schedule a retry.
          _scheduleRetry();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('AnalyticsBuffer.flush unexpected error: $e');
        }
        _scheduleRetry();
      }
    } finally {
      _flushing = false;
    }
  }

  void _scheduleRetry() {
    final now = DateTime.now();
    _retryAfter = now.add(_currentBackoff);
    if (kDebugMode) {
      debugPrint(
        'AnalyticsBuffer: retry scheduled in $_currentBackoff '
        '(queueLen=${_queue.length})',
      );
    }
    // Double for next failure, cap at _retryCap.
    final doubled = _currentBackoff * 2;
    _currentBackoff = doubled > _retryCap ? _retryCap : doubled;
  }

  /// Tear down. Cancels the periodic timer, clears the in-memory
  /// queue, and blocks further logs. Does NOT delete the persistent
  /// file — a fresh buffer instance picks up where we left off on the
  /// next launch.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _periodic?.cancel();
    _periodic = null;
  }

  // --- internals --------------------------------------------------------

  bool _passesPrivacyGuard(AnalyticsEvent event) {
    final payload = event.payload;
    if (payload == null) return true;
    for (final entry in payload.entries) {
      if (_piiKeys.contains(entry.key)) return false;
      final value = entry.value;
      if (value is String && value.length > _maxStringValueLength) {
        return false;
      }
    }
    return true;
  }

  Future<File> _file() async {
    final dir = await _docsDirResolver();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _persist() async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode(_queue.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (e) {
      // A broken filesystem is unfortunate but not fatal — we still
      // keep the in-memory queue so the current session can flush.
      if (kDebugMode) {
        debugPrint('AnalyticsBuffer._persist failed: $e');
      }
    }
  }
}
