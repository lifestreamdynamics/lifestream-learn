/// Duration helpers shared across learner/designer UIs.
library;

/// Format a millisecond value as `MM:SS` — zero-padded, never truncated.
/// Used by the Enrolled-courses list ("Last watched at 02:34") and the
/// course-detail video list ("Video length 05:00"). Keeping one
/// implementation prevents the two call sites from drifting when we
/// eventually add hours ("HH:MM:SS") or localisation.
///
/// [ms] is clamped to a non-negative value — callers pass
/// `VideoPlayer.position.inMilliseconds` which can briefly report
/// negative values during seek; that should render as `00:00`, not
/// `-01:23`.
String formatDurationMs(int ms) {
  final nonNegative = ms < 0 ? 0 : ms;
  final secs = nonNegative ~/ 1000;
  final mm = (secs ~/ 60).toString().padLeft(2, '0');
  final ss = (secs % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// Format a millisecond watch-time total into human-readable hours +
/// minutes, e.g. `2h 15m`. Values under one minute render as `<1m`.
///
/// Used by the profile's progress overview card ("total watch time"). The
/// output intentionally rounds aggressively — the underlying number is an
/// approximation (sum of completed video durations) so sub-minute
/// precision would be false precision.
String formatWatchTimeMs(int ms) {
  if (ms <= 0) return '0m';
  final totalMinutes = ms ~/ 60000;
  if (totalMinutes == 0) return '<1m';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
