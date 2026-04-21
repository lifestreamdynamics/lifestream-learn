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
