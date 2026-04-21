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
import 'core/auth/auth_state.dart';
import 'core/auth/biometric_gate.dart';
import 'core/auth/token_store.dart';
import 'core/crash/crash_consent_bloc.dart';
import 'core/crash/crash_reporter.dart';
import 'core/crash/secure_storage_backend.dart';
import 'core/http/auth_interceptor.dart';
import 'core/http/dio_client.dart';
import 'core/routing/app_router.dart';
import 'core/routing/navigation_history_observer.dart';
import 'core/routing/root_back_handler.dart';
import 'core/settings/settings_cubit.dart';
import 'core/settings/settings_state.dart';
import 'core/settings/settings_store.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/date_formatters.dart';
import 'data/repositories/admin_analytics_repository.dart';
import 'data/repositories/admin_designer_application_repository.dart';
import 'data/repositories/attempt_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/caption_repository.dart';
import 'data/repositories/course_repository.dart';
import 'data/repositories/cue_repository.dart';
import 'data/repositories/designer_application_repository.dart';
import 'data/repositories/enrollment_repository.dart';
import 'data/repositories/events_repository.dart';
import 'data/repositories/feed_repository.dart';
import 'data/repositories/me_repository.dart';
import 'data/repositories/progress_repository.dart';
import 'data/repositories/video_repository.dart';

void main() {
  runZonedGuarded<void>(() {
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

    // Crash reporter owns a LifestreamDoctor instance configured from
    // compile-time env vars. When no API key is supplied the reporter
    // is in disabled mode and all capture calls silently no-op.
    final crashReporter = CrashReporter.fromConfig(storage: storage);
    _zoneCrashReporter = crashReporter;
    crashReporter.installErrorHooks();
    unawaited(crashReporter.bootstrap());

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
    final captionRepo = CaptionRepository(dio);
    final attemptRepo = AttemptRepository(dio);
    final designerAppRepo = DesignerApplicationRepository(dio);
    final adminDesignerAppRepo = AdminDesignerApplicationRepository(dio);
    final adminAnalyticsRepo = AdminAnalyticsRepository(dio);
    final eventsRepo = EventsRepository(dio);
    final meRepo = MeRepository(dio);
    final progressRepo = ProgressRepository(dio);

    final navigationHistoryObserver = NavigationHistoryObserver();

    authBloc = AuthBloc(authRepo: authRepo, tokenStore: tokenStore);

    // Slice P7a — biometric unlock gate. Runs BEFORE `AuthStarted` so
    // a failed biometric check (user cancelled, too many attempts)
    // clears the TokenStore first and the rehydrate sees no tokens,
    // landing the user on /login. A no-op when the feature is off or
    // no tokens are stored.
    final settingsStoreForGate = SettingsStore(storage);
    unawaited(() async {
      await BiometricGate(
        settingsStore: settingsStoreForGate,
        tokenStore: tokenStore,
      ).run();
      authBloc.add(const AuthStarted());
    }());

    // Analytics buffer is a per-process singleton. We hydrate from disk
    // before installing the periodic flush so the first tick drains any
    // events the previous session couldn't ship.
    //
    // The flush gate is tied to `authBloc.state is Authenticated` so that
    // events queued before the user logs in (e.g. a `session_start` fired
    // from the splash, or left-over events from a prior session that got
    // hydrated) wait on disk until we have a bearer token. Without this
    // gate, the first flush after startup races the login and gets
    // rejected 401 by `/api/events`, dropping otherwise-valid telemetry.
    final analyticsBuffer = AnalyticsBuffer(
      repo: eventsRepo,
      canFlush: () => authBloc.state is Authenticated,
    );
    final cueAnalyticsSink = AnalyticsBufferCueSink(analyticsBuffer);
    final videoAnalyticsSink = AnalyticsBufferVideoSink(analyticsBuffer);

    // Kick a flush as soon as the user transitions into `Authenticated`
    // so the first drain doesn't wait up to 30s for the periodic tick.
    // Transitions out of `Authenticated` (logout) don't need a kick —
    // the gate just closes and subsequent ticks short-circuit.
    authBloc.stream.listen((state) {
      if (state is Authenticated) {
        unawaited(analyticsBuffer.flush());
      } else if (state is Unauthenticated) {
        navigationHistoryObserver.clear();
      }
    });

    // Crash consent bloc rehydrates the persisted decision so the user
    // isn't re-prompted on every launch. The router's redirect rule
    // gates authed traffic on the bloc's state.
    final crashConsentBloc = CrashConsentBloc(
      reporter: crashReporter,
      storage: SecureStorageBackend(storage),
    )..add(const CrashConsentLoadRequested());

    // Slice P4 — application preferences. The cubit hydrates from
    // secure storage on `load()` and then drives themeMode, text
    // scale, reduce-motion, etc. through a widget-tree provider.
    // Analytics + crash consent are mirrored into their respective
    // owners (buffer, CrashConsentBloc) so we don't fork their state.
    final settingsStore = SettingsStore(storage);
    final settingsCubit = SettingsCubit(
      store: settingsStore,
      analyticsBuffer: analyticsBuffer,
      crashConsentBloc: crashConsentBloc,
    );
    unawaited(settingsCubit.load());

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
      captionRepo: captionRepo,
      attemptRepo: attemptRepo,
      designerAppRepo: designerAppRepo,
      adminDesignerAppRepo: adminDesignerAppRepo,
      adminAnalyticsRepo: adminAnalyticsRepo,
      meRepo: meRepo,
      progressRepo: progressRepo,
      analyticsBuffer: analyticsBuffer,
      cueAnalyticsSink: cueAnalyticsSink,
      videoAnalyticsSink: videoAnalyticsSink,
      crashReporter: crashReporter,
      crashConsentBloc: crashConsentBloc,
      settingsCubit: settingsCubit,
      navigationHistoryObserver: navigationHistoryObserver,
    ));
  }, (error, stack) {
    // Zone-level uncaught errors — route through the doctor so async
    // crashes not caught by `PlatformDispatcher.onError` still get
    // captured. The reporter is disabled in the no-config path, so
    // this is a cheap pass-through when crash reporting is off.
    _zoneCrashReporter?.captureException(error, stackTrace: stack);
  });
}

/// Captured at zone-setup time so the `runZonedGuarded` onError handler
/// can reach the reporter. Assigned synchronously inside the zone
/// closure once [CrashReporter.fromConfig] returns.
CrashReporter? _zoneCrashReporter;

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
    occurredAt: DateTime.now().toUtcIso8601(),
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
    required this.captionRepo,
    required this.attemptRepo,
    required this.designerAppRepo,
    required this.adminDesignerAppRepo,
    required this.adminAnalyticsRepo,
    required this.meRepo,
    required this.progressRepo,
    required this.analyticsBuffer,
    required this.cueAnalyticsSink,
    required this.videoAnalyticsSink,
    required this.crashReporter,
    required this.crashConsentBloc,
    required this.settingsCubit,
    required this.navigationHistoryObserver,
    super.key,
  });

  final AuthBloc authBloc;
  final FeedRepository feedRepo;
  final CourseRepository courseRepo;
  final VideoRepository videoRepo;
  final EnrollmentRepository enrollmentRepo;
  final CueRepository cueRepo;
  final CaptionRepository captionRepo;
  final AttemptRepository attemptRepo;
  final DesignerApplicationRepository designerAppRepo;
  final AdminDesignerApplicationRepository adminDesignerAppRepo;
  final AdminAnalyticsRepository adminAnalyticsRepo;
  final MeRepository meRepo;
  final ProgressRepository progressRepo;
  final AnalyticsBuffer analyticsBuffer;
  final CueAnalyticsSink cueAnalyticsSink;
  final VideoAnalyticsSink videoAnalyticsSink;
  final CrashReporter crashReporter;
  final CrashConsentBloc crashConsentBloc;
  final SettingsCubit settingsCubit;
  final NavigationHistoryObserver navigationHistoryObserver;

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
    captionRepo: widget.captionRepo,
    attemptRepo: widget.attemptRepo,
    designerAppRepo: widget.designerAppRepo,
    adminDesignerAppRepo: widget.adminDesignerAppRepo,
    adminAnalyticsRepo: widget.adminAnalyticsRepo,
    meRepo: widget.meRepo,
    progressRepo: widget.progressRepo,
    cueAnalyticsSink: widget.cueAnalyticsSink,
    videoAnalyticsSink: widget.videoAnalyticsSink,
    crashConsentBloc: widget.crashConsentBloc,
    observers: <NavigatorObserver>[
      widget.crashReporter.routerObserver,
      widget.navigationHistoryObserver,
    ],
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
    // Resumed: drain any crash reports that couldn't ship last
    // session. No-op when crash reporting is disabled.
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.crashReporter.flushQueue());
    }
    // Detached: final session_end best-effort. Spec is explicit that
    // this is not guaranteed to land — see CLAUDE.md / Slice F spec.
    if (state == AppLifecycleState.detached) {
      final start = _sessionStart;
      if (start != null) {
        final durMs = DateTime.now().difference(start).inMilliseconds;
        unawaited(widget.analyticsBuffer.log(AnalyticsEvent(
          eventType: AnalyticsEventTypes.sessionEnd,
          occurredAt: DateTime.now().toUtcIso8601(),
          payload: <String, dynamic>{'durationMs': durMs},
        )));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: widget.authBloc),
        BlocProvider<CrashConsentBloc>.value(value: widget.crashConsentBloc),
        // Slice P4 — SettingsCubit lives above the MaterialApp so any
        // descendant can `context.watch<SettingsCubit>()` for
        // themeMode, text scale, reduce-motion, etc.
        BlocProvider<SettingsCubit>.value(value: widget.settingsCubit),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp.router(
            title: 'Lifestream Learn',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            routerConfig: router,
            builder: (context, child) {
              // Honour the user's text-scale preference app-wide. We
              // stack on top of whatever scaler the router/MaterialApp
              // already chose so this plays nicely with a future
              // in-app zoom control if we ever add one.
              //
              // Reduce-motion: set `disableAnimations` on the ambient
              // MediaQuery so widgets that check it (most Material
              // implicit animations do) shorten or skip their
              // transitions. This is in addition to any future
              // per-widget opt-ins that read `settings.reduceMotion`
              // directly — the MediaQuery flag is the OS-parity path.
              final existing = MediaQuery.of(context);
              return MediaQuery(
                data: existing.copyWith(
                  textScaler:
                      TextScaler.linear(settings.textScaleMultiplier),
                  disableAnimations:
                      settings.reduceMotion || existing.disableAnimations,
                ),
                child: RootBackHandler(
                  historyObserver: widget.navigationHistoryObserver,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
