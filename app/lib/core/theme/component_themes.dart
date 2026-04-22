import 'package:flutter/material.dart';

import 'brand_radii.dart';

/// Named return type for [buildComponentThemes].
///
/// A plain class rather than a Dart 3 record so that test code can reference
/// the type by name and IDE autocomplete enumerates the fields cleanly.
class AppComponentThemes {
  const AppComponentThemes({
    required this.filledButtonTheme,
    required this.elevatedButtonTheme,
    required this.outlinedButtonTheme,
    required this.textButtonTheme,
    required this.cardTheme,
    required this.appBarTheme,
    required this.inputDecorationTheme,
    required this.navigationBarTheme,
    required this.chipTheme,
    required this.dialogTheme,
    required this.bottomSheetTheme,
    required this.snackBarTheme,
    required this.progressIndicatorTheme,
    required this.segmentedButtonTheme,
  });

  final FilledButtonThemeData filledButtonTheme;
  final ElevatedButtonThemeData elevatedButtonTheme;
  final OutlinedButtonThemeData outlinedButtonTheme;
  final TextButtonThemeData textButtonTheme;
  // Flutter 3.27+ renamed CardTheme → CardThemeData (confirmed for 3.41.5).
  final CardThemeData cardTheme;
  final AppBarTheme appBarTheme;
  final InputDecorationTheme inputDecorationTheme;
  final NavigationBarThemeData navigationBarTheme;
  final ChipThemeData chipTheme;
  // Flutter 3.27+ renamed DialogTheme → DialogThemeData (confirmed for 3.41.5).
  final DialogThemeData dialogTheme;
  final BottomSheetThemeData bottomSheetTheme;
  final SnackBarThemeData snackBarTheme;
  final ProgressIndicatorThemeData progressIndicatorTheme;
  final SegmentedButtonThemeData segmentedButtonTheme;
}

/// Builds all component-level theme overrides for a given [ColorScheme].
///
/// Called once each for [Brightness.light] and [Brightness.dark] in
/// [AppTheme._build]. Keeping the construction function stateless makes it
/// straightforward to unit-test each component theme in isolation.
AppComponentThemes buildComponentThemes(ColorScheme scheme) {
  return AppComponentThemes(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 48),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    appBarTheme: AppBarTheme(
      surfaceTintColor: Colors.transparent,
      backgroundColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: scheme.error),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.2),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary);
        }
        return IconThemeData(color: scheme.onSurfaceVariant);
      }),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      selectedColor: scheme.primaryContainer,
      backgroundColor: scheme.surfaceContainerHigh,
      labelStyle: TextStyle(color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusLg)),
      ),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
      ),
    ),
  );
}
