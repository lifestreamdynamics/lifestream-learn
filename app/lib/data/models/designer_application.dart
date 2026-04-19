import 'package:freezed_annotation/freezed_annotation.dart';

part 'designer_application.freezed.dart';
part 'designer_application.g.dart';

/// Discriminator for a `DesignerApplication` row.
///
/// The backend `AppStatus` Prisma enum has exactly these three values
/// (`PENDING` → waiting on a human reviewer, `APPROVED` → user role was
/// flipped to `COURSE_DESIGNER`, `REJECTED` → user can re-apply, which
/// resurrects the row back to `PENDING`).
enum AppStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('APPROVED')
  approved,
  @JsonValue('REJECTED')
  rejected,
}

extension AppStatusX on AppStatus {
  String get label {
    switch (this) {
      case AppStatus.pending:
        return 'Pending';
      case AppStatus.approved:
        return 'Approved';
      case AppStatus.rejected:
        return 'Rejected';
    }
  }
}

/// A single designer-application row, keyed on `userId` server-side
/// (`@unique userId` means there's at most one row per user).
///
/// `reviewerNote` is the admin's note attached on APPROVED/REJECTED.
/// `note` is the learner's own note attached on submission.
@freezed
class DesignerApplication with _$DesignerApplication {
  const factory DesignerApplication({
    required String id,
    required String userId,
    required AppStatus status,
    String? note,
    String? reviewerNote,
    required DateTime submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) = _DesignerApplication;

  factory DesignerApplication.fromJson(Map<String, dynamic> json) =>
      _$DesignerApplicationFromJson(json);
}

/// Paginated list of designer applications (admin only).
@freezed
class DesignerApplicationPage with _$DesignerApplicationPage {
  const factory DesignerApplicationPage({
    required List<DesignerApplication> items,
    String? nextCursor,
    required bool hasMore,
  }) = _DesignerApplicationPage;

  factory DesignerApplicationPage.fromJson(Map<String, dynamic> json) =>
      _$DesignerApplicationPageFromJson(json);
}
