import 'dart:convert';

import 'package:credential_manager/credential_manager.dart';

/// Slice P7b — thin wrapper around the platform Credential Manager.
///
/// Why a wrapper: the `credential_manager` plugin's types are JSON-ish
/// but not quite spec-shaped, and we want a single place to:
///   1. Translate the server's `PublicKeyCredentialCreationOptionsJSON`
///      / `PublicKeyCredentialRequestOptionsJSON` into the plugin's
///      `CredentialCreationOptions` / `CredentialLoginOptions` bags.
///   2. Flatten the plugin's `PublicKeyCredential` response back into a
///      server-shaped map (`{id, rawId, type, response:{…}}`) that the
///      WebAuthn verifier accepts without further rewriting.
///   3. Keep non-Android paths out of the app's main flow — this
///      platform is Android-only today; the `isSupported` getter lets
///      the UI degrade gracefully on unsupported hosts.
///
/// Option A (per the slice plan): we use the `credential_manager`
/// package unmodified. If it ever regresses, drop in a platform channel
/// against `androidx.credentials:credentials-play-services-auth` at
/// this seam.
class PasskeyPlatform {
  PasskeyPlatform({CredentialManager? credentialManager})
      : _cm = credentialManager ?? CredentialManager();

  final CredentialManager _cm;
  bool _initialized = false;

  /// True on platforms the plugin supports. Today: Android + iOS. Web /
  /// desktop return false so the UI can show a "passkeys unavailable"
  /// path instead of a runtime `MissingPluginException`.
  bool get isSupported {
    if (!_cm.isSupportedPlatform) return false;
    // Additional platform gate — we only ship Android today.
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Lazily initialise the plugin. Idempotent: subsequent calls are
  /// no-ops. The plugin requires `init()` before any save/get call.
  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _cm.init(preferImmediatelyAvailableCredentials: true);
    _initialized = true;
  }

  /// Walk the platform through a registration ceremony.
  ///
  /// [serverOptions] is the raw JSON object from
  /// `POST /api/me/mfa/webauthn/register/options`. Returns the
  /// attestation response as a JSON map — server-shaped with
  /// `{id, rawId, type, response:{attestationObject, clientDataJSON}}`.
  Future<Map<String, dynamic>> register(
    Map<String, dynamic> serverOptions,
  ) async {
    await _ensureInit();
    // The server hands us a spec-compliant
    // PublicKeyCredentialCreationOptionsJSON — the plugin's
    // `CredentialCreationOptions.fromJson` round-trips the top-level
    // fields but drops nothing, so we serialise + re-parse to avoid
    // shape drift as the spec evolves.
    final creationOptions = CredentialCreationOptions.fromJson(serverOptions);
    final saved = await _cm.savePasskeyCredentials(request: creationOptions);
    return _publicKeyCredentialToJson(saved);
  }

  /// Walk the platform through an authentication / assertion ceremony.
  ///
  /// [serverOptions] is the raw JSON object from
  /// `POST /api/auth/login/mfa/webauthn/options`. We pull out the
  /// fields the plugin's `CredentialLoginOptions` needs and ignore the
  /// rest (the plugin doesn't thread `allowCredentials` through yet;
  /// the platform resolves the matching passkey from its keychain).
  Future<Map<String, dynamic>> authenticate(
    Map<String, dynamic> serverOptions,
  ) async {
    await _ensureInit();
    final challenge = serverOptions['challenge'] as String;
    final rpId = serverOptions['rpId'] as String;
    final userVerification =
        (serverOptions['userVerification'] as String?) ?? 'preferred';
    final loginOptions = CredentialLoginOptions(
      challenge: challenge,
      rpId: rpId,
      userVerification: userVerification,
    );
    final creds = await _cm.getCredentials(passKeyOption: loginOptions);
    final pk = creds.publicKeyCredential;
    if (pk == null) {
      throw const PasskeyCancelledException();
    }
    return _publicKeyCredentialToJson(pk);
  }

  /// Normalise the plugin's `PublicKeyCredential` into the spec-shaped
  /// JSON our server's `@simplewebauthn/server` verifier expects.
  ///
  /// The plugin stores the base64url blobs on `pk.response.*` — we just
  /// flatten to the spec's nested form.
  Map<String, dynamic> _publicKeyCredentialToJson(PublicKeyCredential pk) {
    final raw = pk.toJson();
    // Drop plugin-specific fields that aren't part of the spec. The
    // server's validator uses `.passthrough()` but a narrower payload
    // keeps the Dio body smaller and the contract clearer.
    raw.removeWhere((k, v) => v == null);
    final response = raw['response'];
    if (response is Map) {
      (response as Map<String, dynamic>).removeWhere((k, v) => v == null);
    }
    return Map<String, dynamic>.from(raw);
  }

  /// Useful for debugging: surfaces the raw JSON the plugin built.
  String debugSerialize(Map<String, dynamic> obj) => jsonEncode(obj);
}

/// Thrown when the user cancels the platform prompt or no credential
/// matches. UI layer catches this and returns to the challenge screen
/// silently instead of surfacing a generic error.
class PasskeyCancelledException implements Exception {
  const PasskeyCancelledException();
}
