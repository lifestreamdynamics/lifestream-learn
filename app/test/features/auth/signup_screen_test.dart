import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/auth/auth_bloc.dart';
import 'package:lifestream_learn_app/core/auth/auth_event.dart';
import 'package:lifestream_learn_app/core/auth/auth_state.dart';
import 'package:lifestream_learn_app/features/auth/signup_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends Mock implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

Widget _wrap(AuthBloc bloc) {
  return MaterialApp(
    home: BlocProvider<AuthBloc>.value(
      value: bloc,
      child: const SignupScreen(),
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

  testWidgets('password < 12 chars shows error', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.enterText(
      find.byKey(const Key('signup.email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup.displayName')),
      'Test User',
    );
    await tester.enterText(
      find.byKey(const Key('signup.password')),
      'short',
    );
    await tester.tap(find.byKey(const Key('signup.submit')));
    await tester.pump();
    expect(
      find.text('Password must be at least 12 characters'),
      findsOneWidget,
    );
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('valid submit dispatches SignupRequested', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.enterText(
      find.byKey(const Key('signup.email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup.displayName')),
      'Test User',
    );
    await tester.enterText(
      find.byKey(const Key('signup.password')),
      'correcthorsebattery1',
    );
    await tester.tap(find.byKey(const Key('signup.submit')));
    await tester.pump();
    verify(() => bloc.add(const SignupRequested(
          email: 'test@example.com',
          password: 'correcthorsebattery1',
          displayName: 'Test User',
        ))).called(1);
  });

  testWidgets('submit disabled during AuthAuthenticating', (tester) async {
    when(() => bloc.state).thenReturn(const AuthAuthenticating());
    await tester.pumpWidget(_wrap(bloc));
    final button = tester
        .widget<ElevatedButton>(find.byKey(const Key('signup.submit')));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows error message on Unauthenticated(errorMessage)',
      (tester) async {
    when(() => bloc.state).thenReturn(
      const Unauthenticated(errorMessage: 'Email already registered'),
    );
    await tester.pumpWidget(_wrap(bloc));
    expect(find.byKey(const Key('signup.error')), findsOneWidget);
    expect(find.text('Email already registered'), findsOneWidget);
  });
}
