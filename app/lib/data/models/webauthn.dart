import 'package:freezed_annotation/freezed_annotation.dart';

part 'webauthn.freezed.dart';
part 'webauthn.g.dart';

/// Slice P7b — one row returned by `GET /api/me/mfa/webauthn`.
///
/// `credentialId` is a base64url string — matches the spec-defined
/// `PublicKeyCredential.id` that the platform Credential Manager
/// round-trips. `transports` is a free-form list (e.g. `"internal"`,
/// `"usb"`, `"nfc"`, `"ble"`) the UI renders as chips so the user can
/// tell their Pixel passkey apart from a hardware security key.
@freezed
class WebauthnCredential with _$WebauthnCredential {
  const factory WebauthnCredential({
    required String id,
    required String credentialId,
    String? label,
    required DateTime createdAt,
    DateTime? lastUsedAt,
    @Default(<String>[]) List<String> transports,
    String? aaguid,
  }) = _WebauthnCredential;

  factory WebauthnCredential.fromJson(Map<String, dynamic> json) =>
      _$WebauthnCredentialFromJson(json);
}

/// Server → client shape from `POST /api/me/mfa/webauthn/register/options`.
///
/// `options` is a pass-through of the WebAuthn
/// `PublicKeyCredentialCreationOptionsJSON` (RFC 9052 flavoured JSON).
/// We don't model the nested shape — the Credential Manager plugin
/// accepts the raw JSON string, so we keep it in-flight as
/// `Map<String, dynamic>` and let the plugin-layer helper serialize.
@freezed
class WebauthnRegistrationOptions with _$WebauthnRegistrationOptions {
  const factory WebauthnRegistrationOptions({
    required Map<String, dynamic> options,
    required String pendingToken,
  }) = _WebauthnRegistrationOptions;

  factory WebauthnRegistrationOptions.fromJson(Map<String, dynamic> json) =>
      _$WebauthnRegistrationOptionsFromJson(json);
}

/// Server → client shape from `POST /api/auth/login/mfa/webauthn/options`.
///
/// Same "let the plugin handle the nested JSON" approach as
/// [WebauthnRegistrationOptions]. `challengeToken` is an opaque JWT
/// the client holds onto between `options` and `verify`.
@freezed
class WebauthnAssertionOptions with _$WebauthnAssertionOptions {
  const factory WebauthnAssertionOptions({
    required Map<String, dynamic> options,
    required String challengeToken,
  }) = _WebauthnAssertionOptions;

  factory WebauthnAssertionOptions.fromJson(Map<String, dynamic> json) =>
      _$WebauthnAssertionOptionsFromJson(json);
}
