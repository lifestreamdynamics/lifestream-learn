import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Application roles. Serialized as uppercase-underscore to match the backend
/// Prisma enum (`ADMIN`, `COURSE_DESIGNER`, `LEARNER`).
enum UserRole {
  @JsonValue('ADMIN')
  admin,
  @JsonValue('COURSE_DESIGNER')
  courseDesigner,
  @JsonValue('LEARNER')
  learner,
}

extension UserRoleX on UserRole {
  /// Human-readable label; used as a short string on the placeholder HomeShell.
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.courseDesigner:
        return 'COURSE_DESIGNER';
      case UserRole.learner:
        return 'LEARNER';
    }
  }
}

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String displayName,
    required UserRole role,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
