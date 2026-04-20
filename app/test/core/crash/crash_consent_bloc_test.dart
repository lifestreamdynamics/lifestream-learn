import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/crash/crash_consent_bloc.dart';
import 'package:lifestream_learn_app/core/crash/crash_reporter.dart';
import 'package:lifestream_learn_app/core/crash/secure_storage_backend.dart';

import '../../test_support/fake_secure_storage.dart';

void main() {
  late FakeSecureStoragePlatform fake;
  late SecureStorageBackend storage;
  late CrashReporter reporter;

  setUp(() {
    fake = FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = fake;
    storage = SecureStorageBackend(const FlutterSecureStorage());
    // Disabled reporter keeps grant()/revoke() as no-ops so the bloc
    // test focuses on state + persistence.
    reporter = CrashReporter.disabled();
  });

  CrashConsentBloc buildBloc() =>
      CrashConsentBloc(reporter: reporter, storage: storage);

  test('initial state is undecided', () {
    expect(buildBloc().state, CrashConsentStatus.undecided);
  });

  test('load with no persisted value stays undecided', () async {
    final bloc = buildBloc();
    bloc.add(const CrashConsentLoadRequested());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, CrashConsentStatus.undecided);
  });

  test('load rehydrates granted', () async {
    await storage.setItem('consent_decision', 'granted');
    final bloc = buildBloc();
    final emitted = <CrashConsentStatus>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(const CrashConsentLoadRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(bloc.state, CrashConsentStatus.granted);
    expect(emitted, [CrashConsentStatus.granted]);
  });

  test('load rehydrates denied', () async {
    await storage.setItem('consent_decision', 'denied');
    final bloc = buildBloc();
    bloc.add(const CrashConsentLoadRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state, CrashConsentStatus.denied);
  });

  test('grant emits granted and persists', () async {
    final bloc = buildBloc();
    bloc.add(const CrashConsentGranted());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state, CrashConsentStatus.granted);
    expect(await storage.getItem('consent_decision'), 'granted');
  });

  test('revoke emits denied and persists', () async {
    final bloc = buildBloc();
    bloc.add(const CrashConsentRevoked());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state, CrashConsentStatus.denied);
    expect(await storage.getItem('consent_decision'), 'denied');
  });

  test('grant then revoke flips persisted value', () async {
    final bloc = buildBloc();
    bloc
      ..add(const CrashConsentGranted())
      ..add(const CrashConsentRevoked());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state, CrashConsentStatus.denied);
    expect(await storage.getItem('consent_decision'), 'denied');
  });
}
