import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/mfa.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/security/mfa_totp_enrol_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeRepo extends Mock implements MeRepository {}

// Minimal 1x1 PNG base64 payload — enough for Image.memory to accept.
final String _pngDataUrl = 'data:image/png;base64,'
    '${base64Encode(<int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
])}';

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

  testWidgets('renders QR + secret + continue button on successful start', (tester) async {
    when(() => meRepo.startTotpEnrol()).thenAnswer(
      (_) async => TotpEnrolmentStart(
        secret: 'JBSWY3DPEHPK3PXP',
        qrDataUrl: _pngDataUrl,
        otpauthUrl: 'otpauth://totp/foo',
        pendingEnrolmentToken: 'pending.jwt',
      ),
    );

    await tester.pumpWidget(_wrap(MfaTotpEnrolScreen(meRepo: meRepo)));
    // pumpAndSettle can hang if the animation loop of the indicator is
    // permanent; use explicit pumps instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('mfaEnrol.qr')), findsOneWidget);
    expect(find.byKey(const Key('mfaEnrol.secret')), findsOneWidget);
    expect(find.byKey(const Key('mfaEnrol.continueToVerify')), findsOneWidget);
  });

  testWidgets('tapping continue reveals the 6-digit code input', (tester) async {
    when(() => meRepo.startTotpEnrol()).thenAnswer(
      (_) async => TotpEnrolmentStart(
        secret: 'JBSWY3DPEHPK3PXP',
        qrDataUrl: _pngDataUrl,
        otpauthUrl: 'otpauth://totp/foo',
        pendingEnrolmentToken: 'pending.jwt',
      ),
    );
    await tester.pumpWidget(_wrap(MfaTotpEnrolScreen(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('mfaEnrol.continueToVerify')));
    await tester.pump();
    expect(find.byKey(const Key('mfaEnrol.codeInput')), findsOneWidget);
    expect(find.byKey(const Key('mfaEnrol.labelInput')), findsOneWidget);
    expect(find.byKey(const Key('mfaEnrol.submit')), findsOneWidget);
  });

  testWidgets('successful confirm shows the backup codes + Done gate', (tester) async {
    when(() => meRepo.startTotpEnrol()).thenAnswer(
      (_) async => TotpEnrolmentStart(
        secret: 'JBSWY3DPEHPK3PXP',
        qrDataUrl: _pngDataUrl,
        otpauthUrl: 'otpauth://totp/foo',
        pendingEnrolmentToken: 'pending.jwt',
      ),
    );
    when(() => meRepo.confirmTotpEnrol(
          pendingToken: any(named: 'pendingToken'),
          code: any(named: 'code'),
          label: any(named: 'label'),
        )).thenAnswer(
      (_) async => const TotpBackupCodesResponse(
        backupCodes: <String>[
          'AAAAA-11111',
          'BBBBB-22222',
          'CCCCC-33333',
        ],
      ),
    );

    await tester.pumpWidget(_wrap(MfaTotpEnrolScreen(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('mfaEnrol.continueToVerify')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('mfaEnrol.codeInput')), '123456');
    await tester.tap(find.byKey(const Key('mfaEnrol.submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('mfaEnrol.backupCodes')), findsOneWidget);
    expect(find.text('AAAAA-11111'), findsOneWidget);
    // The Done button is disabled until the user checks the ack box.
    final btn =
        tester.widget<FilledButton>(find.byKey(const Key('mfaEnrol.done')));
    expect(btn.onPressed, isNull);
    await tester.tap(find.byKey(const Key('mfaEnrol.ackCheckbox')));
    await tester.pump();
    final btn2 =
        tester.widget<FilledButton>(find.byKey(const Key('mfaEnrol.done')));
    expect(btn2.onPressed, isNotNull);
  });

  testWidgets('wrong code surfaces "Wrong code — try again" inline', (tester) async {
    when(() => meRepo.startTotpEnrol()).thenAnswer(
      (_) async => TotpEnrolmentStart(
        secret: 'JBSWY3DPEHPK3PXP',
        qrDataUrl: _pngDataUrl,
        otpauthUrl: 'otpauth://totp/foo',
        pendingEnrolmentToken: 'pending.jwt',
      ),
    );
    when(() => meRepo.confirmTotpEnrol(
          pendingToken: any(named: 'pendingToken'),
          code: any(named: 'code'),
          label: any(named: 'label'),
        )).thenThrow(const ApiException(
      code: 'UNAUTHORIZED',
      statusCode: 401,
      message: 'Invalid MFA code',
    ));
    await tester.pumpWidget(_wrap(MfaTotpEnrolScreen(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('mfaEnrol.continueToVerify')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('mfaEnrol.codeInput')), '000000');
    await tester.tap(find.byKey(const Key('mfaEnrol.submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Wrong code — try again'), findsOneWidget);
  });

  testWidgets('409 surfaces the "already set up" error + retry', (tester) async {
    when(() => meRepo.startTotpEnrol()).thenThrow(
      const ApiException(code: 'CONFLICT', statusCode: 409, message: 'x'),
    );
    await tester.pumpWidget(_wrap(MfaTotpEnrolScreen(meRepo: meRepo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.textContaining('already set up'),
      findsOneWidget,
    );
  });
}
