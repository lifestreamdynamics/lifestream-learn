import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/user.dart';
import 'package:lifestream_learn_app/features/home/home_shell.dart';

void main() {
  group('tabsForRole', () {
    // Post-Slice G3 bottom-nav layout: every role shares the Feed / Courses
    // / Profile trio. Admin additionally sees an Admin tab between Courses
    // and Profile. The /browse, /my-courses and /designer tabs are gone —
    // their functionality is folded into /courses and deep-links redirect.

    test('LEARNER sees Feed | Courses | Profile (branches 0, 1, 3)', () {
      final tabs = tabsForRole(UserRole.learner);
      expect(tabs.length, 3);
      expect(
        tabs.map((t) => t.label).toList(),
        ['Feed', 'Courses', 'Profile'],
      );
      expect(
        tabs.map((t) => t.path).toList(),
        ['/feed', '/courses', '/profile'],
      );
      expect(
        tabs.map((t) => t.key).toList(),
        ['feed', 'courses', 'profile'],
      );
      expect(
        tabs.map((t) => t.branchIndex).toList(),
        [0, 1, 3],
      );
    });

    test(
      'COURSE_DESIGNER sees Feed | Courses | Profile (same as learner)',
      () {
        final tabs = tabsForRole(UserRole.courseDesigner);
        expect(tabs.length, 3);
        expect(
          tabs.map((t) => t.label).toList(),
          ['Feed', 'Courses', 'Profile'],
        );
        expect(
          tabs.map((t) => t.path).toList(),
          ['/feed', '/courses', '/profile'],
        );
        expect(
          tabs.map((t) => t.branchIndex).toList(),
          [0, 1, 3],
        );
      },
    );

    test('ADMIN sees Feed | Courses | Admin | Profile (branches 0, 1, 2, 3)',
        () {
      final tabs = tabsForRole(UserRole.admin);
      expect(tabs.length, 4);
      expect(
        tabs.map((t) => t.label).toList(),
        ['Feed', 'Courses', 'Admin', 'Profile'],
      );
      expect(
        tabs.map((t) => t.path).toList(),
        ['/feed', '/courses', '/admin', '/profile'],
      );
      expect(
        tabs.map((t) => t.key).toList(),
        ['feed', 'courses', 'admin', 'profile'],
      );
      expect(
        tabs.map((t) => t.branchIndex).toList(),
        [0, 1, 2, 3],
      );
    });

    test('branchIndex mapping is stable across roles', () {
      // First slot is always Feed → branch 0.
      expect(tabsForRole(UserRole.learner).first.branchIndex, 0);
      expect(tabsForRole(UserRole.courseDesigner).first.branchIndex, 0);
      expect(tabsForRole(UserRole.admin).first.branchIndex, 0);
      // Last slot is always Profile → branch 3.
      expect(tabsForRole(UserRole.learner).last.branchIndex, 3);
      expect(tabsForRole(UserRole.courseDesigner).last.branchIndex, 3);
      expect(tabsForRole(UserRole.admin).last.branchIndex, 3);
      // Second slot is always Courses → branch 1.
      expect(tabsForRole(UserRole.learner)[1].branchIndex, 1);
      expect(tabsForRole(UserRole.courseDesigner)[1].branchIndex, 1);
      expect(tabsForRole(UserRole.admin)[1].branchIndex, 1);
      // Admin-only: third slot is Admin → branch 2, with the 'admin' key.
      expect(tabsForRole(UserRole.admin)[2].branchIndex, 2);
      expect(tabsForRole(UserRole.admin)[2].key, 'admin');
    });

    test('courses tab uses school icons (filled + outlined)', () {
      final learnerCourses = tabsForRole(UserRole.learner)[1];
      expect(learnerCourses.icon, Icons.school_outlined);
      expect(learnerCourses.selectedIcon, Icons.school_rounded);
    });
  });
}
