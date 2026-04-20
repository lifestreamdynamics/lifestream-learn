import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/crash/secure_storage_backend.dart';

import '../../test_support/fake_secure_storage.dart';

void main() {
  late FakeSecureStoragePlatform fake;
  late SecureStorageBackend backend;

  setUp(() {
    fake = FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = fake;
    backend = SecureStorageBackend(const FlutterSecureStorage());
  });

  test('set then get round-trips', () async {
    await backend.setItem('queue', 'payload');
    expect(await backend.getItem('queue'), 'payload');
  });

  test('get returns null for missing key', () async {
    expect(await backend.getItem('missing'), isNull);
  });

  test('remove clears the key', () async {
    await backend.setItem('queue', 'payload');
    await backend.removeItem('queue');
    expect(await backend.getItem('queue'), isNull);
  });

  test('crash.* namespace does not collide with auth.* keys', () async {
    // Simulate an auth token already in storage.
    fake.data['auth.access'] = 'token-xyz';
    await backend.setItem('access', 'queue-payload');

    // Backend read of 'access' returns its own namespaced value, not
    // the auth token.
    expect(await backend.getItem('access'), 'queue-payload');

    // Removing via the backend does not touch the auth entry.
    await backend.removeItem('access');
    expect(fake.data['auth.access'], 'token-xyz');
  });

  test('writes land under the crash. prefix', () async {
    await backend.setItem('q', 'v');
    expect(fake.data.keys, contains('crash.q'));
    expect(fake.data.keys, isNot(contains('q')));
  });
}
