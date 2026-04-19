import 'package:flutter/material.dart';

/// Material 3 light + dark themes. Kept intentionally minimal for Slice C —
/// Slice D will revisit once the feed UI has real chrome.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E60CE),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E60CE),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}
