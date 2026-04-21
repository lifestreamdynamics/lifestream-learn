import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/user.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

Map<String, dynamic> _userJson({
  String displayName = 'Test User',
  String? avatarKey,
  bool useGravatar = false,
  Map<String, dynamic>? preferences,
}) =>
    <String, dynamic>{
      'id': 'u1',
      'email': 'u@example.local',
      'displayName': displayName,
      'role': 'LEARNER',
      'createdAt': '2026-04-01T00:00:00.000Z',
      'avatarKey': avatarKey,
      'useGravatar': useGravatar,
      'preferences': preferences,
    };

void main() {
  group('MeRepository.patchMe', () {
    test('sends only non-null fields', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueJson(_userJson(displayName: 'New Name'));

      final user = await repo.patchMe(displayName: 'New Name');
      expect(user.displayName, 'New Name');
      expect(user.role, UserRole.learner);
      final req = adapter.requestLog.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/me');
      expect((req.data as Map).containsKey('displayName'), isTrue);
      expect((req.data as Map).containsKey('useGravatar'), isFalse);
      expect((req.data as Map).containsKey('preferences'), isFalse);
    });

    test('propagates useGravatar + preferences', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueJson(_userJson(
        useGravatar: true,
        preferences: {'theme': 'dark'},
      ));

      final user = await repo.patchMe(
        useGravatar: true,
        preferences: {'theme': 'dark'},
      );
      expect(user.useGravatar, true);
      expect(user.preferences, {'theme': 'dark'});
      final req = adapter.requestLog.single;
      expect((req.data as Map)['useGravatar'], true);
      expect((req.data as Map)['preferences'], {'theme': 'dark'});
    });

    test('400 from server surfaces as ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueError(400, <String, dynamic>{
        'error': 'VALIDATION_ERROR',
        'message': 'Display name too long',
      });

      expect(
        repo.patchMe(displayName: 'x' * 81),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
      );
    });
  });

  group('MeRepository.uploadAvatar', () {
    test('posts raw bytes with content-type and refetches /api/auth/me',
        () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      // First response: the upload endpoint returns `{avatarKey, avatarUrl}`.
      adapter.enqueueJson(<String, dynamic>{
        'avatarKey': 'avatars/u1/xyz.png',
        'avatarUrl': null,
      });
      // Second response: the /api/auth/me refetch.
      adapter.enqueueJson(_userJson(avatarKey: 'avatars/u1/xyz.png'));

      final bytes = Uint8List.fromList(List<int>.filled(16, 0x89));
      final user = await repo.uploadAvatar(bytes, 'image/png');

      expect(user.avatarKey, 'avatars/u1/xyz.png');
      expect(adapter.requestLog, hasLength(2));
      expect(adapter.requestLog.first.path, '/api/me/avatar');
      expect(adapter.requestLog.first.contentType, 'image/png');
      expect(adapter.requestLog.last.path, '/api/auth/me');
    });

    test('413 response from server surfaces as ApiException(413)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueError(413, <String, dynamic>{
        'error': 'PAYLOAD_TOO_LARGE',
        'message': 'Avatar exceeds 2 MB limit',
      });

      final bytes = Uint8List.fromList(List<int>.filled(10, 1));
      expect(
        repo.uploadAvatar(bytes, 'image/jpeg'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 413)),
      );
    });
  });

  group('MeRepository.changePassword (Slice P5)', () {
    test('POSTs {currentPassword,newPassword} to /api/me/password', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueEmpty204();

      await repo.changePassword(
        currentPassword: 'CurrentPass1234',
        newPassword: 'BrandNewPass5678',
      );

      final req = adapter.requestLog.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/me/password');
      expect((req.data as Map)['currentPassword'], 'CurrentPass1234');
      expect((req.data as Map)['newPassword'], 'BrandNewPass5678');
    });

    test('401 surfaces as ApiException(UNAUTHORIZED, 401)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueError(401, <String, dynamic>{
        'error': 'UNAUTHORIZED',
        'message': 'Current password is incorrect',
      });

      await expectLater(
        repo.changePassword(
          currentPassword: 'wrong',
          newPassword: 'BrandNewPass5678',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 401)
            .having((e) => e.code, 'code', 'UNAUTHORIZED')),
      );
    });

    test('429 surfaces as ApiException(RATE_LIMITED, 429)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueError(429, <String, dynamic>{
        'error': 'RATE_LIMITED',
        'message': 'Too many password-change attempts',
      });

      await expectLater(
        repo.changePassword(
          currentPassword: 'any',
          newPassword: 'BrandNewPass5678',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 429)),
      );
    });
  });

  group('MeRepository.deleteAccount (Slice P5)', () {
    test('DELETEs /api/me with currentPassword body', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueEmpty204();

      await repo.deleteAccount(currentPassword: 'CurrentPass1234');

      final req = adapter.requestLog.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/me');
      expect((req.data as Map)['currentPassword'], 'CurrentPass1234');
    });

    test('401 surfaces as ApiException(401)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueError(401, <String, dynamic>{
        'error': 'UNAUTHORIZED',
        'message': 'Current password is incorrect',
      });

      await expectLater(
        repo.deleteAccount(currentPassword: 'wrong'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 401)),
      );
    });
  });

  // -------- Slice P6 — sessions --------

  group('MeRepository.listSessions (Slice P6)', () {
    test('GETs /api/me/sessions and decodes the JSON list', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueJson(<dynamic>[
        <String, dynamic>{
          'id': 's1',
          'deviceLabel': 'Android',
          'ipHashPrefix': 'deadbeef',
          'createdAt': '2026-04-01T00:00:00.000Z',
          'lastSeenAt': '2026-04-20T00:00:00.000Z',
          'current': true,
        },
        <String, dynamic>{
          'id': 's2',
          'deviceLabel': 'macOS',
          'ipHashPrefix': 'feedface',
          'createdAt': '2026-04-15T00:00:00.000Z',
          'lastSeenAt': '2026-04-19T00:00:00.000Z',
          'current': false,
        },
      ]);

      final sessions = await repo.listSessions();
      expect(sessions, hasLength(2));
      expect(sessions[0].id, 's1');
      expect(sessions[0].deviceLabel, 'Android');
      expect(sessions[0].current, isTrue);
      expect(sessions[1].current, isFalse);

      final req = adapter.requestLog.single;
      expect(req.method, 'GET');
      expect(req.path, '/api/me/sessions');
    });

    test('401 surfaces as ApiException(401)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueError(401, <String, dynamic>{
        'error': 'UNAUTHORIZED',
        'message': 'Not authenticated',
      });

      await expectLater(
        repo.listSessions(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });
  });

  group('MeRepository.revokeSession (Slice P6)', () {
    test('DELETEs /api/me/sessions/:id', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueEmpty204();

      await repo.revokeSession('s1');

      final req = adapter.requestLog.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/me/sessions/s1');
    });

    test('404 surfaces as ApiException(404)', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueError(404, <String, dynamic>{
        'error': 'NOT_FOUND',
        'message': 'Session not found',
      });

      await expectLater(
        repo.revokeSession('missing'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('MeRepository.revokeAllOtherSessions (Slice P6)', () {
    test('DELETEs /api/me/sessions', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueEmpty204();

      await repo.revokeAllOtherSessions();

      final req = adapter.requestLog.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/me/sessions');
    });
  });

  // -------- Slice P8 — personal-data export --------

  group('MeRepository.exportMyData (Slice P8)', () {
    test('GETs /api/me/export and returns the parsed JSON map', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      final payload = <String, dynamic>{
        'schemaVersion': 1,
        'exportedAt': '2026-04-20T00:00:00.000Z',
        'user': <String, dynamic>{'id': 'u1', 'email': 'u@example.local'},
        'enrollments': <dynamic>[],
        'attempts': <dynamic>[],
        'analyticsEvents': <dynamic>[],
        'analyticsEventsTruncated': false,
        'achievements': <dynamic>[],
        'sessions': <dynamic>[],
        'ownedCoursesCount': 0,
        'collaboratorCoursesCount': 0,
      };
      adapter.enqueueJson(payload);

      final result = await repo.exportMyData();
      expect(result['schemaVersion'], 1);
      expect(result['user'], isA<Map<String, dynamic>>());
      expect(result['analyticsEventsTruncated'], false);

      final req = adapter.requestLog.single;
      expect(req.method, 'GET');
      expect(req.path, '/api/me/export');
    });

    test(
        '429 raises ExportRateLimitException with retry-after header parsed',
        () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueJson(
        <String, dynamic>{
          'error': 'RATE_LIMITED',
          'message': 'You can export your data once per 24 hours',
        },
        statusCode: 429,
        headers: <String, List<String>>{
          'retry-after': ['86400'],
        },
      );

      await expectLater(
        repo.exportMyData(),
        throwsA(
          isA<ExportRateLimitException>()
              .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 86400),
        ),
      );
    });

    test(
        '429 without retry-after header still raises ExportRateLimitException',
        () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueJson(
        <String, dynamic>{
          'error': 'RATE_LIMITED',
          'message': 'Too many',
        },
        statusCode: 429,
      );

      await expectLater(
        repo.exportMyData(),
        throwsA(
          isA<ExportRateLimitException>()
              .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', isNull),
        ),
      );
    });

    test('403 (deleted account) surfaces as a regular ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueJson(
        <String, dynamic>{
          'error': 'ACCOUNT_DELETED',
          'message': 'Account is pending deletion',
        },
        statusCode: 403,
      );

      await expectLater(
        repo.exportMyData(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    });

    test('401 surfaces as a regular ApiException', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = MeRepository(dio);
      adapter.enqueueError(401, <String, dynamic>{
        'error': 'UNAUTHORIZED',
        'message': 'Not authenticated',
      });

      await expectLater(
        repo.exportMyData(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });
  });
}
