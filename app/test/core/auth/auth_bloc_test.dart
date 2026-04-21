import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/auth/auth_bloc.dart';
import 'package:lifestream_learn_app/core/auth/auth_event.dart';
import 'package:lifestream_learn_app/core/auth/auth_state.dart';
import 'package:lifestream_learn_app/core/auth/auth_tokens.dart';
import 'package:lifestream_learn_app/core/auth/token_store.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/user.dart';
import 'package:lifestream_learn_app/data/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _data = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      _data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async =>
      _data.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _data.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      _data[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map<String, String>.from(_data);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _data[key] = value;
  }
}

class _MockAuthRepository extends Mock implements AuthRepository {}

const _testUser = User(
  id: 'u1',
  email: 'test@example.com',
  displayName: 'Test User',
  role: UserRole.learner,
);

const _tokens =
    AuthTokens(accessToken: 'a', refreshToken: 'r');

void main() {
  late _FakeSecureStoragePlatform platform;
  late TokenStore tokenStore;
  late _MockAuthRepository repo;

  setUp(() {
    platform = _FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = platform;
    tokenStore = TokenStore(const FlutterSecureStorage());
    repo = _MockAuthRepository();
    // Slice P6 — LoggedOut now calls `authRepo.logout(...)` before
    // clearing tokens. Stub it by default so every test doesn't have
    // to remember; tests that want to assert the call can use `verify`.
    when(() => repo.logout(any())).thenAnswer((_) async {});
  });

  group('AuthStarted', () {
    test('no stored tokens -> Unauthenticated', () async {
      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[const Unauthenticated()]),
      );
      bloc.add(const AuthStarted());
      await expectation;
      await bloc.close();
    });

    test('stored tokens + me() succeeds -> Authenticated', () async {
      await tokenStore.save(_tokens);
      when(() => repo.me()).thenAnswer((_) async => _testUser);

      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[const Authenticated(_testUser)]),
      );
      bloc.add(const AuthStarted());
      await expectation;
      verify(() => repo.me()).called(1);
      await bloc.close();
    });

    test('stored tokens + me() 401 -> clear tokens + Unauthenticated',
        () async {
      await tokenStore.save(_tokens);
      when(() => repo.me()).thenThrow(const ApiException(
        code: 'UNAUTHORIZED',
        statusCode: 401,
        message: 'gone',
      ));

      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[const Unauthenticated()]),
      );
      bloc.add(const AuthStarted());
      await expectation;
      expect(await tokenStore.read(), isNull);
      await bloc.close();
    });
  });

  group('LoginRequested', () {
    test('success: AuthAuthenticating -> Authenticated + tokens saved',
        () async {
      when(() => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => const LoginSuccess(
                AuthSession(tokens: _tokens, user: _testUser),
              ));

      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          const AuthAuthenticating(),
          const Authenticated(_testUser),
        ]),
      );
      bloc.add(const LoginRequested(email: 'e', password: 'p'));
      await expectation;
      expect(await tokenStore.read(), _tokens);
      await bloc.close();
    });

    test('401 invalid credentials -> Unauthenticated(errorMessage)', () async {
      when(() => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const ApiException(
        code: 'UNAUTHORIZED',
        statusCode: 401,
        message: 'Invalid credentials',
      ));

      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          const AuthAuthenticating(),
          const Unauthenticated(errorMessage: 'Invalid credentials'),
        ]),
      );
      bloc.add(const LoginRequested(email: 'e', password: 'p'));
      await expectation;
      expect(await tokenStore.read(), isNull);
      await bloc.close();
    });
  });

  group('SignupRequested', () {
    test('409 conflict -> Unauthenticated(errorMessage)', () async {
      when(() => repo.signup(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          )).thenThrow(const ApiException(
        code: 'CONFLICT',
        statusCode: 409,
        message: 'Email already registered',
      ));

      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          const AuthAuthenticating(),
          const Unauthenticated(errorMessage: 'Email already registered'),
        ]),
      );
      bloc.add(const SignupRequested(
        email: 'e',
        password: 'p1p1p1p1p1p1',
        displayName: 'd',
      ));
      await expectation;
      await bloc.close();
    });

    test('success -> Authenticated + tokens saved', () async {
      when(() => repo.signup(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          )).thenAnswer((_) async =>
          const AuthSession(tokens: _tokens, user: _testUser));

      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          const AuthAuthenticating(),
          const Authenticated(_testUser),
        ]),
      );
      bloc.add(const SignupRequested(
        email: 'e',
        password: 'p1p1p1p1p1p1',
        displayName: 'd',
      ));
      await expectation;
      expect(await tokenStore.read(), _tokens);
      await bloc.close();
    });
  });

  group('LoggedOut', () {
    test('clears tokens and emits Unauthenticated', () async {
      await tokenStore.save(_tokens);
      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[const Unauthenticated()]),
      );
      bloc.add(const LoggedOut());
      await expectation;
      expect(await tokenStore.read(), isNull);
      await bloc.close();
    });

    test('Slice P6: calls authRepo.logout(refreshToken) before clearing tokens',
        () async {
      await tokenStore.save(_tokens);
      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final done = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[const Unauthenticated()]),
      );
      bloc.add(const LoggedOut());
      await done;

      verify(() => repo.logout('r')).called(1);
      expect(await tokenStore.read(), isNull);
      await bloc.close();
    });

    test('Slice P6: logout is skipped when TokenStore is already empty',
        () async {
      // User taps logout but tokens were already cleared (e.g. the
      // interceptor forced a logout). The bloc should not attempt the
      // HTTP call with a bogus refresh token.
      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final done = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[const Unauthenticated()]),
      );
      bloc.add(const LoggedOut());
      await done;
      verifyNever(() => repo.logout(any()));
      await bloc.close();
    });

    test('emitLoggedOut() from AuthStateSink dispatches LoggedOut event',
        () async {
      await tokenStore.save(_tokens);
      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[const Unauthenticated()]),
      );
      bloc.emitLoggedOut();
      await expectation;
      expect(await tokenStore.read(), isNull);
      await bloc.close();
    });
  });

  group('UserUpdated', () {
    // Slice P1: the profile screen's Edit Profile sheet dispatches
    // `UserUpdated(freshUser)` after a successful PATCH /api/me so the
    // cached state reflects the rename. The handler must only act when
    // the current state is `Authenticated` — a late response arriving
    // after logout should not resurrect the session.

    test('replaces user when currently Authenticated', () async {
      await tokenStore.save(_tokens);
      when(() => repo.me()).thenAnswer((_) async => _testUser);

      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      final renamed = _testUser.copyWith(displayName: 'Renamed');

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          const Authenticated(_testUser),
          Authenticated(renamed),
        ]),
      );
      bloc.add(const AuthStarted());
      // Allow AuthStarted to land before UserUpdated so the Bloc event
      // queue processes them in order.
      await Future<void>.delayed(Duration.zero);
      bloc.add(UserUpdated(renamed));
      await expectation;
      await bloc.close();
    });

    test('ignored when state is Unauthenticated', () async {
      final bloc = AuthBloc(authRepo: repo, tokenStore: tokenStore);
      // AuthStarted with no stored tokens -> Unauthenticated.
      final authStartedDone = expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[const Unauthenticated()]),
      );
      bloc.add(const AuthStarted());
      await authStartedDone;

      // Dispatching UserUpdated should not emit a new state — the
      // state stays Unauthenticated.
      bloc.add(UserUpdated(_testUser));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state, const Unauthenticated());
      await bloc.close();
    });
  });
}
