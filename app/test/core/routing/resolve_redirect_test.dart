import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/auth/auth_state.dart';
import 'package:lifestream_learn_app/core/crash/crash_consent_bloc.dart';
import 'package:lifestream_learn_app/core/routing/app_router.dart';
import 'package:lifestream_learn_app/data/models/user.dart';

const _learner = User(
  id: 'u1',
  email: 'l@x.com',
  displayName: 'L',
  role: UserRole.learner,
);
const _admin = User(
  id: 'u2',
  email: 'a@x.com',
  displayName: 'A',
  role: UserRole.admin,
);

void main() {
  group('resolveRedirect — consent gating', () {
    test('undecided + authed on an authed route → /crash-consent', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.undecided,
          location: '/feed',
        ),
        '/crash-consent',
      );
    });

    test('undecided + authed on /login → /crash-consent (not role home)', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.undecided,
          location: '/login',
        ),
        '/crash-consent',
      );
    });

    test('undecided + authed already on /crash-consent → null (stay)', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.undecided,
          location: '/crash-consent',
        ),
        isNull,
      );
    });

    test('granted + authed on /crash-consent → /feed (leave)', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/crash-consent',
        ),
        '/feed',
      );
    });

    test('denied + authed on /crash-consent → /feed (leave)', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.denied,
          location: '/crash-consent',
        ),
        '/feed',
      );
    });

    test('granted + authed on /feed → null (no redirect)', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/feed',
        ),
        isNull,
      );
    });

    test('null consentStatus (gating disabled) does not block authed', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: null,
          location: '/feed',
        ),
        isNull,
      );
    });
  });

  group('resolveRedirect — auth gating', () {
    test('Unauthenticated on /feed → /login', () {
      expect(
        resolveRedirect(
          authState: const Unauthenticated(),
          consentStatus: null,
          location: '/feed',
        ),
        '/login',
      );
    });

    test('Unauthenticated already on /login → null', () {
      expect(
        resolveRedirect(
          authState: const Unauthenticated(),
          consentStatus: null,
          location: '/login',
        ),
        isNull,
      );
    });

    test('AuthInitial does not redirect (still booting)', () {
      expect(
        resolveRedirect(
          authState: const AuthInitial(),
          consentStatus: null,
          location: '/feed',
        ),
        isNull,
      );
    });

    test('Authenticated + granted on /login → role home', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/login',
        ),
        '/feed',
      );
    });
  });

  group('resolveRedirect — role gating', () {
    test('learner cannot reach /admin', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/admin',
        ),
        '/feed',
      );
    });

    test('admin can reach /admin', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_admin),
          consentStatus: CrashConsentStatus.granted,
          location: '/admin',
        ),
        isNull,
      );
    });

    test('admin cannot reach /my-courses', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_admin),
          consentStatus: CrashConsentStatus.granted,
          location: '/my-courses',
        ),
        '/feed',
      );
    });
  });
}
