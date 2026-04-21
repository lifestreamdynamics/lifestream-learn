import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/auth/auth_tokens.dart';
import 'package:lifestream_learn_app/core/auth/biometric_gate.dart';
import 'package:lifestream_learn_app/core/auth/token_store.dart';
import 'package:lifestream_learn_app/core/settings/settings_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalAuth extends Mock implements LocalAuthentication {}

class _MemoryStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _map = <String, String>{};
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      _map.containsKey(key);
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _map.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _map.clear();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      _map[key];
  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async {
    return Map<String, String>.from(_map);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _map[key] = value;
  }
}

class _FakeAuthOptions extends Fake implements AuthenticationOptions {}

void main() {
  setUpAll(() {
    FlutterSecureStoragePlatform.instance = _MemoryStorage();
    registerFallbackValue(_FakeAuthOptions());
  });

  late FlutterSecureStorage storage;
  late SettingsStore settingsStore;
  late TokenStore tokenStore;
  late _MockLocalAuth localAuth;

  setUp(() async {
    FlutterSecureStoragePlatform.instance = _MemoryStorage();
    storage = const FlutterSecureStorage();
    settingsStore = SettingsStore(storage);
    tokenStore = TokenStore(storage);
    localAuth = _MockLocalAuth();
  });

  test('no-op when biometric unlock preference is off', () async {
    await settingsStore.writeBiometricUnlock(false);
    await tokenStore.save(const AuthTokens(accessToken: 'a', refreshToken: 'r'));

    final gate = BiometricGate(
      settingsStore: settingsStore,
      tokenStore: tokenStore,
      localAuth: localAuth,
    );
    expect(await gate.run(), isTrue);
    verifyNever(() => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        ));
  });

  test('no-op when no tokens are stored even with preference on', () async {
    await settingsStore.writeBiometricUnlock(true);
    await tokenStore.clear();
    final gate = BiometricGate(
      settingsStore: settingsStore,
      tokenStore: tokenStore,
      localAuth: localAuth,
    );
    expect(await gate.run(), isTrue);
    verifyNever(() => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        ));
  });

  test('returns true + preserves tokens on successful biometric prompt',
      () async {
    await settingsStore.writeBiometricUnlock(true);
    await tokenStore.save(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    when(() => localAuth.canCheckBiometrics).thenAnswer((_) async => true);
    when(() => localAuth.isDeviceSupported()).thenAnswer((_) async => true);
    when(() => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => true);

    final gate = BiometricGate(
      settingsStore: settingsStore,
      tokenStore: tokenStore,
      localAuth: localAuth,
    );
    expect(await gate.run(), isTrue);
    expect(await tokenStore.read(), isNotNull);
  });

  test('failed biometric clears the token store and returns false',
      () async {
    await settingsStore.writeBiometricUnlock(true);
    await tokenStore.save(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    when(() => localAuth.canCheckBiometrics).thenAnswer((_) async => true);
    when(() => localAuth.isDeviceSupported()).thenAnswer((_) async => true);
    when(() => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => false);

    final gate = BiometricGate(
      settingsStore: settingsStore,
      tokenStore: tokenStore,
      localAuth: localAuth,
    );
    expect(await gate.run(), isFalse);
    expect(await tokenStore.read(), isNull);
  });

  test('PlatformException during canCheckBiometrics falls through to true',
      () async {
    await settingsStore.writeBiometricUnlock(true);
    await tokenStore.save(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    when(() => localAuth.canCheckBiometrics).thenThrow(
      PlatformException(code: 'NotAvailable'),
    );
    final gate = BiometricGate(
      settingsStore: settingsStore,
      tokenStore: tokenStore,
      localAuth: localAuth,
    );
    expect(await gate.run(), isTrue);
    expect(await tokenStore.read(), isNotNull);
  });
}
