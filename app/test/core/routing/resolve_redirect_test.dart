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
const _designer = User(
  id: 'u3',
  email: 'd@x.com',
  displayName: 'D',
  role: UserRole.courseDesigner,
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

    test('granted + authed on /crash-consent → /courses (leave)', () {
      // Post-Slice G3 every role's home is /courses, so bouncing off the
      // consent screen lands on the unified Courses tab rather than /feed.
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/crash-consent',
        ),
        '/courses',
      );
    });

    test('denied + authed on /crash-consent → /courses (leave)', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.denied,
          location: '/crash-consent',
        ),
        '/courses',
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

    test('Authenticated + granted on /login → role home (/courses)', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/login',
        ),
        '/courses',
      );
    });
  });

  group('resolveRedirect — role gating', () {
    test('learner cannot reach /admin → role home /courses', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/admin',
        ),
        '/courses',
      );
    });

    test('designer cannot reach /admin → role home /courses', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_designer),
          consentStatus: CrashConsentStatus.granted,
          location: '/admin',
        ),
        '/courses',
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

    test('admin on /login → /courses (role home)', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_admin),
          consentStatus: CrashConsentStatus.granted,
          location: '/login',
        ),
        '/courses',
      );
    });

    test('designer on /login → /courses (role home)', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_designer),
          consentStatus: CrashConsentStatus.granted,
          location: '/login',
        ),
        '/courses',
      );
    });
  });

  group('resolveRedirect — deprecated-path folding', () {
    // The old shell had role-specific tabs (/browse, /my-courses, /designer).
    // Post-Slice G3 they're all folded into /courses; the resolver should
    // redirect, NOT 404 or apply role-gating, so old deep-links keep working
    // for every role.

    test('/my-courses redirects to /courses for learner', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/my-courses',
        ),
        '/courses',
      );
    });

    test('/my-courses redirects to /courses for admin', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_admin),
          consentStatus: CrashConsentStatus.granted,
          location: '/my-courses',
        ),
        '/courses',
      );
    });

    test('/my-courses redirects to /courses for designer', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_designer),
          consentStatus: CrashConsentStatus.granted,
          location: '/my-courses',
        ),
        '/courses',
      );
    });

    test('/browse redirects to /courses for learner', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/browse',
        ),
        '/courses',
      );
    });

    test('/browse redirects to /courses for admin', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_admin),
          consentStatus: CrashConsentStatus.granted,
          location: '/browse',
        ),
        '/courses',
      );
    });

    test('/browse redirects to /courses for designer', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_designer),
          consentStatus: CrashConsentStatus.granted,
          location: '/browse',
        ),
        '/courses',
      );
    });

    test('/designer redirects to /courses for learner (not role-blocked)', () {
      // A learner hitting the deprecated /designer path should be folded
      // into /courses just like everyone else — the path is gone, it's not
      // a designer-only route anymore.
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/designer',
        ),
        '/courses',
      );
    });

    test('/designer redirects to /courses for designer', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_designer),
          consentStatus: CrashConsentStatus.granted,
          location: '/designer',
        ),
        '/courses',
      );
    });

    test('/designer redirects to /courses for admin', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_admin),
          consentStatus: CrashConsentStatus.granted,
          location: '/designer',
        ),
        '/courses',
      );
    });
  });

  group('resolveRedirect — /courses is open to all authed roles', () {
    test('learner on /courses → null', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_learner),
          consentStatus: CrashConsentStatus.granted,
          location: '/courses',
        ),
        isNull,
      );
    });

    test('designer on /courses → null', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_designer),
          consentStatus: CrashConsentStatus.granted,
          location: '/courses',
        ),
        isNull,
      );
    });

    test('admin on /courses → null', () {
      expect(
        resolveRedirect(
          authState: const Authenticated(_admin),
          consentStatus: CrashConsentStatus.granted,
          location: '/courses',
        ),
        isNull,
      );
    });
  });
}
