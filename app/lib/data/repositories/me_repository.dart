import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/mfa.dart';
import '../models/session.dart';
import '../models/user.dart';
import '../models/webauthn.dart';

/// Slice P8 — typed exception surfaced by `exportMyData` on 429.
///
/// The server enforces a per-user 1-request-per-24h ceiling on the
/// export endpoint and returns a `Retry-After` header (draft-7 rate-
/// limit standard) with the seconds until the next allowed call. We
/// surface a dedicated exception type (not a bare `ApiException`) so
/// the UI can render "You can export once per day. Try again in X
/// hours." without string-matching the message.
class ExportRateLimitException implements Exception {
  const ExportRateLimitException({this.retryAfterSeconds});

  /// Seconds until the next allowed request, parsed from the
  /// `Retry-After` header. Null when the header is absent or unparsable.
  final int? retryAfterSeconds;

  /// Retry window as a `Duration`. Null when [retryAfterSeconds] is null.
  Duration? get retryAfter => retryAfterSeconds == null
      ? null
      : Duration(seconds: retryAfterSeconds!);

  @override
  String toString() => 'ExportRateLimitException(retryAfter=$retryAfterSeconds)';
}

/// Wrapper around `PATCH /api/me` and `POST /api/me/avatar`. Mirrors the
/// patterns in `AuthRepository` — Dio under the hood, `DioException`
/// normalised to `ApiException` via `_unwrap`.
class MeRepository {
  MeRepository(this._dio);

  final Dio _dio;

  /// Update the caller's profile. All args are optional; passing none
  /// exercises the server's idempotent no-op path.
  ///
  /// Returns the fresh `User` from the server so callers can update
  /// their cached `AuthState.user` in one round-trip.
  Future<User> patchMe({
    String? displayName,
    bool? useGravatar,
    Map<String, dynamic>? preferences,
  }) async {
    final body = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (useGravatar != null) 'useGravatar': useGravatar,
      if (preferences != null) 'preferences': preferences,
    };
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/me',
        data: body,
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty /api/me response',
        );
      }
      return User.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Fetch the caller's stored avatar bytes.
  ///
  /// GETs `/api/me/avatar`. Returns null when the server responds 204
  /// (no avatar set) so callers can fall through to Gravatar / initials
  /// without distinguishing "no avatar" from a hard error. The dio
  /// interceptor attaches the bearer token; bytes come back in-memory
  /// because the payload is capped at 2 MB.
  Future<Uint8List?> fetchMyAvatar() async {
    try {
      final response = await _dio.get<List<int>>(
        '/api/me/avatar',
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 204) return null;
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      // A 204 sometimes surfaces as a DioException with an empty body —
      // treat any "no content" response as "no avatar" rather than an
      // error. Everything else propagates as an ApiException so the
      // caller can distinguish network failure from an absent avatar.
      if (e.response?.statusCode == 204) return null;
      throw _unwrap(e);
    }
  }

  /// Upload a new avatar. The server accepts a raw image body (not
  /// multipart) with one of `image/jpeg`, `image/png`, `image/webp`
  /// as the content type. Max 2 MB.
  ///
  /// Returns a `User`-shaped object the caller can splice into state.
  /// The server actually returns `{ avatarKey, avatarUrl }`; we fetch
  /// the rest of the fields with a follow-up `GET /api/auth/me` so the
  /// caller gets a single uniform type back.
  Future<User> uploadAvatar(Uint8List bytes, String contentType) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/me/avatar',
        data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        options: Options(
          contentType: contentType,
          headers: <String, dynamic>{
            // `content-length` must be set explicitly when the body is a
            // stream — Dio otherwise emits a chunked transfer which
            // `express.raw()` refuses with a 400.
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
      // Server returns `{ avatarKey, avatarUrl }` on the upload endpoint,
      // not a full user row. Refetch the user so the caller gets the
      // authoritative merged view — keeps the client model consistent
      // with what `/api/auth/me` would have returned.
      final meResponse = await _dio.get<Map<String, dynamic>>('/api/auth/me');
      final meData = meResponse.data;
      if (meData == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty /api/auth/me response',
        );
      }
      return User.fromJson(meData);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P5 — change the caller's password.
  ///
  /// POSTs `{ currentPassword, newPassword }` to `/api/me/password`. On
  /// success the server returns 204 and implicitly revokes every refresh
  /// token minted before this call; the caller should treat the next
  /// refresh failure as "session expired, please log in again".
  ///
  /// Maps wrong-current-password to `ApiException(code: 'UNAUTHORIZED',
  /// statusCode: 401)` so UI code can render an inline error on the
  /// current-password field without string-matching the message.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        '/api/me/password',
        data: <String, dynamic>{
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P5 — soft-delete the caller's account.
  ///
  /// DELETEs `/api/me` with a `{ currentPassword }` body. Server returns
  /// 204 on success; the row is marked with a 30-day recovery window and
  /// all tokens stop working on next refresh. The caller is expected to
  /// log out + navigate away immediately.
  Future<void> deleteAccount({
    required String currentPassword,
  }) async {
    try {
      await _dio.delete<void>(
        '/api/me',
        data: <String, dynamic>{
          'currentPassword': currentPassword,
        },
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P6 — list the caller's active sessions.
  ///
  /// GETs `/api/me/sessions`. The server returns a JSON array of
  /// sessions, newest first. Each row includes a `current: bool` flag
  /// the UI uses to label the caller's own device.
  Future<List<Session>> listSessions() async {
    try {
      final response = await _dio.get<dynamic>('/api/me/sessions');
      final raw = response.data;
      if (raw is! List) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Malformed sessions response',
        );
      }
      return raw
          .map((e) => Session.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P6 — revoke a single session by id.
  ///
  /// DELETEs `/api/me/sessions/:sessionId`. Server returns 204 on
  /// success and 404 when the session is not found or not owned by the
  /// caller (the controller deliberately conflates the two cases so a
  /// client can't probe for ids across accounts).
  Future<void> revokeSession(String sessionId) async {
    try {
      await _dio.delete<void>('/api/me/sessions/$sessionId');
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P6 — sign out every other device.
  ///
  /// DELETEs `/api/me/sessions` — the server revokes every session for
  /// the caller except the one matching the access token's `sid`
  /// claim. Returns 204 even when there are no other sessions (idempotent).
  Future<void> revokeAllOtherSessions() async {
    try {
      await _dio.delete<void>('/api/me/sessions');
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7a — list the caller's currently-enrolled MFA factors.
  ///
  /// GETs `/api/me/mfa`. Server returns
  /// `{ totp, webauthnCount, hasBackupCodes, backupCodesRemaining }`.
  /// Used by the profile `MfaCard` + settings security section to
  /// render the right call-to-action ("Set up" vs "Disable").
  Future<MfaMethods> fetchMfaMethods() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/me/mfa');
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty /api/me/mfa response',
        );
      }
      return MfaMethods.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7a — begin TOTP enrolment.
  ///
  /// POSTs `/api/me/mfa/totp/enrol` (empty body). Server returns the
  /// fresh base32 secret + otpauth URI + QR data URL + a short-lived
  /// pending token that the client must hand back to the verify step.
  /// Throws [ApiException] with `statusCode == 409` when a TOTP factor
  /// is already enrolled.
  Future<TotpEnrolmentStart> startTotpEnrol() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/me/mfa/totp/enrol',
        data: const <String, dynamic>{},
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty TOTP enrol response',
        );
      }
      return TotpEnrolmentStart.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7a — confirm TOTP enrolment.
  ///
  /// POSTs `{ pendingToken, code, label? }` to
  /// `/api/me/mfa/totp/verify`. On success the server returns 10
  /// plaintext backup codes — store them client-side ONCE and walk the
  /// user through a copy/acknowledge flow before leaving the screen.
  /// 401 maps to wrong-code or expired pending token (server
  /// deliberately conflates both); 409 to "already enrolled".
  Future<TotpBackupCodesResponse> confirmTotpEnrol({
    required String pendingToken,
    required String code,
    String? label,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/me/mfa/totp/verify',
        data: <String, dynamic>{
          'pendingToken': pendingToken,
          'code': code,
          if (label != null && label.isNotEmpty) 'label': label,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty confirm response',
        );
      }
      return TotpBackupCodesResponse.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7a — disable TOTP.
  ///
  /// DELETEs `/api/me/mfa/totp` with
  /// `{ currentPassword, code }`. Requires BOTH the current password
  /// and a fresh 6-digit code — same re-auth posture as P5 destructive
  /// ops. 204 on success.
  Future<void> disableTotp({
    required String currentPassword,
    required String code,
  }) async {
    try {
      await _dio.delete<void>(
        '/api/me/mfa/totp',
        data: <String, dynamic>{
          'currentPassword': currentPassword,
          'code': code,
        },
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7b — list the caller's registered WebAuthn passkeys.
  ///
  /// GETs `/api/me/mfa/webauthn`. Empty list when none are registered.
  Future<List<WebauthnCredential>> fetchWebauthnCredentials() async {
    try {
      final response = await _dio.get<dynamic>('/api/me/mfa/webauthn');
      final raw = response.data;
      if (raw is! List) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Malformed passkey list response',
        );
      }
      return raw
          .map((e) => WebauthnCredential.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7b — begin WebAuthn registration.
  ///
  /// POSTs `/api/me/mfa/webauthn/register/options` (empty body). Returns
  /// the creation options JSON the platform Credential Manager expects
  /// plus a server-held pending token the client passes back to
  /// [verifyWebauthnRegistration].
  Future<WebauthnRegistrationOptions> startWebauthnRegistration() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/me/mfa/webauthn/register/options',
        data: const <String, dynamic>{},
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty passkey options response',
        );
      }
      return WebauthnRegistrationOptions.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P7b — confirm WebAuthn registration.
  ///
  /// POSTs `{ pendingToken, attestationResponse, label? }`. Server
  /// verifies the attestation against the challenge carried inside the
  /// pending token, writes an `MfaCredential(kind=WEBAUTHN)`, and on
  /// the FIRST MFA enrolment also returns 10 plaintext backup codes.
  ///
  /// Returns the raw response map so the screen can read both
  /// `credentialId` and the optional `backupCodes` array.
  Future<Map<String, dynamic>> verifyWebauthnRegistration({
    required String pendingToken,
    required Map<String, dynamic> attestationResponse,
    String? label,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/me/mfa/webauthn/register/verify',
        data: <String, dynamic>{
          'pendingToken': pendingToken,
          'attestationResponse': attestationResponse,
          if (label != null && label.isNotEmpty) 'label': label,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty passkey verify response',
        );
      }
      return data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P8 — download the caller's personal-data export.
  ///
  /// GETs `/api/me/export`. Server returns a typed JSON document
  /// (`schemaVersion: 1`) containing the user row minus credentials,
  /// enrollments, attempts, analytics events (capped at 10k most-
  /// recent), achievements, sessions (with IP hashes truncated to
  /// 8 hex chars), and count-only pointers for owned /collaborator
  /// courses. Returns the parsed JSON as a `Map<String, dynamic>` so
  /// the caller can both serialise it to disk for share-sheet export
  /// and inspect individual fields for UI (e.g. truncation warnings).
  ///
  /// 401 — not authenticated.
  /// 403 — account is soft-deleted; export must happen BEFORE delete.
  /// 429 — rate limited (1 req per 24h per user). The `Retry-After`
  ///       header is surfaced via [ExportRateLimitException] so the
  ///       UI can show "Try again in X hours".
  Future<Map<String, dynamic>> exportMyData() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/me/export');
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty /api/me/export response',
        );
      }
      return data;
    } on DioException catch (e) {
      // Surface the 429 as a typed exception so the UI can render a
      // friendly "try again in X hours" message without string-matching.
      if (e.response?.statusCode == 429) {
        final retryAfterRaw =
            e.response?.headers.value('retry-after') ?? '';
        final retryAfterSeconds = int.tryParse(retryAfterRaw);
        throw ExportRateLimitException(
          retryAfterSeconds: retryAfterSeconds,
        );
      }
      throw _unwrap(e);
    }
  }

  /// Slice P7b — delete a passkey.
  ///
  /// DELETEs `/api/me/mfa/webauthn/:credentialId` with
  /// `{ currentPassword }`. Requires current password — same re-auth
  /// posture as P5 destructive ops. Server returns 204 on success and
  /// 404 when the credential doesn't exist or belongs to another user.
  Future<void> deleteWebauthnCredential({
    required String credentialId,
    required String currentPassword,
  }) async {
    try {
      await _dio.delete<void>(
        '/api/me/mfa/webauthn/$credentialId',
        data: <String, dynamic>{'currentPassword': currentPassword},
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  ApiException _unwrap(DioException e) {
    final err = e.error;
    if (err is ApiException) return err;
    return ApiException(
      code: 'NETWORK_ERROR',
      statusCode: e.response?.statusCode ?? 0,
      message: e.message ?? 'Network error',
    );
  }
}
