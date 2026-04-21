import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

/// Slice P6 — a single row from `GET /api/me/sessions`.
///
/// Mirrors the server's `PublicSession` view:
/// - `deviceLabel` — coarse hand-rolled parse of the UA header on login
///   (`"Android"`, `"iPhone"`, `"Windows"`, …). Null when the server
///   could not derive anything useful.
/// - `ipHashPrefix` — first 8 hex chars of `sha256(ip + ":" + salt)`.
///   Never the raw IP. The client treats this as an opaque discriminator
///   a user can eyeball for "same device as last time".
/// - `createdAt` — when the session (refresh-token lineage) was first
///   minted.
/// - `lastSeenAt` — updated on every successful refresh rotation.
/// - `current` — true iff this row matches the caller's current access
///   token's `sid` claim. Drives the "You're signed in here" label in
///   the sessions screen.
@freezed
class Session with _$Session {
  const factory Session({
    required String id,
    String? deviceLabel,
    String? ipHashPrefix,
    required DateTime createdAt,
    required DateTime lastSeenAt,
    @Default(false) bool current,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
}
