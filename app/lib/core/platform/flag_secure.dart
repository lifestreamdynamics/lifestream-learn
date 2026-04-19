import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper over the `com.lifestream.learn/flag_secure` method
/// channel. Toggling FLAG_SECURE prevents the window from being
/// screenshot, screen-recorded, or shown in the Recents thumbnail —
/// we enable it around screens that display sensitive content:
/// - Cue overlays (would leak quiz answers if screenshotted).
/// - Admin analytics / applications screens (PII).
///
/// Contract: each call to [enable] MUST be paired with a [disable] on
/// screen teardown, otherwise a subsequent screenshot in a context
/// that should be allowed (e.g. the feed) would fail silently.
///
/// iOS/web fall through as no-ops; we only ship Android today.
class FlagSecure {
  const FlagSecure._();

  static const MethodChannel _channel = MethodChannel(
    'com.lifestream.learn/flag_secure',
  );

  /// Override for tests — points the class at a stubbed channel so
  /// `setMockMethodCallHandler` can see calls without reaching the
  /// platform plugin. Null in production.
  @visibleForTesting
  static MethodChannel? testChannel;

  static MethodChannel get _effective => testChannel ?? _channel;

  /// Whether the current runtime is Android (the only platform that
  /// actually honours the flag). Split into a getter so tests on the
  /// host VM can override via [FlagSecure.testChannel].
  static bool get _isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  static Future<void> enable() async {
    if (testChannel != null) {
      await testChannel!.invokeMethod<void>('enable');
      return;
    }
    if (!_isAndroid) return;
    try {
      await _effective.invokeMethod<void>('enable');
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('FlagSecure.enable failed: $e');
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('FlagSecure.enable missing plugin: $e');
    }
  }

  static Future<void> disable() async {
    if (testChannel != null) {
      await testChannel!.invokeMethod<void>('disable');
      return;
    }
    if (!_isAndroid) return;
    try {
      await _effective.invokeMethod<void>('disable');
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('FlagSecure.disable failed: $e');
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('FlagSecure.disable missing plugin: $e');
    }
  }
}
