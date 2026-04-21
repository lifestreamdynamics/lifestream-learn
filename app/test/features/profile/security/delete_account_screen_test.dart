import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/auth/auth_bloc.dart';
import 'package:lifestream_learn_app/core/auth/auth_event.dart';
import 'package:lifestream_learn_app/core/auth/auth_state.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/security/delete_account_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeRepo extends Mock implements MeRepository {}

class _MockAuthBloc extends Mock implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

Widget _wrap({
  required AuthBloc authBloc,
  required MeRepository meRepo,
}) {
  final router = GoRouter(
    initialLocation: '/profile/delete',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('login-screen'))),
      ),
      GoRoute(
        path: '/profile/delete',
        builder: (_, __) => DeleteAccountScreen(meRepo: meRepo),
      ),
    ],
  );
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockMeRepo meRepo;

  setUp(() {
    authBloc = _MockAuthBloc();
    meRepo = _MockMeRepo();
    when(() => authBloc.state).thenReturn(const Unauthenticated());
    when(() => authBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => authBloc.close()).thenAnswer((_) async {});
    when(() => authBloc.add(any())).thenReturn(null);
  });

  testWidgets('step 1 renders; Continue disabled until checkbox ticked',
      (tester) async {
    await tester.pumpWidget(_wrap(authBloc: authBloc, meRepo: meRepo));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('deleteAccount.step.warning')),
      findsOneWidget,
    );
    // Slice P8 — "Export my data first" is now enabled and navigates
    // to the /profile/export screen.
    final exportBtn = tester.widget<OutlinedButton>(
      find.byKey(const Key('deleteAccount.exportFirst')),
    );
    expect(exportBtn.onPressed, isNotNull);

    // Continue starts disabled.
    final continueBtn = find.byKey(const Key('deleteAccount.continue'));
    expect(tester.widget<FilledButton>(continueBtn).onPressed, isNull);

    // Tick the acknowledge checkbox.
    await tester.tap(find.byKey(const Key('deleteAccount.acknowledge')));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(continueBtn).onPressed, isNotNull);
  });

  testWidgets('step 2 gates on acknowledgement + shows password field',
      (tester) async {
    await tester.pumpWidget(_wrap(authBloc: authBloc, meRepo: meRepo));
    await tester.pumpAndSettle();

    // Tick + Continue to reach step 2.
    await tester.tap(find.byKey(const Key('deleteAccount.acknowledge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteAccount.continue')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('deleteAccount.step.confirm')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('deleteAccount.password')),
      findsOneWidget,
    );

    // Submit starts disabled (password empty).
    final submit = find.byKey(const Key('deleteAccount.submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets('wrong password shows inline error; account not logged out',
      (tester) async {
    when(() => meRepo.deleteAccount(
          currentPassword: any(named: 'currentPassword'),
        )).thenThrow(
      const ApiException(
        code: 'UNAUTHORIZED',
        statusCode: 401,
        message: 'Current password is incorrect',
      ),
    );

    await tester.pumpWidget(_wrap(authBloc: authBloc, meRepo: meRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteAccount.acknowledge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteAccount.continue')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('deleteAccount.password')),
      'WrongGuess1234',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('deleteAccount.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Password is incorrect'), findsOneWidget);
    // Must NOT have dispatched LoggedOut.
    verifyNever(() => authBloc.add(any(that: isA<LoggedOut>())));
  });

  testWidgets(
      'happy path: calls repo, dispatches LoggedOut, shows SnackBar, routes to /login',
      (tester) async {
    when(() => meRepo.deleteAccount(
          currentPassword: any(named: 'currentPassword'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(authBloc: authBloc, meRepo: meRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteAccount.acknowledge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteAccount.continue')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('deleteAccount.password')),
      'CurrentPass1234',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('deleteAccount.submit')));
    // Let the awaited delete + setState + SnackBar push settle. We use
    // discrete pumps rather than pumpAndSettle because the /login
    // placeholder renders a `Center` — no animations — but SnackBar has
    // its own enter animation.
    await tester.pump();
    await tester.pump();

    verify(() => meRepo.deleteAccount(
          currentPassword: 'CurrentPass1234',
        )).called(1);
    verify(() => authBloc.add(any(that: isA<LoggedOut>()))).called(1);
    // See note in change_password_screen_test.dart — the ScaffoldMessenger
    // keeps at least one SnackBar in the tree during the pop animation,
    // so we assert "at least one" rather than "exactly one".
    expect(
      find.byKey(const Key('deleteAccount.successToast')),
      findsWidgets,
    );

    // After animations, we should be on the /login placeholder.
    await tester.pumpAndSettle();
    expect(find.text('login-screen'), findsOneWidget);
  });
}
