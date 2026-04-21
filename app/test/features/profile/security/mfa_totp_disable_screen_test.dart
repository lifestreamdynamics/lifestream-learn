import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/security/mfa_totp_disable_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeRepo extends Mock implements MeRepository {}

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/disable',
    routes: <GoRoute>[
      GoRoute(path: '/disable', builder: (_, __) => child),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold(body: Text('PROFILE'))),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockMeRepo meRepo;

  setUp(() {
    meRepo = _MockMeRepo();
  });

  testWidgets('renders password + code inputs + disable button', (tester) async {
    await tester.pumpWidget(_wrap(MfaTotpDisableScreen(meRepo: meRepo)));
    expect(find.byKey(const Key('mfaDisable.password')), findsOneWidget);
    expect(find.byKey(const Key('mfaDisable.code')), findsOneWidget);
    expect(find.byKey(const Key('mfaDisable.submit')), findsOneWidget);
  });

  testWidgets('submit calls disableTotp with password + code on success',
      (tester) async {
    when(() => meRepo.disableTotp(
          currentPassword: any(named: 'currentPassword'),
          code: any(named: 'code'),
        )).thenAnswer((_) async {});
    await tester.pumpWidget(_wrap(MfaTotpDisableScreen(meRepo: meRepo)));
    await tester.enterText(find.byKey(const Key('mfaDisable.password')), 'CorrectHorse1234');
    await tester.enterText(find.byKey(const Key('mfaDisable.code')), '123456');
    await tester.tap(find.byKey(const Key('mfaDisable.submit')));
    await tester.pump();
    verify(() => meRepo.disableTotp(
          currentPassword: 'CorrectHorse1234',
          code: '123456',
        )).called(1);
  });

  testWidgets('401 surfaces the "wrong password or code" inline error',
      (tester) async {
    when(() => meRepo.disableTotp(
          currentPassword: any(named: 'currentPassword'),
          code: any(named: 'code'),
        )).thenThrow(const ApiException(
      code: 'UNAUTHORIZED',
      statusCode: 401,
      message: 'x',
    ));
    await tester.pumpWidget(_wrap(MfaTotpDisableScreen(meRepo: meRepo)));
    await tester.enterText(find.byKey(const Key('mfaDisable.password')), 'wrong-password');
    await tester.enterText(find.byKey(const Key('mfaDisable.code')), '000000');
    await tester.tap(find.byKey(const Key('mfaDisable.submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('mfaDisable.error')), findsOneWidget);
    expect(find.textContaining('Wrong password or code'), findsOneWidget);
  });

  testWidgets('button is disabled if password or code missing',
      (tester) async {
    await tester.pumpWidget(_wrap(MfaTotpDisableScreen(meRepo: meRepo)));
    // Enter only 4-digit code.
    await tester.enterText(find.byKey(const Key('mfaDisable.password')), 'hello');
    await tester.enterText(find.byKey(const Key('mfaDisable.code')), '12');
    await tester.tap(find.byKey(const Key('mfaDisable.submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    verifyNever(() => meRepo.disableTotp(
          currentPassword: any(named: 'currentPassword'),
          code: any(named: 'code'),
        ));
  });
}
