import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// Cyan-to-sky linear gradients. Use on hero CTAs and the video-player
/// progress bar. Keep gradient usage rare — restraint is the style rule.
class BrandGradients {
  BrandGradients._();

  static const LinearGradient primary = LinearGradient(
    colors: [BrandColors.cyan400, BrandColors.sky400],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Softer variant for subtle surfaces (progress fill, focus rings).
  static LinearGradient get primarySubtle => LinearGradient(
        colors: [
          BrandColors.cyan400.withValues(alpha: 0.85),
          BrandColors.sky400.withValues(alpha: 0.85),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
}
