/// DateTime helpers used across the app.
extension DateTimeX on DateTime {
  /// UTC ISO-8601 representation. Shorthand for
  /// `toUtc().toIso8601String()`, used by analytics sinks and the
  /// session-marker events in main.dart.
  String toUtcIso8601() => toUtc().toIso8601String();
}
