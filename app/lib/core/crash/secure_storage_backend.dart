import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lifestream_doctor/lifestream_doctor.dart';

/// `StorageBackend` implementation backed by [FlutterSecureStorage].
///
/// The doctor SDK uses this for its offline queue (failed uploads) and
/// consent state. Keys are namespaced with a `crash.` prefix so they
/// don't collide with the auth store's `auth.access` / `auth.refresh`
/// entries on the same secure-storage instance.
///
/// The encrypted-at-rest guarantees come from the underlying
/// `FlutterSecureStorage` configuration at the instantiation site
/// (`main.dart` wires `AndroidOptions(encryptedSharedPreferences: true)`).
class SecureStorageBackend implements StorageBackend {
  SecureStorageBackend(this._storage);

  final FlutterSecureStorage _storage;

  static const String _prefix = 'crash.';

  @override
  Future<String?> getItem(String key) => _storage.read(key: '$_prefix$key');

  @override
  Future<void> setItem(String key, String value) =>
      _storage.write(key: '$_prefix$key', value: value);

  @override
  Future<void> removeItem(String key) =>
      _storage.delete(key: '$_prefix$key');
}
