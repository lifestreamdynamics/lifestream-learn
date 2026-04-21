import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/session.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/security/sessions_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeRepo extends Mock implements MeRepository {}

Widget _wrap(MeRepository meRepo) {
  final router = GoRouter(
    initialLocation: '/profile/security/sessions',
    routes: [
      GoRoute(
        path: '/profile/security/sessions',
        builder: (_, __) => SessionsScreen(meRepo: meRepo),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Session _session({
  required String id,
  String? deviceLabel = 'Android',
  bool current = false,
  Duration lastSeen = const Duration(minutes: 5),
}) {
  return Session(
    id: id,
    deviceLabel: deviceLabel,
    ipHashPrefix: 'deadbeef',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    lastSeenAt: DateTime.now().subtract(lastSeen),
    current: current,
  );
}

void main() {
  late _MockMeRepo meRepo;

  setUp(() {
    meRepo = _MockMeRepo();
  });

  testWidgets('renders one tile per session with current flagged', (tester) async {
    when(() => meRepo.listSessions()).thenAnswer((_) async => [
          _session(id: 's1', deviceLabel: 'Android', current: true),
          _session(
            id: 's2',
            deviceLabel: 'macOS',
            lastSeen: const Duration(hours: 2),
          ),
        ]);
    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sessions.list')), findsOneWidget);
    expect(find.byKey(const Key('sessions.tile.s1')), findsOneWidget);
    expect(find.byKey(const Key('sessions.tile.s2')), findsOneWidget);
    // Current session shows the "signed in here" subtitle, not a menu.
    expect(find.text("You're signed in here"), findsOneWidget);
    // Non-current session shows "X hours ago" subtitle + menu.
    expect(find.byKey(const Key('sessions.tile.s2.menu')), findsOneWidget);
    // Current session's menu is NOT rendered.
    expect(find.byKey(const Key('sessions.tile.s1.menu')), findsNothing);
  });

  testWidgets('revoke-all button is disabled when only current session exists',
      (tester) async {
    when(() => meRepo.listSessions()).thenAnswer((_) async => [
          _session(id: 'only', current: true),
        ]);
    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('sessions.revokeAll')),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('revoke-all button enabled when there are other sessions', (
    tester,
  ) async {
    when(() => meRepo.listSessions()).thenAnswer((_) async => [
          _session(id: 's1', current: true),
          _session(
            id: 's2',
            deviceLabel: 'macOS',
            lastSeen: const Duration(hours: 2),
          ),
        ]);
    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('sessions.revokeAll')),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('revoke single session: calls repo + shows toast + reloads',
      (tester) async {
    int call = 0;
    when(() => meRepo.listSessions()).thenAnswer((_) async {
      call++;
      if (call == 1) {
        return [
          _session(id: 's1', current: true),
          _session(
            id: 's2',
            deviceLabel: 'macOS',
            lastSeen: const Duration(hours: 2),
          ),
        ];
      }
      // After revoke: only the current session remains.
      return [_session(id: 's1', current: true)];
    });
    when(() => meRepo.revokeSession('s2')).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    // Open the popup menu for the other session.
    await tester.tap(find.byKey(const Key('sessions.tile.s2.menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out this device'));
    await tester.pumpAndSettle();

    verify(() => meRepo.revokeSession('s2')).called(1);
    expect(find.byKey(const Key('sessions.revokeOneToast')), findsOneWidget);
    // Reload happened: only s1 left.
    expect(find.byKey(const Key('sessions.tile.s2')), findsNothing);
  });

  testWidgets('revoke all others: confirm dialog + repo call + reload', (
    tester,
  ) async {
    int call = 0;
    when(() => meRepo.listSessions()).thenAnswer((_) async {
      call++;
      if (call == 1) {
        return [
          _session(id: 's1', current: true),
          _session(
            id: 's2',
            deviceLabel: 'macOS',
            lastSeen: const Duration(hours: 2),
          ),
        ];
      }
      return [_session(id: 's1', current: true)];
    });
    when(() => meRepo.revokeAllOtherSessions()).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sessions.revokeAll')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sessions.revokeAllDialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sessions.revokeAllConfirm')));
    await tester.pumpAndSettle();

    verify(() => meRepo.revokeAllOtherSessions()).called(1);
    expect(find.byKey(const Key('sessions.revokeAllToast')), findsOneWidget);
    expect(find.byKey(const Key('sessions.tile.s2')), findsNothing);
  });

  testWidgets('list failure shows error message in empty state', (tester) async {
    when(() => meRepo.listSessions()).thenThrow(const ApiException(
      code: 'NETWORK_ERROR',
      statusCode: 0,
      message: 'Offline',
    ));
    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sessions.empty')), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('unknown-device label falls back to "Unknown device"',
      (tester) async {
    when(() => meRepo.listSessions()).thenAnswer((_) async => [
          _session(id: 's1', deviceLabel: null, current: true),
        ]);
    await tester.pumpWidget(_wrap(meRepo));
    await tester.pumpAndSettle();

    expect(find.text('Unknown device'), findsOneWidget);
  });
}
