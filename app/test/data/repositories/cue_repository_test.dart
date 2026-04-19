import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/http/error_envelope.dart';
import 'package:lifestream_learn_app/data/models/cue.dart';
import 'package:lifestream_learn_app/data/repositories/cue_repository.dart';

import '../../test_support/fake_dio_adapter.dart';

Map<String, dynamic> _cueJson({
  String id = 'c1',
  String videoId = 'v1',
  int atMs = 1000,
  String type = 'MCQ',
  Map<String, dynamic>? payload,
}) =>
    <String, dynamic>{
      'id': id,
      'videoId': videoId,
      'atMs': atMs,
      'pause': true,
      'type': type,
      'payload': payload ??
          <String, dynamic>{
            'type': 'MCQ',
            'question': 'Q?',
            'choices': ['A', 'B'],
            'answerIndex': 0,
          },
      'orderIndex': 0,
      'createdAt': '2026-04-19T00:00:00.000Z',
      'updatedAt': '2026-04-19T00:00:00.000Z',
    };

void main() {
  group('CueRepository', () {
    test('listForVideo returns parsed cues sorted as server returned', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CueRepository(dio);

      adapter.enqueueJson([
        _cueJson(id: 'c1', atMs: 1000),
        _cueJson(id: 'c2', atMs: 3000),
      ]);

      final cues = await repo.listForVideo('v1');
      expect(cues, hasLength(2));
      expect(cues[0].id, 'c1');
      expect(cues[0].type, CueType.mcq);
      expect(cues[1].atMs, 3000);
      expect(adapter.requestLog.single.path, '/api/videos/v1/cues');
    });

    test('create POSTs atMs+type+payload and decodes the returned cue',
        () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CueRepository(dio);

      adapter.enqueueJson(_cueJson(id: 'new', atMs: 4200), statusCode: 201);

      final created = await repo.create(
        'v1',
        atMs: 4200,
        type: CueType.mcq,
        payload: {
          'question': 'Q?',
          'choices': ['A', 'B'],
          'answerIndex': 1,
        },
      );
      expect(created.id, 'new');
      expect(adapter.requestLog.single.method, 'POST');
      expect(adapter.requestLog.single.path, '/api/videos/v1/cues');
      final data = adapter.requestLog.single.data as Map<String, dynamic>;
      expect(data['atMs'], 4200);
      expect(data['type'], 'MCQ');
      expect(data['pause'], true);
    });

    test('update PATCHes the payload and returns the updated cue', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CueRepository(dio);

      adapter.enqueueJson(_cueJson(id: 'c1', atMs: 1500));
      final updated =
          await repo.update('c1', <String, dynamic>{'atMs': 1500});
      expect(updated.atMs, 1500);
      expect(adapter.requestLog.single.method, 'PATCH');
      expect(adapter.requestLog.single.path, '/api/cues/c1');
    });

    test('delete sends DELETE and expects 204', () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CueRepository(dio);

      adapter.enqueueEmpty204();
      await repo.delete('c1');
      expect(adapter.requestLog.single.method, 'DELETE');
      expect(adapter.requestLog.single.path, '/api/cues/c1');
    });

    test('400 response surfaces ApiException via the envelope interceptor',
        () async {
      final adapter = FakeDioAdapter();
      final dio = buildTestDio(adapter);
      final repo = CueRepository(dio);

      adapter.enqueueError(400, <String, dynamic>{
        'error': 'VALIDATION_ERROR',
        'message': 'answerIndex must be a valid index into choices',
      });
      await expectLater(
        repo.create(
          'v1',
          atMs: 0,
          type: CueType.mcq,
          payload: {
            'question': 'Q?',
            'choices': ['A'],
            'answerIndex': 5,
          },
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION_ERROR')
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });
}
