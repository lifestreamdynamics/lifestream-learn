import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/webauthn.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/security/passkeys_list_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeRepo extends Mock implements MeRepository {}

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/list',
    routes: <GoRoute>[
      GoRoute(path: '/list', builder: (_, __) => child),
      GoRoute(
        path: '/profile/security/mfa/passkey/enrol',
        builder: (_, __) => const Scaffold(body: Text('ENROL')),
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

  testWidgets('renders registered passkeys with label + transports + add button',
      (tester) async {
    when(() => meRepo.fetchWebauthnCredentials()).thenAnswer(
      (_) async => <WebauthnCredential>[
        WebauthnCredential(
          id: 'row-1',
          credentialId: 'AAA',
          label: 'Pixel fingerprint',
          createdAt: DateTime(2026, 4, 1),
          lastUsedAt: DateTime(2026, 4, 19),
          transports: const <String>['internal'],
          aaguid: null,
        ),
      ],
    );
    await tester.pumpWidget(_wrap(PasskeysListScreen(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('passkeys.tile.row-1')), findsOneWidget);
    expect(find.text('Pixel fingerprint'), findsOneWidget);
    expect(find.byKey(const Key('passkeys.addAnother')), findsOneWidget);
  });

  testWidgets('empty list renders the empty-state placeholder', (tester) async {
    when(() => meRepo.fetchWebauthnCredentials())
        .thenAnswer((_) async => <WebauthnCredential>[]);
    await tester.pumpWidget(_wrap(PasskeysListScreen(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('passkeys.empty')), findsOneWidget);
  });

  testWidgets('delete opens the password dialog with cancel + confirm buttons',
      (tester) async {
    when(() => meRepo.fetchWebauthnCredentials()).thenAnswer(
      (_) async => <WebauthnCredential>[
        WebauthnCredential(
          id: 'row-1',
          credentialId: 'AAA',
          label: null,
          createdAt: DateTime(2026, 4, 1),
          lastUsedAt: null,
          transports: const <String>[],
          aaguid: null,
        ),
      ],
    );
    await tester.pumpWidget(_wrap(PasskeysListScreen(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('passkeys.delete.row-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passkeys.deleteDialog')), findsOneWidget);
    expect(find.byKey(const Key('passkeys.deletePwInput')), findsOneWidget);
    expect(find.byKey(const Key('passkeys.deleteCancel')), findsOneWidget);
    expect(find.byKey(const Key('passkeys.deleteConfirm')), findsOneWidget);
  });

  testWidgets('error from list fetch surfaces a retry button', (tester) async {
    when(() => meRepo.fetchWebauthnCredentials()).thenThrow(
      const ApiException(
        code: 'NETWORK_ERROR',
        statusCode: 0,
        message: 'no net',
      ),
    );
    await tester.pumpWidget(_wrap(PasskeysListScreen(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('no net'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
