import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/auth/auth_bloc.dart';
import 'package:lifestream_learn_app/core/auth/auth_event.dart';
import 'package:lifestream_learn_app/core/auth/auth_state.dart';
import 'package:lifestream_learn_app/features/auth/login_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends Mock implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

Widget _wrap(AuthBloc bloc) {
  return MaterialApp(
    home: BlocProvider<AuthBloc>.value(
      value: bloc,
      child: const LoginScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockAuthBloc bloc;

  setUp(() {
    bloc = _MockAuthBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.state).thenReturn(const Unauthenticated());
  });

  testWidgets('renders email, password, submit and signup link',
      (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    expect(find.byKey(const Key('login.email')), findsOneWidget);
    expect(find.byKey(const Key('login.password')), findsOneWidget);
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
    expect(find.byKey(const Key('login.goSignup')), findsOneWidget);
  });

  testWidgets('invalid email shows inline error', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.enterText(find.byKey(const Key('login.email')), 'not-email');
    await tester.enterText(
      find.byKey(const Key('login.password')),
      'anything',
    );
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pump();
    expect(find.text('Invalid email'), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('valid submit dispatches LoginRequested', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.enterText(
      find.byKey(const Key('login.email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login.password')),
      'correcthorsebattery',
    );
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pump();
    verify(() => bloc.add(const LoginRequested(
          email: 'test@example.com',
          password: 'correcthorsebattery',
        ))).called(1);
  });

  testWidgets('shows error message on Unauthenticated(errorMessage)',
      (tester) async {
    when(() => bloc.state).thenReturn(
      const Unauthenticated(errorMessage: 'Invalid credentials'),
    );
    await tester.pumpWidget(_wrap(bloc));
    expect(find.byKey(const Key('login.error')), findsOneWidget);
    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('submit button disabled while AuthAuthenticating',
      (tester) async {
    when(() => bloc.state).thenReturn(const AuthAuthenticating());
    await tester.pumpWidget(_wrap(bloc));
    final button = tester
        .widget<ElevatedButton>(find.byKey(const Key('login.submit')));
    expect(button.onPressed, isNull);
  });
}
