import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fvp/fvp.dart' as fvp;

import 'core/auth/auth_bloc.dart';
import 'core/auth/auth_event.dart';
import 'core/auth/token_store.dart';
import 'core/http/auth_interceptor.dart';
import 'core/http/dio_client.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/course_repository.dart';
import 'data/repositories/enrollment_repository.dart';
import 'data/repositories/feed_repository.dart';
import 'data/repositories/video_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // fvp registers a `video_player` backend that uses ffmpeg for broad
  // codec support (important for HLS on mid-range Androids). We only
  // register on Android — web/desktop paths aren't shipped in Slice D,
  // and iOS uses AVFoundation (if/when we ship that target).
  if (!kIsWeb && Platform.isAndroid) {
    fvp.registerWith();
  }

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
  final feedRepo = FeedRepository(dio);
  final courseRepo = CourseRepository(dio);
  final videoRepo = VideoRepository(dio);
  final enrollmentRepo = EnrollmentRepository(dio);

  authBloc = AuthBloc(authRepo: authRepo, tokenStore: tokenStore)
    ..add(const AuthStarted());

  runApp(App(
    authBloc: authBloc,
    feedRepo: feedRepo,
    courseRepo: courseRepo,
    videoRepo: videoRepo,
    enrollmentRepo: enrollmentRepo,
  ));
}

class _AuthStateSinkProxy implements AuthStateSink {
  _AuthStateSinkProxy(this._resolve);
  final AuthStateSink Function() _resolve;

  @override
  void emitLoggedOut() => _resolve().emitLoggedOut();
}

class App extends StatefulWidget {
  const App({
    required this.authBloc,
    required this.feedRepo,
    required this.courseRepo,
    required this.videoRepo,
    required this.enrollmentRepo,
    super.key,
  });

  final AuthBloc authBloc;
  final FeedRepository feedRepo;
  final CourseRepository courseRepo;
  final VideoRepository videoRepo;
  final EnrollmentRepository enrollmentRepo;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final router = createRouter(
    widget.authBloc,
    feedRepo: widget.feedRepo,
    courseRepo: widget.courseRepo,
    videoRepo: widget.videoRepo,
    enrollmentRepo: widget.enrollmentRepo,
  );

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
