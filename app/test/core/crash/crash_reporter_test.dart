import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lifestream_doctor/lifestream_doctor.dart';
import 'package:lifestream_learn_app/core/crash/crash_reporter.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

/// Helper to build an *enabled* reporter backed by a real
/// `LifestreamDoctor` but with HTTP stubbed out. Used to cover the
/// enabled-mode branches of `CrashReporter` without hitting the
/// network.
CrashReporter _enabledReporter({required http.Client httpClient}) {
  final doctor = LifestreamDoctor(
    apiUrl: 'https://vault.example.com',
    vaultId: 'learn-crashes',
    apiKey: 'lsv_k_test',
    enabled: true,
    httpClient: httpClient,
    storage: MemoryStorage(),
  );
  return CrashReporter.forTesting(doctor: doctor, enabled: true);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  // Preserve the production error hooks so our test doesn't leak.
  FlutterExceptionHandler? originalFlutterErrorOnError;
  bool Function(Object, StackTrace)? originalPlatformOnError;

  setUp(() {
    originalFlutterErrorOnError = FlutterError.onError;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = originalFlutterErrorOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  });

  group('CrashReporter.disabled()', () {
    test('enabled flag is false', () {
      final reporter = CrashReporter.disabled();
      expect(reporter.enabled, isFalse);
    });

    test('captureException is a no-op and does not throw', () async {
      final reporter = CrashReporter.disabled();
      await expectLater(
        reporter.captureException(Exception('boom'),
            stackTrace: StackTrace.current),
        completes,
      );
    });

    test('grant / revoke are no-ops and do not throw', () async {
      final reporter = CrashReporter.disabled();
      await expectLater(reporter.grant(), completes);
      await expectLater(reporter.revoke(), completes);
    });

    test('bootstrap does nothing observable', () async {
      final reporter = CrashReporter.disabled();
      await expectLater(reporter.bootstrap(), completes);
    });

    test('flushQueue is a no-op', () async {
      final reporter = CrashReporter.disabled();
      await expectLater(reporter.flushQueue(), completes);
    });

    test('installErrorHooks does not touch Flutter handlers', () {
      // Tag the current handlers so we can detect a change.
      FlutterError.onError = (_) {};
      final marker = FlutterError.onError;
      final platformMarker = PlatformDispatcher.instance.onError;

      CrashReporter.disabled().installErrorHooks();

      expect(FlutterError.onError, same(marker));
      expect(PlatformDispatcher.instance.onError, same(platformMarker));
    });

    test('routerObserver records navigation without throwing', () {
      final reporter = CrashReporter.disabled();
      final observer = reporter.routerObserver;
      // Invoke the observer methods directly — they should silently
      // no-op when the reporter is disabled.
      observer.didPush(
        MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
          settings: const RouteSettings(name: '/foo'),
        ),
        null,
      );
      observer.didPop(
        MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
          settings: const RouteSettings(name: '/foo'),
        ),
        null,
      );
      observer.didReplace(
        newRoute: MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
          settings: const RouteSettings(name: '/bar'),
        ),
      );
      // No expectation beyond "did not throw" — the observer writes to
      // the SDK's breadcrumb buffer which isn't publicly readable.
    });
  });

  group('CrashReporter enabled path', () {
    test('bootstrap sets device context and triggers flushQueue',
        () async {
      final http_ = _MockHttpClient();
      // flushQueue is a no-op over an empty queue, so we don't need to
      // stub any requests here.
      final reporter = _enabledReporter(httpClient: http_);
      await reporter.bootstrap();
      // No throw + reporter is still enabled.
      expect(reporter.enabled, isTrue);
    });

    test('installErrorHooks assigns Flutter error handlers', () {
      // Mark the current handlers so we can detect that install
      // replaces them.
      FlutterError.onError = (_) {};
      final marker = FlutterError.onError;

      final reporter = _enabledReporter(httpClient: _MockHttpClient());
      reporter.installErrorHooks();

      expect(FlutterError.onError, isNot(same(marker)));
      expect(PlatformDispatcher.instance.onError, isNotNull);
    });

    test('installed error handlers forward to captureException', () {
      final http_ = _MockHttpClient();
      when(() => http_.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('err', 500));

      final reporter = _enabledReporter(httpClient: http_);
      reporter.installErrorHooks();

      // Fire a Flutter framework error and a zone error — both should
      // be swallowed by the installed handlers without rethrowing.
      FlutterError.reportError(FlutterErrorDetails(
        exception: Exception('flutter-err'),
        stack: StackTrace.current,
        library: 'test',
      ));
      final platform = PlatformDispatcher.instance.onError;
      expect(platform, isNotNull);
      final handled =
          platform!(Exception('platform-err'), StackTrace.current);
      expect(handled, isTrue);
    });

    test('grant + revoke drive the underlying SDK without throwing',
        () async {
      final reporter = _enabledReporter(httpClient: _MockHttpClient());
      await reporter.grant();
      await reporter.revoke();
      // Re-grant + flush covers the flushQueue enabled branch.
      await reporter.grant();
      await reporter.flushQueue();
    });

    test('captureException in enabled mode completes without throwing',
        () async {
      final http_ = _MockHttpClient();
      // A 500 response makes the queue enqueue the report without
      // requiring stubbed responses we'd have to parse.
      when(() => http_.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('err', 500));

      final reporter = _enabledReporter(httpClient: http_);
      await reporter.grant();
      await expectLater(
        reporter.captureException(Exception('test'),
            stackTrace: StackTrace.current),
        completes,
      );
    });

    test('routerObserver emits breadcrumbs in enabled mode', () {
      final reporter = _enabledReporter(httpClient: _MockHttpClient());
      final observer = reporter.routerObserver;
      observer.didPush(
        MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
          settings: const RouteSettings(name: '/one'),
        ),
        null,
      );
      observer.didReplace(
        newRoute: MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
          settings: const RouteSettings(name: '/two'),
        ),
      );
      // Breadcrumbs go into the SDK's private buffer, so we just
      // confirm the calls don't throw.
    });
  });
}
