import 'package:freezed_annotation/freezed_annotation.dart';

part 'mfa.freezed.dart';
part 'mfa.g.dart';

/// Slice P7a — shape of `GET /api/me/mfa`.
///
/// `webauthnCount` is always 0 until P7b lands; the field is here today
/// so the server contract is monotonic (clients compiled against this
/// model keep working when WebAuthn ships).
@freezed
class MfaMethods with _$MfaMethods {
  const factory MfaMethods({
    required bool totp,
    @Default(0) int webauthnCount,
    @Default(false) bool hasBackupCodes,
    @Default(0) int backupCodesRemaining,
  }) = _MfaMethods;

  factory MfaMethods.fromJson(Map<String, dynamic> json) =>
      _$MfaMethodsFromJson(json);
}

/// Shape returned by `POST /api/me/mfa/totp/enrol`.
///
/// `qrDataUrl` is a `data:image/png;base64,...` string the client feeds
/// into `Image.memory` after stripping the prefix. `secret` is the same
/// base32 value encoded inside the QR, shown to users who can't scan
/// (copy-to-clipboard). `pendingEnrolmentToken` MUST be returned to the
/// verify endpoint — the server holds no state between start and
/// confirm.
@freezed
class TotpEnrolmentStart with _$TotpEnrolmentStart {
  const factory TotpEnrolmentStart({
    required String secret,
    required String qrDataUrl,
    required String otpauthUrl,
    required String pendingEnrolmentToken,
  }) = _TotpEnrolmentStart;

  factory TotpEnrolmentStart.fromJson(Map<String, dynamic> json) =>
      _$TotpEnrolmentStartFromJson(json);
}

/// Shape returned by `POST /api/me/mfa/totp/verify` (enrol confirm).
///
/// `backupCodes` is the ONE-TIME plaintext set — once the user leaves
/// the enrolment screen the list is unrecoverable. The UI must push
/// the user through a "copy / print / acknowledge" gate before popping.
@freezed
class TotpBackupCodesResponse with _$TotpBackupCodesResponse {
  const factory TotpBackupCodesResponse({
    required List<String> backupCodes,
  }) = _TotpBackupCodesResponse;

  factory TotpBackupCodesResponse.fromJson(Map<String, dynamic> json) =>
      _$TotpBackupCodesResponseFromJson(json);
}
