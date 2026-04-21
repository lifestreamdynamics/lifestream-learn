import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/auth/auth_bloc.dart';
import 'package:lifestream_learn_app/core/auth/auth_event.dart';
import 'package:lifestream_learn_app/core/auth/auth_state.dart';
import 'package:lifestream_learn_app/data/models/achievement.dart';
import 'package:lifestream_learn_app/data/models/mfa.dart';
import 'package:lifestream_learn_app/data/models/progress.dart';
import 'package:lifestream_learn_app/data/models/user.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/data/repositories/progress_repository.dart';
import 'package:lifestream_learn_app/features/profile/profile_screen.dart';
import 'package:mocktail/mocktail.dart';

// Mock the bloc so the test doesn't race a real AuthRepository/TokenStore
// or leak a live stream (which made `pumpAndSettle` never complete).
class _MockAuthBloc extends Mock implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockMeRepo extends Mock implements MeRepository {}

class _MockProgressRepo extends Mock implements ProgressRepository {}

OverallProgress _emptyProgress() => const OverallProgress(
      summary: ProgressSummary(
        coursesEnrolled: 0,
        lessonsCompleted: 0,
        totalCuesAttempted: 0,
        totalCuesCorrect: 0,
        totalWatchTimeMs: 0,
      ),
      perCourse: [],
    );

User _user({
  String displayName = 'Jane Doe',
  UserRole role = UserRole.learner,
  DateTime? createdAt,
}) =>
    User(
      id: 'u1',
      email: 'jane@example.local',
      displayName: displayName,
      role: role,
      createdAt: createdAt ?? DateTime.utc(2026, 4, 1),
    );

Widget _wrap({
  required AuthBloc authBloc,
  required MeRepository meRepo,
  required ProgressRepository progressRepo,
}) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, __) =>
            ProfileScreen(meRepo: meRepo, progressRepo: progressRepo),
      ),
      GoRoute(
        path: '/designer-application',
        builder: (_, __) =>
            const Scaffold(body: Text('designer-application')),
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
    registerFallbackValue(Uint8List(0));
  });

  late _MockAuthBloc authBloc;
  late _MockMeRepo meRepo;
  late _MockProgressRepo progressRepo;

  void stubAuthed(User user) {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(Authenticated(user));
    // Empty stream — the BlocBuilder subscribes once, finds no events,
    // renders the current state. Avoids the pumpAndSettle hang caused
    // by a never-closing broadcast stream.
    when(() => authBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => authBloc.close()).thenAnswer((_) async {});
    when(() => authBloc.add(any())).thenReturn(null);
  }

  setUp(() {
    meRepo = _MockMeRepo();
    progressRepo = _MockProgressRepo();
    // Default: P2 progress fetch returns the zero-state. Individual
    // tests can override with their own stub before pumping.
    when(() => progressRepo.fetchOverall())
        .thenAnswer((_) async => _emptyProgress());
    // Slice P3 — default empty achievements catalog so the grid's
    // initState fetch doesn't throw.
    when(() => progressRepo.fetchAchievements()).thenAnswer(
      (_) async => const AchievementsResponse(
        unlocked: [],
        locked: [],
        unlockedAtByAchievementId: {},
      ),
    );
    // Slice P3 — profile screen silently patches `timezoneOffsetMinutes`
    // if missing on first load. Stub a success so the fire-and-forget
    // call doesn't throw.
    when(() => meRepo.patchMe(
          displayName: any(named: 'displayName'),
          useGravatar: any(named: 'useGravatar'),
          preferences: any(named: 'preferences'),
        )).thenAnswer((_) async => _user());
    // Slice P7a — MfaCard fetches `/api/me/mfa` on mount. Default to
    // "no MFA enrolled" so the card renders the "Set up" tile; tests
    // that want to assert the enrolled state override this stub.
    when(() => meRepo.fetchMfaMethods()).thenAnswer(
      (_) async => const MfaMethods(totp: false),
    );
  });

  testWidgets('renders header, stats, account section, logout for learner',
      (tester) async {
    stubAuthed(_user());

    await tester.pumpWidget(_wrap(authBloc: authBloc, meRepo: meRepo, progressRepo: progressRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile.displayName')), findsOneWidget);
    expect(find.byKey(const Key('profile.email')), findsOneWidget);
    expect(find.byKey(const Key('profile.role')), findsOneWidget);
    expect(find.byKey(const Key('profile.memberSince')), findsOneWidget);
    expect(find.byKey(const Key('profile.avatar')), findsOneWidget);

    // Quick stats strip — all four tiles present, all showing placeholders.
    expect(find.byKey(const Key('profile.stat.courses')), findsOneWidget);
    expect(find.byKey(const Key('profile.stat.lessons')), findsOneWidget);
    expect(find.byKey(const Key('profile.stat.streak')), findsOneWidget);
    expect(find.byKey(const Key('profile.stat.accuracy')), findsOneWidget);

    // Account section — edit profile enabled, others coming soon.
    expect(
      find.byKey(const Key('profile.account.editProfile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile.account.password')),
      findsOneWidget,
    );
    // Slice P7a — MFA tile now loads `GET /api/me/mfa` and toggles
    // between `profile.mfa.setup`, `profile.mfa.manage`, and
    // `profile.mfa.loading`. The default stub returns `totp: false`,
    // so the "Set up" tile should be present once the async load
    // completes (pumpAndSettle above).
    expect(find.byKey(const Key('profile.mfa.setup')), findsOneWidget);
    expect(
      find.byKey(const Key('profile.account.sessions')),
      findsOneWidget,
    );
    // Slice P7a — no more "Coming soon" tiles in the Account section;
    // both MFA and Sessions tiles are now live.

    // Slice P4 — the three per-topic Settings coming-soon tiles are
    // replaced by a single entry that pushes `/profile/settings`.
    expect(
      find.byKey(const Key('profile.settings.entry')),
      findsOneWidget,
    );

    // Learner-only: apply to become a designer.
    expect(find.byKey(const Key('profile.applyDesigner')), findsOneWidget);

    expect(find.byKey(const Key('profile.logout')), findsOneWidget);
  });

  testWidgets('no "apply to become designer" card for non-learners',
      (tester) async {
    stubAuthed(_user(role: UserRole.admin));

    await tester.pumpWidget(_wrap(authBloc: authBloc, meRepo: meRepo, progressRepo: progressRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile.applyDesigner')), findsNothing);
  });

  testWidgets('edit profile tile opens the sheet and save dispatches patch',
      (tester) async {
    final user = _user(displayName: 'Old Name');
    final updated = _user(displayName: 'New Name');
    when(() => meRepo.patchMe(
          displayName: any(named: 'displayName'),
          useGravatar: any(named: 'useGravatar'),
          preferences: any(named: 'preferences'),
        )).thenAnswer((_) async => updated);
    stubAuthed(user);

    await tester.pumpWidget(_wrap(authBloc: authBloc, meRepo: meRepo, progressRepo: progressRepo));
    await tester.pumpAndSettle();

    // Slice P3 — the profile screen is now tall enough that the edit
    // profile tile is below the fold in a 800x600 test viewport.
    // Scroll it into view before tapping.
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile.account.editProfile')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile.account.editProfile')));
    await tester.pumpAndSettle();

    // Sheet is open.
    expect(find.byKey(const Key('editProfile.displayName')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('editProfile.displayName')),
      'New Name',
    );
    await tester.tap(find.byKey(const Key('editProfile.save')));
    await tester.pumpAndSettle();

    verify(() => meRepo.patchMe(displayName: 'New Name')).called(1);
    // The bloc should have received a UserUpdated event carrying the
    // refreshed user — assert via the mock's call log.
    final captured = verify(() => authBloc.add(captureAny())).captured;
    expect(
      captured.whereType<UserUpdated>().any((e) => e.user.displayName == 'New Name'),
      isTrue,
    );
  });

  testWidgets('logout tile fires LoggedOut on the bloc', (tester) async {
    stubAuthed(_user());

    await tester.pumpWidget(_wrap(authBloc: authBloc, meRepo: meRepo, progressRepo: progressRepo));
    await tester.pumpAndSettle();

    // The logout button is below the fold of the 800x600 test viewport;
    // scroll it into view before tapping.
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile.logout')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile.logout')));
    await tester.pump();

    verify(() => authBloc.add(any(that: isA<LoggedOut>()))).called(1);
  });

  testWidgets(
      'Slice P3: recentlyUnlocked achievements surface a SnackBar',
      (tester) async {
    when(() => progressRepo.fetchOverall()).thenAnswer(
      (_) async => OverallProgress(
        summary: const ProgressSummary(
          coursesEnrolled: 1,
          lessonsCompleted: 1,
          totalCuesAttempted: 3,
          totalCuesCorrect: 3,
          totalWatchTimeMs: 60000,
          currentStreak: 2,
          longestStreak: 5,
          overallAccuracy: 1.0,
          overallGrade: Grade.a,
        ),
        perCourse: const [],
        recentlyUnlocked: [
          AchievementSummary(
            id: 'first_lesson',
            title: 'First Lesson',
            iconKey: 'school',
            unlockedAt: DateTime.utc(2026, 4, 20),
          ),
        ],
      ),
    );
    // Fetch achievements for the grid too — empty is fine here.
    when(() => progressRepo.fetchAchievements()).thenAnswer(
      (_) async => const AchievementsResponse(
        unlocked: [],
        locked: [],
        unlockedAtByAchievementId: {},
      ),
    );
    stubAuthed(_user());

    await tester.pumpWidget(_wrap(
      authBloc: authBloc,
      meRepo: meRepo,
      progressRepo: progressRepo,
    ));
    // Pump instead of settle — the bloc emits after the microtask.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const Key('profile.unlockToast.first_lesson')),
      findsOneWidget,
    );
    expect(find.text('Unlocked: First Lesson'), findsOneWidget);
  });

  testWidgets(
      'Slice P3: silent patchMe fires with timezoneOffsetMinutes when pref missing',
      (tester) async {
    stubAuthed(_user()); // preferences unset
    await tester.pumpWidget(_wrap(
      authBloc: authBloc,
      meRepo: meRepo,
      progressRepo: progressRepo,
    ));
    await tester.pump();

    // Verify patchMe was called with a `preferences` map containing
    // `timezoneOffsetMinutes`. Exact value depends on test host tz; we
    // assert the key is present.
    final captured = verify(
      () => meRepo.patchMe(
        preferences: captureAny(named: 'preferences'),
      ),
    ).captured;
    expect(captured, isNotEmpty);
    final prefs = captured.first as Map<String, dynamic>;
    expect(prefs.containsKey('timezoneOffsetMinutes'), isTrue);
    expect(prefs['timezoneOffsetMinutes'], isA<int>());
  });

  testWidgets(
      'Slice P3: no patchMe when timezoneOffsetMinutes already present',
      (tester) async {
    final userWithTz = User(
      id: 'u1',
      email: 'jane@example.local',
      displayName: 'Jane Doe',
      role: UserRole.learner,
      createdAt: DateTime.utc(2026, 4, 1),
      preferences: const <String, dynamic>{
        'timezoneOffsetMinutes': -300,
      },
    );
    stubAuthed(userWithTz);
    await tester.pumpWidget(_wrap(
      authBloc: authBloc,
      meRepo: meRepo,
      progressRepo: progressRepo,
    ));
    await tester.pump();
    verifyNever(
      () => meRepo.patchMe(
        preferences: any(named: 'preferences'),
      ),
    );
  });

  testWidgets('shows spinner when state is not Authenticated', (tester) async {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => authBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => authBloc.close()).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(authBloc: authBloc, meRepo: meRepo, progressRepo: progressRepo));
    // Intentionally no pumpAndSettle — CircularProgressIndicator animates
    // forever.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
