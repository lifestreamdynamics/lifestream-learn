/// DateTime helpers used across the app.
extension DateTimeX on DateTime {
  /// UTC ISO-8601 representation. Shorthand for
  /// `toUtc().toIso8601String()`, used by analytics sinks and the
  /// session-marker events in main.dart.
  String toUtcIso8601() => toUtc().toIso8601String();
}

/// Month names in the learner's locale — English only today. When
/// `flutter_localizations` + ARB lands (out of scope for Slice P1),
/// this table moves into the generated messages class.
const List<String> _englishMonthLongNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Member since April 2026" — used by the profile header. Accepts any
/// DateTime and renders in the system's local zone. Returns an empty
/// string for null inputs so the caller can render the widget
/// unconditionally without a null check.
String formatMemberSinceMonthYear(DateTime? when) {
  if (when == null) return '';
  final local = when.toLocal();
  // Month is 1-indexed in Dart; the name table is 0-indexed.
  final monthIdx = (local.month - 1).clamp(0, 11);
  return '${_englishMonthLongNames[monthIdx]} ${local.year}';
}
