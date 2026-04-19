import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fvp/fvp.dart' as fvp;

import 'core/analytics/analytics_buffer.dart';
import 'core/analytics/analytics_event.dart';
import 'core/analytics/analytics_sinks.dart';
import 'core/auth/auth_bloc.dart';
import 'core/auth/auth_event.dart';
import 'core/auth/token_store.dart';
import 'core/http/auth_interceptor.dart';
import 'core/http/dio_client.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/admin_analytics_repository.dart';
import 'data/repositories/admin_designer_application_repository.dart';
import 'data/repositories/attempt_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/course_repository.dart';
import 'data/repositories/cue_repository.dart';
import 'data/repositories/designer_application_repository.dart';
import 'data/repositories/enrollment_repository.dart';
import 'data/repositories/events_repository.dart';
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
  final cueRepo = CueRepository(dio);
  final attemptRepo = AttemptRepository(dio);
  final designerAppRepo = DesignerApplicationRepository(dio);
  final adminDesignerAppRepo = AdminDesignerApplicationRepository(dio);
  final adminAnalyticsRepo = AdminAnalyticsRepository(dio);
  final eventsRepo = EventsRepository(dio);

  // Analytics buffer is a per-process singleton. We hydrate from disk
  // before installing the periodic flush so the first tick drains any
  // events the previous session couldn't ship.
  final analyticsBuffer = AnalyticsBuffer(repo: eventsRepo);
  final cueAnalyticsSink = AnalyticsBufferCueSink(analyticsBuffer);
  final videoAnalyticsSink = AnalyticsBufferVideoSink(analyticsBuffer);

  authBloc = AuthBloc(authRepo: authRepo, tokenStore: tokenStore)
    ..add(const AuthStarted());

  // Fire-and-forget hydrate + periodic install. Failures are logged
  // inside the buffer; they never block app startup.
  unawaited(_bootstrapAnalytics(analyticsBuffer));

  runApp(App(
    authBloc: authBloc,
    feedRepo: feedRepo,
    courseRepo: courseRepo,
    videoRepo: videoRepo,
    enrollmentRepo: enrollmentRepo,
    cueRepo: cueRepo,
    attemptRepo: attemptRepo,
    designerAppRepo: designerAppRepo,
    adminDesignerAppRepo: adminDesignerAppRepo,
    adminAnalyticsRepo: adminAnalyticsRepo,
    analyticsBuffer: analyticsBuffer,
    cueAnalyticsSink: cueAnalyticsSink,
    videoAnalyticsSink: videoAnalyticsSink,
  ));
}

Future<void> _bootstrapAnalytics(AnalyticsBuffer buffer) async {
  try {
    await buffer.hydrate();
  } catch (_) {
    /* hydrate swallows errors internally; belt-and-braces. */
  }
  buffer.startPeriodic();
  // Emit a session_start marker. DateTime.now() is the client clock;
  // the backend records its own `receivedAt` separately.
  await buffer.log(AnalyticsEvent(
    eventType: AnalyticsEventTypes.sessionStart,
    occurredAt: DateTime.now().toUtc().toIso8601String(),
    payload: const <String, dynamic>{},
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
    required this.cueRepo,
    required this.attemptRepo,
    required this.designerAppRepo,
    required this.adminDesignerAppRepo,
    required this.adminAnalyticsRepo,
    required this.analyticsBuffer,
    required this.cueAnalyticsSink,
    required this.videoAnalyticsSink,
    super.key,
  });

  final AuthBloc authBloc;
  final FeedRepository feedRepo;
  final CourseRepository courseRepo;
  final VideoRepository videoRepo;
  final EnrollmentRepository enrollmentRepo;
  final CueRepository cueRepo;
  final AttemptRepository attemptRepo;
  final DesignerApplicationRepository designerAppRepo;
  final AdminDesignerApplicationRepository adminDesignerAppRepo;
  final AdminAnalyticsRepository adminAnalyticsRepo;
  final AnalyticsBuffer analyticsBuffer;
  final CueAnalyticsSink cueAnalyticsSink;
  final VideoAnalyticsSink videoAnalyticsSink;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final router = createRouter(
    widget.authBloc,
    feedRepo: widget.feedRepo,
    courseRepo: widget.courseRepo,
    videoRepo: widget.videoRepo,
    enrollmentRepo: widget.enrollmentRepo,
    cueRepo: widget.cueRepo,
    attemptRepo: widget.attemptRepo,
    designerAppRepo: widget.designerAppRepo,
    adminDesignerAppRepo: widget.adminDesignerAppRepo,
    adminAnalyticsRepo: widget.adminAnalyticsRepo,
    cueAnalyticsSink: widget.cueAnalyticsSink,
    videoAnalyticsSink: widget.videoAnalyticsSink,
  );

  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionStart = DateTime.now();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Paused: best-effort flush. If the OS kills the process before
    // the POST returns, the events remain on disk and get replayed on
    // next launch via hydrate().
    if (state == AppLifecycleState.paused) {
      unawaited(widget.analyticsBuffer.flush());
    }
    // Detached: final session_end best-effort. Spec is explicit that
    // this is not guaranteed to land — see CLAUDE.md / Slice F spec.
    if (state == AppLifecycleState.detached) {
      final start = _sessionStart;
      if (start != null) {
        final durMs = DateTime.now().difference(start).inMilliseconds;
        unawaited(widget.analyticsBuffer.log(AnalyticsEvent(
          eventType: AnalyticsEventTypes.sessionEnd,
          occurredAt: DateTime.now().toUtc().toIso8601String(),
          payload: <String, dynamic>{'durationMs': durMs},
        )));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: widget.authBloc,
      child: MaterialApp.router(
        title: 'Lifestream Learn',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: router,
      ),
    );
  }
}
