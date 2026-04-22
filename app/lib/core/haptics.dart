import 'package:flutter/services.dart';

/// Static haptic wrappers. Respects the app-wide reduce-motion setting
/// (managed in SettingsCubit); when disabled, all calls are no-ops.
class Haptics {
  Haptics._();

  static bool enabled = true;

  static Future<void> selection() async {
    if (!enabled) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> light() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
  }
}
