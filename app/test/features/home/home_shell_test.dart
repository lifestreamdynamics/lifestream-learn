import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/user.dart';
import 'package:lifestream_learn_app/features/home/home_shell.dart';

void main() {
  group('tabsForRole', () {
    test('LEARNER sees Feed | Browse | My Courses | Profile', () {
      final tabs = tabsForRole(UserRole.learner);
      expect(
        tabs.map((t) => t.label).toList(),
        ['Feed', 'Browse', 'My Courses', 'Profile'],
      );
      expect(
        tabs.map((t) => t.path).toList(),
        ['/feed', '/browse', '/my-courses', '/profile'],
      );
    });

    test('COURSE_DESIGNER sees Feed | Designer | Profile', () {
      final tabs = tabsForRole(UserRole.courseDesigner);
      expect(
        tabs.map((t) => t.label).toList(),
        ['Feed', 'Designer', 'Profile'],
      );
      expect(
        tabs.map((t) => t.path).toList(),
        ['/feed', '/designer', '/profile'],
      );
    });

    test('ADMIN sees Feed | Admin | Profile', () {
      final tabs = tabsForRole(UserRole.admin);
      expect(
        tabs.map((t) => t.label).toList(),
        ['Feed', 'Admin', 'Profile'],
      );
      expect(
        tabs.map((t) => t.path).toList(),
        ['/feed', '/admin', '/profile'],
      );
    });

    test('branchIndex mapping is stable across roles', () {
      // Slot 0 is always Feed.
      expect(tabsForRole(UserRole.learner).first.branchIndex, 0);
      expect(tabsForRole(UserRole.courseDesigner).first.branchIndex, 0);
      expect(tabsForRole(UserRole.admin).first.branchIndex, 0);
      // Last slot (Profile) is always branch 3.
      expect(tabsForRole(UserRole.learner).last.branchIndex, 3);
      expect(tabsForRole(UserRole.courseDesigner).last.branchIndex, 3);
      expect(tabsForRole(UserRole.admin).last.branchIndex, 3);
      // Learner's third slot is My Courses → branch 2.
      expect(tabsForRole(UserRole.learner)[2].branchIndex, 2);
    });
  });
}
