import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/auth/auth_bloc.dart';
import 'core/auth/auth_event.dart';
import 'core/auth/token_store.dart';
import 'core/http/auth_interceptor.dart';
import 'core/http/dio_client.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final tokenStore = TokenStore(storage);

  // The interceptor needs an `AuthStateSink` but the BLoC needs the Dio
  // client (indirectly, via AuthRepository). Break the cycle with a proxy
  // that resolves the BLoC lazily once it's constructed below.
  late final AuthBloc authBloc;
  final dio = createDio(
    tokenStore: tokenStore,
    authStateSink: _AuthStateSinkProxy(() => authBloc),
  );
  final authRepo = AuthRepository(dio);
  authBloc = AuthBloc(authRepo: authRepo, tokenStore: tokenStore)
    ..add(const AuthStarted());

  runApp(App(authBloc: authBloc));
}

class _AuthStateSinkProxy implements AuthStateSink {
  _AuthStateSinkProxy(this._resolve);
  final AuthStateSink Function() _resolve;

  @override
  void emitLoggedOut() => _resolve().emitLoggedOut();
}

class App extends StatefulWidget {
  const App({required this.authBloc, super.key});
  final AuthBloc authBloc;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final router = createRouter(widget.authBloc);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: widget.authBloc,
      child: MaterialApp.router(
        title: 'Lifestream Learn',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: router,
      ),
    );
  }
}
