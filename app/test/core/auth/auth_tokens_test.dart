import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/auth/auth_tokens.dart';

void main() {
  test('AuthTokens.fromJson round-trips', () {
    final json = <String, dynamic>{
      'accessToken': 'a',
      'refreshToken': 'r',
    };
    final tokens = AuthTokens.fromJson(json);
    expect(tokens.accessToken, 'a');
    expect(tokens.refreshToken, 'r');
    expect(tokens.toJson(), json);
  });

  test('AuthTokens equality', () {
    expect(
      const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    expect(
      const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      isNot(const AuthTokens(accessToken: 'a', refreshToken: 'x')),
    );
  });
}
