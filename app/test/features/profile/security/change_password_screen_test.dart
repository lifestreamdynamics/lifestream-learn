import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/security/change_password_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeRepo extends Mock implements MeRepository {}

Widget _wrap(MeRepository meRepo) {
  final router = GoRouter(
    initialLocation: '/profile/security/password',
    routes: [
      // A stand-in for /profile so `GoRouter.of(context).pop()` has
      // somewhere to land (the route stack needs at least two entries).
      GoRoute(
        path: '/profile',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('profile-home'))),
      ),
      GoRoute(
        path: '/profile/security/password',
        builder: (_, __) => ChangePasswordScreen(meRepo: meRepo),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Future<void> _fillForm(
  WidgetTester tester, {
  required String current,
  required String next,
  required String confirm,
}) async {
  await tester.enterText(
    find.byKey(const Key('changePassword.current')),
    current,
  );
  await tester.enterText(
    find.byKey(const Key('changePassword.new')),
    next,
  );
  await tester.enterText(
    find.byKey(const Key('changePassword.confirm')),
    confirm,
  );
  await tester.pump();
}

void main() {
  late _MockMeRepo meRepo;

  setUp(() {
    meRepo = _MockMeRepo();
  });

  testWidgets('submit disabled until form is valid', (tester) async {
    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('changePassword.submit'));
    // Initial: all empty → disabled.
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // New password too short → still disabled.
    await _fillForm(
      tester,
      current: 'CurrentPass1234',
      next: 'short',
      confirm: 'short',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // Confirm mismatch → still disabled.
    await _fillForm(
      tester,
      current: 'CurrentPass1234',
      next: 'BrandNewPass5678',
      confirm: 'BrandNewPass9999',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // Same as current → still disabled.
    await _fillForm(
      tester,
      current: 'CurrentPass1234',
      next: 'CurrentPass1234',
      confirm: 'CurrentPass1234',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // Valid → enabled.
    await _fillForm(
      tester,
      current: 'CurrentPass1234',
      next: 'BrandNewPass5678',
      confirm: 'BrandNewPass5678',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('happy path: submit calls repo, shows success SnackBar, pops',
      (tester) async {
    when(() => meRepo.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    await _fillForm(
      tester,
      current: 'CurrentPass1234',
      next: 'BrandNewPass5678',
      confirm: 'BrandNewPass5678',
    );

    await tester.tap(find.byKey(const Key('changePassword.submit')));
    await tester.pump(); // kicks the async work + setState(submitting=true)
    await tester.pump(); // lets the microtask settle

    verify(() => meRepo.changePassword(
          currentPassword: 'CurrentPass1234',
          newPassword: 'BrandNewPass5678',
        )).called(1);

    // SnackBar rendered — we use `findsWidgets` because the
    // ScaffoldMessenger will keep at least one SnackBar widget in the
    // tree through the pop animation; the count is incidental.
    expect(
      find.byKey(const Key('changePassword.successToast')),
      findsWidgets,
    );

    await tester.pumpAndSettle();
    // We popped to /profile.
    expect(find.text('profile-home'), findsOneWidget);
  });

  testWidgets('401 surfaces inline error under current password field',
      (tester) async {
    when(() => meRepo.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(
      const ApiException(
        code: 'UNAUTHORIZED',
        statusCode: 401,
        message: 'Current password is incorrect',
      ),
    );

    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    await _fillForm(
      tester,
      current: 'WrongGuess1234',
      next: 'BrandNewPass5678',
      confirm: 'BrandNewPass5678',
    );

    await tester.tap(find.byKey(const Key('changePassword.submit')));
    await tester.pumpAndSettle();

    // The TextFormField's errorText shows up as rendered text.
    expect(find.text('Current password is incorrect'), findsOneWidget);
    // Toast did NOT appear.
    expect(
      find.byKey(const Key('changePassword.successToast')),
      findsNothing,
    );
  });

  testWidgets('429 surfaces a friendly rate-limit message', (tester) async {
    when(() => meRepo.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(
      const ApiException(
        code: 'RATE_LIMITED',
        statusCode: 429,
        message: 'Too many password-change attempts',
      ),
    );

    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    await _fillForm(
      tester,
      current: 'CurrentPass1234',
      next: 'BrandNewPass5678',
      confirm: 'BrandNewPass5678',
    );

    await tester.tap(find.byKey(const Key('changePassword.submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('changePassword.generalError')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Too many attempts'),
      findsOneWidget,
    );
  });
}
