import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/crash/crash_consent_bloc.dart';
import 'package:lifestream_learn_app/core/crash/crash_reporter.dart';
import 'package:lifestream_learn_app/core/crash/secure_storage_backend.dart';
import 'package:lifestream_learn_app/features/onboarding/crash_consent_screen.dart';

import '../../test_support/fake_secure_storage.dart';

Widget _wrap(CrashConsentBloc bloc) {
  return BlocProvider<CrashConsentBloc>.value(
    value: bloc,
    child: const MaterialApp(home: CrashConsentScreen()),
  );
}

void main() {
  late FakeSecureStoragePlatform fake;
  late CrashConsentBloc bloc;

  setUp(() {
    fake = FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = fake;
    final storage = SecureStorageBackend(const FlutterSecureStorage());
    bloc = CrashConsentBloc(
      reporter: CrashReporter.disabled(),
      storage: storage,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  testWidgets('renders title, body, and both buttons', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    expect(find.byKey(const Key('crashConsent.title')), findsOneWidget);
    expect(find.byKey(const Key('crashConsent.body')), findsOneWidget);
    expect(find.byKey(const Key('crashConsent.allow')), findsOneWidget);
    expect(find.byKey(const Key('crashConsent.deny')), findsOneWidget);
  });

  testWidgets('tapping Allow dispatches CrashConsentGranted to the bloc',
      (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.tap(find.byKey(const Key('crashConsent.allow')));
    // Drain the async chain: reporter.grant → storage.setItem → emit.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(bloc.state, CrashConsentStatus.granted);
    // Note: navigation out of this screen is driven by the router
    // redirect listening to the bloc stream (see app_router.dart),
    // not by the screen itself — that's why we don't assert on a
    // `/feed` pathname here.
  });

  testWidgets('tapping Deny dispatches CrashConsentRevoked to the bloc',
      (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.tap(find.byKey(const Key('crashConsent.deny')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(bloc.state, CrashConsentStatus.denied);
  });
}
