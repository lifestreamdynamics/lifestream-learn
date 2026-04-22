import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'component_themes.dart';

/// App theme entry point. Composed from:
///   - [BrandColors] (hex constants, single source of truth)
///   - Material 3 ColorScheme derivation with brand-specific overrides
///   - [buildComponentThemes] (stadium buttons, rounded cards, etc.)
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: BrandColors.seed,
      brightness: brightness,
    );

    final scheme = brightness == Brightness.dark
        ? base.copyWith(
            primary: BrandColors.cyan400,
            secondary: BrandColors.sky400,
            surface: BrandColors.darkSurface,
          )
        : base.copyWith(
            primary: BrandColors.cyan700,
            secondary: BrandColors.sky600,
            surface: BrandColors.lightSurface,
          );

    final components = buildComponentThemes(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? BrandColors.darkBg
          : BrandColors.lightBg,
      filledButtonTheme: components.filledButtonTheme,
      elevatedButtonTheme: components.elevatedButtonTheme,
      outlinedButtonTheme: components.outlinedButtonTheme,
      textButtonTheme: components.textButtonTheme,
      cardTheme: components.cardTheme,
      appBarTheme: components.appBarTheme,
      inputDecorationTheme: components.inputDecorationTheme,
      navigationBarTheme: components.navigationBarTheme,
      chipTheme: components.chipTheme,
      dialogTheme: components.dialogTheme,
      bottomSheetTheme: components.bottomSheetTheme,
      snackBarTheme: components.snackBarTheme,
      progressIndicatorTheme: components.progressIndicatorTheme,
      segmentedButtonTheme: components.segmentedButtonTheme,
    );
  }
}
