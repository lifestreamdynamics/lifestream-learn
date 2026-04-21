import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/auth/passkey_platform.dart';
import 'package:lifestream_learn_app/data/models/webauthn.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/security/mfa_passkey_enrol_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeRepo extends Mock implements MeRepository {}

/// Test-mode PasskeyPlatform that never invokes the real plugin.
///
/// Subclassing the concrete class gets us around mocktail's
/// `registerFallbackValue` dance for the plugin's many nested types —
/// and because every method we need to override is non-final, this
/// works without exposing a separate `PasskeyPlatform` interface.
class _FakePasskeyPlatform extends PasskeyPlatform {
  _FakePasskeyPlatform({this.supported = true});

  final bool supported;

  @override
  bool get isSupported => supported;

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> serverOptions) {
    return Future.value(<String, dynamic>{
      'id': 'cred-id',
      'rawId': 'cred-id',
      'type': 'public-key',
      'response': <String, dynamic>{
        'attestationObject': 'AAAA',
        'clientDataJSON': 'BBBB',
      },
    });
  }

  @override
  Future<Map<String, dynamic>> authenticate(Map<String, dynamic> serverOptions) {
    return Future.value(<String, dynamic>{
      'id': 'cred-id',
      'rawId': 'cred-id',
      'type': 'public-key',
      'response': <String, dynamic>{
        'authenticatorData': 'AAAA',
        'clientDataJSON': 'BBBB',
        'signature': 'SSSS',
      },
    });
  }
}

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/enrol',
    routes: <GoRoute>[
      GoRoute(path: '/enrol', builder: (_, __) => child),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('PROFILE')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockMeRepo meRepo;

  setUp(() {
    meRepo = _MockMeRepo();
  });

  testWidgets('intro step renders icon + label field + continue button', (tester) async {
    await tester.pumpWidget(_wrap(
      MfaPasskeyEnrolScreen(
        meRepo: meRepo,
        passkeyPlatform: _FakePasskeyPlatform(),
      ),
    ));
    expect(find.byKey(const Key('passkeyEnrol.labelInput')), findsOneWidget);
    expect(find.byKey(const Key('passkeyEnrol.continue')), findsOneWidget);
    expect(find.byKey(const Key('passkeyEnrol.cancel')), findsOneWidget);
  });

  testWidgets('successful registration with backup codes shows the backup step', (tester) async {
    when(() => meRepo.startWebauthnRegistration()).thenAnswer(
      (_) async => const WebauthnRegistrationOptions(
        options: <String, dynamic>{
          'challenge': 'CH',
          'rp': <String, dynamic>{'id': 'localhost', 'name': 'Test'},
          'user': <String, dynamic>{'id': 'u', 'name': 'u', 'displayName': 'u'},
          'pubKeyCredParams': <dynamic>[],
        },
        pendingToken: 'pending.jwt',
      ),
    );
    when(() => meRepo.verifyWebauthnRegistration(
          pendingToken: any(named: 'pendingToken'),
          attestationResponse: any(named: 'attestationResponse'),
          label: any(named: 'label'),
        )).thenAnswer((_) async => <String, dynamic>{
          'credentialId': 'cred-id',
          'backupCodes': <String>[
            'AAAAA-BBBBB',
            'CCCCC-DDDDD',
            'EEEEE-FFFFF',
            'GGGGG-HHHHH',
            'IIIII-JJJJJ',
            'KKKKK-LLLLL',
            'MMMMM-NNNNN',
            'OOOOO-PPPPP',
            'QQQQQ-RRRRR',
            'SSSSS-TTTTT',
          ],
        });

    await tester.pumpWidget(_wrap(
      MfaPasskeyEnrolScreen(
        meRepo: meRepo,
        passkeyPlatform: _FakePasskeyPlatform(),
      ),
    ));
    await tester.tap(find.byKey(const Key('passkeyEnrol.continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('passkeyEnrol.backupCodes')), findsOneWidget);
    expect(find.byKey(const Key('passkeyEnrol.ackCheckbox')), findsOneWidget);
    expect(find.byKey(const Key('passkeyEnrol.done')), findsOneWidget);
    // Done is disabled until the user acknowledges.
    final FilledButton done =
        tester.widget(find.byKey(const Key('passkeyEnrol.done')));
    expect(done.onPressed, isNull);
  });

  testWidgets('unsupported platform renders the inline error', (tester) async {
    await tester.pumpWidget(_wrap(
      MfaPasskeyEnrolScreen(
        meRepo: meRepo,
        passkeyPlatform: _FakePasskeyPlatform(supported: false),
      ),
    ));
    await tester.tap(find.byKey(const Key('passkeyEnrol.continue')));
    await tester.pump();
    expect(find.byKey(const Key('passkeyEnrol.errorCard')), findsOneWidget);
    verifyNever(() => meRepo.startWebauthnRegistration());
  });
}
