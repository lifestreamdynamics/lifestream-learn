import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/mfa.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/widgets/mfa_card.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeRepo extends Mock implements MeRepository {}

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: <GoRoute>[
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(
        path: '/profile/security/mfa/totp/enrol',
        builder: (_, __) => const Scaffold(body: Text('ENROL')),
      ),
      GoRoute(
        path: '/profile/security/mfa/totp/disable',
        builder: (_, __) => const Scaffold(body: Text('DISABLE')),
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

  testWidgets('renders the loading tile first, then the setup tile when no TOTP',
      (tester) async {
    when(() => meRepo.fetchMfaMethods()).thenAnswer(
      (_) async => const MfaMethods(totp: false),
    );
    await tester.pumpWidget(_wrap(MfaCard(meRepo: meRepo)));
    // Initial frame: loading.
    expect(find.byKey(const Key('profile.mfa.loading')), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('profile.mfa.setup')), findsOneWidget);
    expect(find.textContaining('set up'), findsOneWidget);
  });

  testWidgets('renders the manage tile + backup-codes count when enrolled',
      (tester) async {
    when(() => meRepo.fetchMfaMethods()).thenAnswer(
      (_) async => const MfaMethods(
        totp: true,
        backupCodesRemaining: 7,
        hasBackupCodes: true,
      ),
    );
    await tester.pumpWidget(_wrap(MfaCard(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('profile.mfa.manage')), findsOneWidget);
    expect(find.textContaining('7 backup codes'), findsOneWidget);
  });

  testWidgets('error state shows a retry icon', (tester) async {
    when(() => meRepo.fetchMfaMethods()).thenThrow(const ApiException(
      code: 'NETWORK_ERROR',
      statusCode: 0,
      message: 'offline',
    ));
    await tester.pumpWidget(_wrap(MfaCard(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('profile.mfa.error')), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });
}
