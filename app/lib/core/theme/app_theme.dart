import 'package:flutter/material.dart';

/// Material 3 light + dark themes.
///
/// The seed color is Indigo-600 (`#4F46E5`) — placeholder that matches the
/// adaptive-icon background. Designer can override later by editing this
/// file and the splash/launcher-icon YAML side-by-side (both read the
/// same hex so the app's chrome stays in sync with its icon).
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF4F46E5);

  static ThemeData get light => ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.light,
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      );
}
