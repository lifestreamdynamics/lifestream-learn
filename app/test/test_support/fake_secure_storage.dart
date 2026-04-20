import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// In-memory `FlutterSecureStoragePlatform` substitute for unit tests.
///
/// Use by assigning `FlutterSecureStoragePlatform.instance = <fake>` in
/// `setUp()`. The same pattern exists inline in
/// `test/core/auth/token_store_test.dart`; this file lifts it so
/// multiple stores (token, crash) can share it.
class FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> data = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    data.clear();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      data[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map<String, String>.from(data);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    data[key] = value;
  }
}
