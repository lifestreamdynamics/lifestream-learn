import 'package:flutter/material.dart';

/// Single source of truth for brand color literals. Every other file in the
/// codebase MUST reference colors through `Theme.of(context).colorScheme`
/// (or `BrandGradients.*` / `BrandColors.darkBg` for scaffold-level surfaces
/// where a ColorScheme token would lose the exact brand value).
class BrandColors {
  BrandColors._();

  // Dark mode
  static const Color darkBg = Color(0xFF050A14);
  static const Color darkSurface = Color(0xFF0F1724);
  static const Color cyan400 = Color(0xFF22D3EE); // dark-mode primary
  static const Color sky400 = Color(0xFF38BDF8); // dark-mode secondary
  static const Color cyan200 = Color(0xFFA5F3FC); // accent/highlight

  // Light mode
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color cyan700 = Color(0xFF0891B2); // light-mode primary
  static const Color sky600 = Color(0xFF0284C7); // light-mode secondary

  // Material 3 seed (derives the tonal palette for tertiary/error/etc.)
  static const Color seed = Color(0xFF22D3EE);
}
