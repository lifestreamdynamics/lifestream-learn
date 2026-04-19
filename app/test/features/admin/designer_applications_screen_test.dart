import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/platform/flag_secure.dart';
import 'package:lifestream_learn_app/data/models/designer_application.dart';
import 'package:lifestream_learn_app/data/repositories/admin_designer_application_repository.dart';
import 'package:lifestream_learn_app/features/admin/designer_applications_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AdminDesignerApplicationRepository {}

DesignerApplication _app(String id, {String userId = 'u1'}) =>
    DesignerApplication(
      id: id,
      userId: userId,
      status: AppStatus.pending,
      submittedAt: DateTime.utc(2026, 4, 1),
    );

Widget _wrap(AdminDesignerApplicationRepository repo) => MaterialApp(
      // Wrap the screen in a Scaffold so the ScaffoldMessenger.showSnackBar
      // call from the review flow has a place to land. In production the
      // screen is a TabBarView child under AdminHomeScreen's Scaffold,
      // which supplies the messenger; tests replicate that host.
      home: Scaffold(body: DesignerApplicationsScreen(repo: repo)),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(AppStatus.approved);
  });

  setUp(() {
    // Stub FLAG_SECURE method channel so widget mount doesn't try to
    // talk to a real platform plugin.
    final channel = MethodChannel('com.lifestream.learn/flag_secure');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    FlagSecure.testChannel = channel;
  });

  tearDown(() {
    FlagSecure.testChannel = null;
  });

  testWidgets('renders a tile per PENDING application', (tester) async {
    final repo = _MockRepo();
    when(() => repo.list(
          status: any(named: 'status'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => DesignerApplicationPage(
          items: [_app('a1'), _app('a2'), _app('a3')],
          hasMore: false,
        ));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin.apps.list')), findsOneWidget);
    expect(find.byKey(const Key('admin.apps.tile.a1')), findsOneWidget);
    expect(find.byKey(const Key('admin.apps.tile.a2')), findsOneWidget);
    expect(find.byKey(const Key('admin.apps.tile.a3')), findsOneWidget);
  });

  testWidgets('empty result shows the empty-state', (tester) async {
    final repo = _MockRepo();
    when(() => repo.list(
          status: any(named: 'status'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const DesignerApplicationPage(
          items: [],
          hasMore: false,
        ));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin.apps.empty')), findsOneWidget);
  });

  testWidgets('approve flow: confirm → repo.review called → row removed',
      (tester) async {
    final repo = _MockRepo();
    when(() => repo.list(
          status: any(named: 'status'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => DesignerApplicationPage(
          items: [_app('a1')],
          hasMore: false,
        ));
    when(() => repo.review(
          any(),
          status: any(named: 'status'),
          reviewerNote: any(named: 'reviewerNote'),
        )).thenAnswer((_) async => _app('a1'));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin.apps.approve.a1')));
    await tester.pumpAndSettle();
    // Confirm the reviewer-note dialog.
    await tester.tap(find.byKey(const Key('admin.reviewerNote.Approve.confirm')));
    await tester.pumpAndSettle();

    verify(() => repo.review(
          'a1',
          status: AppStatus.approved,
          reviewerNote: any(named: 'reviewerNote'),
        )).called(1);
    // Row removed from the list after review.
    expect(find.byKey(const Key('admin.apps.tile.a1')), findsNothing);
  });
}
