import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/user.dart';

void main() {
  group('UserRoleX.label', () {
    test('learner → LEARNER', () {
      expect(UserRole.learner.label, 'LEARNER');
    });
    test('courseDesigner → COURSE_DESIGNER', () {
      expect(UserRole.courseDesigner.label, 'COURSE_DESIGNER');
    });
    test('admin → ADMIN', () {
      expect(UserRole.admin.label, 'ADMIN');
    });
  });

  group('User.fromJson', () {
    test('parses all fields + maps Prisma enum values to Dart enum', () {
      final u = User.fromJson(<String, dynamic>{
        'id': 'u1',
        'email': 'a@b.com',
        'displayName': 'A',
        'role': 'COURSE_DESIGNER',
      });
      expect(u.role, UserRole.courseDesigner);
      expect(u.email, 'a@b.com');
    });
  });
}
