import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/auth/auth_bloc.dart';
import 'package:lifestream_learn_app/core/auth/auth_event.dart';
import 'package:lifestream_learn_app/core/auth/auth_state.dart';
import 'package:lifestream_learn_app/features/auth/mfa_challenge_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends Mock implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

Widget _wrap({
  required AuthBloc bloc,
}) {
  final router = GoRouter(
    initialLocation: '/login/mfa',
    routes: <GoRoute>[
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LOGIN'))),
      GoRoute(path: '/login/mfa', builder: (_, __) => const MfaChallengeScreen()),
    ],
  );
  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockAuthBloc bloc;

  MfaChallengeRequired challenge({
    String? errorMessage,
    bool submitting = false,
    List<String> methods = const ['totp', 'backup'],
  }) {
    return MfaChallengeRequired(
      mfaToken: 'pending.jwt',
      availableMethods: methods,
      errorMessage: errorMessage,
      submitting: submitting,
    );
  }

  setUp(() {
    bloc = _MockAuthBloc();
    when(() => bloc.state).thenReturn(challenge());
    when(() => bloc.stream).thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
  });

  testWidgets('renders the 6-digit code input + submit button + backup toggle', (tester) async {
    await tester.pumpWidget(_wrap(bloc: bloc));
    expect(find.byKey(const Key('mfa.totpInput')), findsOneWidget);
    expect(find.byKey(const Key('mfa.submit')), findsOneWidget);
    expect(find.byKey(const Key('mfa.toggleBackup')), findsOneWidget);
  });

  testWidgets('submit dispatches MfaSubmitted with the entered code', (tester) async {
    await tester.pumpWidget(_wrap(bloc: bloc));
    await tester.enterText(find.byKey(const Key('mfa.totpInput')), '123456');
    await tester.tap(find.byKey(const Key('mfa.submit')));
    await tester.pump();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured, isNotEmpty);
    expect(captured.last, isA<MfaSubmitted>());
    final event = captured.last as MfaSubmitted;
    expect(event.code, '123456');
    expect(event.useBackup, isFalse);
  });

  testWidgets('toggling backup switches the input + submit routes backup path', (tester) async {
    await tester.pumpWidget(_wrap(bloc: bloc));
    await tester.tap(find.byKey(const Key('mfa.toggleBackup')));
    await tester.pump();
    expect(find.byKey(const Key('mfa.backupInput')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mfa.backupInput')), 'ABCDE-12345');
    await tester.tap(find.byKey(const Key('mfa.submit')));
    await tester.pump();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured, isNotEmpty);
    expect(captured.last, isA<MfaSubmitted>());
    final event = captured.last as MfaSubmitted;
    expect(event.useBackup, isTrue);
    expect(event.code, 'ABCDE-12345');
  });

  testWidgets('renders errorText when the state carries one', (tester) async {
    when(() => bloc.state).thenReturn(challenge(errorMessage: 'Invalid code'));
    await tester.pumpWidget(_wrap(bloc: bloc));
    expect(find.text('Invalid code'), findsOneWidget);
  });

  testWidgets('submit button is disabled while submitting', (tester) async {
    when(() => bloc.state).thenReturn(challenge(submitting: true));
    await tester.pumpWidget(_wrap(bloc: bloc));
    final btn = tester.widget<FilledButton>(find.byKey(const Key('mfa.submit')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('hides the backup toggle when only totp is advertised', (tester) async {
    when(() => bloc.state).thenReturn(challenge(methods: const ['totp']));
    await tester.pumpWidget(_wrap(bloc: bloc));
    expect(find.byKey(const Key('mfa.toggleBackup')), findsNothing);
  });

  testWidgets('shows the passkey CTA when webauthn is advertised', (tester) async {
    when(() => bloc.state).thenReturn(
      challenge(methods: const ['totp', 'webauthn', 'backup']),
    );
    await tester.pumpWidget(_wrap(bloc: bloc));
    expect(find.byKey(const Key('mfa.usePasskey')), findsOneWidget);
  });

  testWidgets('tapping the passkey CTA dispatches MfaPasskeySubmitted', (tester) async {
    when(() => bloc.state).thenReturn(
      challenge(methods: const ['totp', 'webauthn']),
    );
    await tester.pumpWidget(_wrap(bloc: bloc));
    await tester.tap(find.byKey(const Key('mfa.usePasskey')));
    await tester.pump();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured, isNotEmpty);
    expect(captured.last, isA<MfaPasskeySubmitted>());
  });

  testWidgets('hides the passkey CTA when webauthn is NOT advertised', (tester) async {
    when(() => bloc.state).thenReturn(challenge(methods: const ['totp']));
    await tester.pumpWidget(_wrap(bloc: bloc));
    expect(find.byKey(const Key('mfa.usePasskey')), findsNothing);
  });
}
