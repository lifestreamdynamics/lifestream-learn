import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/theme/app_theme.dart';
import 'package:lifestream_learn_app/core/theme/brand_colors.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses M3 and brand light primary', () {
      final t = AppTheme.light;
      expect(t.useMaterial3, isTrue);
      expect(t.colorScheme.primary, BrandColors.cyan700);
      expect(t.colorScheme.secondary, BrandColors.sky600);
      expect(t.scaffoldBackgroundColor, BrandColors.lightBg);
    });

    test('dark theme uses M3 and brand dark primary', () {
      final t = AppTheme.dark;
      expect(t.useMaterial3, isTrue);
      expect(t.colorScheme.primary, BrandColors.cyan400);
      expect(t.colorScheme.secondary, BrandColors.sky400);
      expect(t.scaffoldBackgroundColor, BrandColors.darkBg);
    });

    test('component themes are attached (smoke)', () {
      final t = AppTheme.dark;
      expect(t.cardTheme, isNotNull);
      expect(t.filledButtonTheme, isNotNull);
      expect(t.inputDecorationTheme, isNotNull);
      expect(t.navigationBarTheme, isNotNull);
      expect(t.appBarTheme, isNotNull);
    });

    test('button shape is stadium', () {
      final style = AppTheme.dark.filledButtonTheme.style!;
      // Resolved default shape should be StadiumBorder.
      final shape = style.shape!.resolve({});
      expect(shape, isA<StadiumBorder>());
    });
  });
}
