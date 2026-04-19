import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_tokens.dart';

/// Thin async wrapper around `FlutterSecureStorage` for the access/refresh
/// token pair. Platform-agnostic — the `AndroidOptions` (including
/// `encryptedSharedPreferences: true`) are configured at the storage
/// instantiation site (`main.dart`) so this class remains test-friendly.
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _kAccess = 'auth.access';
  static const _kRefresh = 'auth.refresh';

  /// Persist both tokens. The two writes happen sequentially; in the worst
  /// case (process killed between them) `read()` returns null because it
  /// requires both keys.
  Future<void> save(AuthTokens tokens) async {
    await _storage.write(key: _kAccess, value: tokens.accessToken);
    await _storage.write(key: _kRefresh, value: tokens.refreshToken);
  }

  /// Returns null if either key is missing.
  Future<AuthTokens?> read() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    if (access == null || refresh == null) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
