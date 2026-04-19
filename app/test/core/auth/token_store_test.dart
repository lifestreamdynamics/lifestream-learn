import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/auth/auth_tokens.dart';
import 'package:lifestream_learn_app/core/auth/token_store.dart';

/// In-memory implementation of the `FlutterSecureStoragePlatform` so the
/// `TokenStore` can run unit tests without a Method Channel.
class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _data = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      _data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _data.clear();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      _data[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map<String, String>.from(_data);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _data[key] = value;
  }
}

void main() {
  late _FakeSecureStoragePlatform fake;
  late TokenStore tokenStore;

  setUp(() {
    fake = _FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = fake;
    tokenStore = TokenStore(const FlutterSecureStorage());
  });

  test('save -> read returns the saved tokens', () async {
    const tokens = AuthTokens(accessToken: 'a1', refreshToken: 'r1');
    await tokenStore.save(tokens);
    expect(await tokenStore.read(), tokens);
  });

  test('read with both keys missing returns null', () async {
    expect(await tokenStore.read(), isNull);
  });

  test('read returns null when refresh is missing', () async {
    const tokens = AuthTokens(accessToken: 'a1', refreshToken: 'r1');
    await tokenStore.save(tokens);
    // Simulate a torn write: remove the refresh key out-of-band.
    fake._data.remove('auth.refresh');
    expect(await tokenStore.read(), isNull);
  });

  test('clear removes both keys', () async {
    const tokens = AuthTokens(accessToken: 'a1', refreshToken: 'r1');
    await tokenStore.save(tokens);
    await tokenStore.clear();
    expect(await tokenStore.read(), isNull);
  });
}
