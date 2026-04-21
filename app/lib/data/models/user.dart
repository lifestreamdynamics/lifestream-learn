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
    // Slice P1 — profile screen additions. All optional on the client so
    // the model stays backward-compatible with older `/api/auth/me`
    // payloads (e.g. between rolling app + API upgrades).
    //
    // - `createdAt`: ISO-8601 string on the wire; freezed + json_serializable
    //   decode to a DateTime automatically.
    // - `avatarKey`: object-storage key, not a URL. The media-serving
    //   route arrives in a later slice; the ProfileHeader widget
    //   composes a display URL then. For now, a non-null key is a
    //   signal that an avatar exists; we still render initials.
    // - `useGravatar`: opt-in fallback flag (defaults off to match
    //   backend default).
    // - `preferences`: free-form bag (theme / playback / a11y) — Slice
    //   P4 introduces a strongly-typed wrapper on top.
    DateTime? createdAt,
    String? avatarKey,
    @Default(false) bool useGravatar,
    Map<String, dynamic>? preferences,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
