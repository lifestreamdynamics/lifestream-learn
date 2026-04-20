import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lifestream_doctor/lifestream_doctor.dart';

import '../../config/crash_reporting_config.dart';
import '../utils/date_formatters.dart';
import 'secure_storage_backend.dart';

/// Thin façade over the `lifestream_doctor` SDK.
///
/// Bundles (1) SDK construction with the app's compile-time config, (2)
/// Flutter error-hook installation, and (3) a [NavigatorObserver] that
/// records navigation breadcrumbs. All three pieces ship together so
/// `main.dart` only needs to call [bootstrap] + [installErrorHooks] and
/// hand [routerObserver] to GoRouter.
///
/// When [CrashReportingConfig.hasCrashReportingConfig] is false the SDK
/// is constructed in `enabled: false` mode — capture calls silently
/// no-op, `grant()` / `revoke()` are safe to call, and no network
/// traffic is produced. This lets the app ship before the
/// `learn-crashes` vault + API key are provisioned.
class CrashReporter {
  CrashReporter._(this._doctor, {required this.enabled});

  /// Builds a [CrashReporter] configured from [CrashReportingConfig].
  ///
  /// [storage] is the `FlutterSecureStorage` the rest of the app already
  /// uses for auth tokens — passing it in avoids a second encrypted
  /// store. In tests, pass [doctorOverride] to inject a fake.
  factory CrashReporter.fromConfig({
    required FlutterSecureStorage storage,
    LifestreamDoctor? doctorOverride,
  }) {
    final enabled = CrashReportingConfig.hasCrashReportingConfig;
    final doctor = doctorOverride ??
        LifestreamDoctor(
          apiUrl: CrashReportingConfig.crashApiUrl,
          vaultId: CrashReportingConfig.crashVaultId,
          apiKey: CrashReportingConfig.crashApiKey,
          enabled: enabled,
          environment: kDebugMode ? 'development' : 'production',
          tags: const ['mobile', 'flutter', 'learn'],
          storage: SecureStorageBackend(storage),
          debug: kDebugMode,
        );
    return CrashReporter._(doctor, enabled: enabled);
  }

  /// A disabled reporter for tests and the placeholder-key path. All
  /// capture calls are no-ops.
  factory CrashReporter.disabled() {
    final doctor = LifestreamDoctor(
      apiUrl: '',
      vaultId: '',
      apiKey: '',
      enabled: false,
    );
    return CrashReporter._(doctor, enabled: false);
  }

  /// Test-only constructor that lets a suite inject a fully-constructed
  /// [LifestreamDoctor] in either enabled or disabled mode. Keeps the
  /// production entry points honest (`fromConfig` + `disabled`) while
  /// giving tests a way to cover the `enabled == true` branches.
  @visibleForTesting
  factory CrashReporter.forTesting({
    required LifestreamDoctor doctor,
    required bool enabled,
  }) =>
      CrashReporter._(doctor, enabled: enabled);

  final LifestreamDoctor _doctor;

  /// Whether the underlying SDK is in enabled mode.
  final bool enabled;

  /// Expose the underlying SDK for callers that need lower-level
  /// behaviour (e.g. the consent bloc's `grantConsent` + breadcrumb
  /// injection). Prefer the pass-through methods below for the common
  /// cases.
  LifestreamDoctor get doctor => _doctor;

  /// Configures the device-context provider and drains any queued
  /// reports persisted by a previous session. Safe to call from an
  /// unawaited context — errors are swallowed because they'd just
  /// re-enter the global error handler.
  Future<void> bootstrap() async {
    if (!enabled) return;
    _doctor.setDeviceContextProvider(getDartIoDeviceContext);
    try {
      await _doctor.flushQueue();
    } catch (_) {
      // Queue flush failures are non-fatal — the queue entries remain
      // on disk and will be retried on the next resume / flush.
    }
  }

  /// Installs Flutter's global error handlers so framework and
  /// uncaught platform errors are captured.
  ///
  /// Callers must also wrap `runApp(...)` in [runZonedGuarded] to catch
  /// uncaught zone errors — see `main.dart` for the complete wiring.
  void installErrorHooks() {
    if (!enabled) return;
    FlutterError.onError = (details) {
      _doctor.captureException(
        details.exception,
        stackTrace: details.stack,
        severity: Severity.fatal,
        extra: <String, Object?>{'library': details.library},
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _doctor.captureException(
        error,
        stackTrace: stack,
        severity: Severity.fatal,
      );
      return true;
    };
  }

  /// GoRouter-compatible navigator observer that records a
  /// `navigation` breadcrumb on each push / pop / replace.
  NavigatorObserver get routerObserver => _CrashBreadcrumbObserver(this);

  /// Pass-through for zone-level captures (used by `runZonedGuarded`).
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    Severity severity = Severity.fatal,
  }) {
    if (!enabled) return Future<void>.value();
    return _doctor.captureException(
      error,
      stackTrace: stackTrace,
      severity: severity,
    );
  }

  /// Drains the offline queue. Call on app resume + on network
  /// recovery.
  Future<void> flushQueue() async {
    if (!enabled) return;
    try {
      await _doctor.flushQueue();
    } catch (_) {
      // Same rationale as [bootstrap]: failures stay on disk.
    }
  }

  /// Called by the consent bloc when the user grants consent.
  Future<void> grant() async {
    if (!enabled) return;
    await _doctor.grantConsent();
    _doctor.setConsentPreVerified();
  }

  /// Rehydrates the SDK's in-memory pre-verified flag without writing
  /// to storage. Used by the consent bloc on app launch when the
  /// persisted decision is already "granted" — the `consent` key is
  /// already set from the grant that produced the persisted decision.
  void setConsentPreVerified() {
    if (!enabled) return;
    _doctor.setConsentPreVerified();
  }

  /// Called by the consent bloc when the user revokes consent.
  Future<void> revoke() async {
    if (!enabled) return;
    await _doctor.revokeConsent();
  }

  /// Records a navigation breadcrumb. Made public so the observer +
  /// future feature-flag or HTTP breadcrumbs can reuse it.
  void addNavigationBreadcrumb(String message) {
    if (!enabled) return;
    _doctor.addBreadcrumb(Breadcrumb(
      timestamp: DateTime.now().toUtcIso8601(),
      type: 'navigation',
      message: message,
    ));
  }
}

class _CrashBreadcrumbObserver extends NavigatorObserver {
  _CrashBreadcrumbObserver(this._reporter);

  final CrashReporter _reporter;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _reporter.addNavigationBreadcrumb(
      'push ${route.settings.name ?? '<unnamed>'}',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _reporter.addNavigationBreadcrumb(
      'pop ${route.settings.name ?? '<unnamed>'}',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _reporter.addNavigationBreadcrumb(
      'replace ${newRoute?.settings.name ?? '<unnamed>'}',
    );
  }
}
