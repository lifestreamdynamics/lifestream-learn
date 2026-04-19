import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/designer_application.dart';
import 'package:lifestream_learn_app/data/repositories/designer_application_repository.dart';
import 'package:lifestream_learn_app/features/designer/designer_application_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements DesignerApplicationRepository {}

DesignerApplication _app({
  String id = 'a1',
  AppStatus status = AppStatus.pending,
  String? note,
  String? reviewerNote,
}) =>
    DesignerApplication(
      id: id,
      userId: 'u1',
      status: status,
      note: note,
      reviewerNote: reviewerNote,
      submittedAt: DateTime.utc(2026, 4, 1),
      reviewedAt: status == AppStatus.pending ? null : DateTime.utc(2026, 4, 2),
    );

Widget _wrap(DesignerApplicationRepository repo) {
  final router = GoRouter(
    initialLocation: '/designer-application',
    routes: [
      GoRoute(
        path: '/designer-application',
        builder: (_, __) => DesignerApplicationScreen(repo: repo),
      ),
      GoRoute(
        path: '/designer',
        builder: (_, __) => const Scaffold(body: Text('designer-home')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('renders form when no application exists', (tester) async {
    when(() => repo.getMy()).thenAnswer((_) async => null);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('designerApp.note')), findsOneWidget);
    expect(find.byKey(const Key('designerApp.submit')), findsOneWidget);
  });

  testWidgets('renders PENDING state with submitted date', (tester) async {
    when(() => repo.getMy()).thenAnswer((_) async => _app());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('designerApp.pending')), findsOneWidget);
    // Local date rendering isn't asserted exactly — just that the
    // string "2026-" appears (the submitted date is April 2026).
    expect(find.textContaining('2026'), findsWidgets);
  });

  testWidgets('renders APPROVED state with "go to Designer" CTA',
      (tester) async {
    when(() => repo.getMy())
        .thenAnswer((_) async => _app(status: AppStatus.approved));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('designerApp.approved')), findsOneWidget);
    expect(find.byKey(const Key('designerApp.goDesigner')), findsOneWidget);
  });

  testWidgets('renders REJECTED state with reviewer note + resubmit form',
      (tester) async {
    when(() => repo.getMy()).thenAnswer((_) async => _app(
          status: AppStatus.rejected,
          reviewerNote: 'Please add a portfolio link.',
        ));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('designerApp.rejected')), findsOneWidget);
    expect(find.byKey(const Key('designerApp.reviewerNote')), findsOneWidget);
    expect(
      find.textContaining('Please add a portfolio link.'),
      findsOneWidget,
    );
    // Resubmit form is present.
    expect(find.byKey(const Key('designerApp.note')), findsOneWidget);
    expect(find.byKey(const Key('designerApp.submit')), findsOneWidget);
  });

  testWidgets('submit dispatches repo call and transitions to PENDING',
      (tester) async {
    when(() => repo.getMy()).thenAnswer((_) async => null);
    when(() => repo.submit(note: any(named: 'note')))
        .thenAnswer((_) async => _app());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('designerApp.submit')));
    await tester.pumpAndSettle();

    verify(() => repo.submit(note: any(named: 'note'))).called(1);
    expect(find.byKey(const Key('designerApp.pending')), findsOneWidget);
  });

  testWidgets('shows inline error on ApiException from submit',
      (tester) async {
    when(() => repo.getMy()).thenAnswer((_) async => null);
    when(() => repo.submit(note: any(named: 'note')))
        .thenThrow(const ApiException(
      code: 'CONFLICT',
      statusCode: 409,
      message: 'You already have a pending application',
    ));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('designerApp.submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('designerApp.submitError')),
      findsOneWidget,
    );
    expect(find.textContaining('pending application'), findsOneWidget);
  });
}
