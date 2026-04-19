import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/cue.dart';

/// Wraps the cue CRUD endpoints exposed by the learn-api:
/// - `GET /api/videos/:id/cues`
/// - `POST /api/videos/:id/cues`
/// - `PATCH /api/cues/:id`
/// - `DELETE /api/cues/:id`
///
/// The backend returns cues ordered by `atMs asc` from the list endpoint;
/// we keep that invariant so the `CueScheduler` can assume sorted input.
class CueRepository {
  CueRepository(this._dio);

  final Dio _dio;

  Future<List<Cue>> listForVideo(String videoId) async {
    try {
      final response =
          await _dio.get<List<dynamic>>('/api/videos/$videoId/cues');
      final data = response.data ?? <dynamic>[];
      return data
          .map((e) => Cue.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Create a cue on a video. Mirrors the backend's create body shape:
  /// `{atMs, pause?, type, payload, orderIndex?}`.
  Future<Cue> create(
    String videoId, {
    required int atMs,
    required CueType type,
    required Map<String, dynamic> payload,
    bool pause = true,
    int? orderIndex,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/videos/$videoId/cues',
        data: <String, dynamic>{
          'atMs': atMs,
          'pause': pause,
          'type': _cueTypeToJson(type),
          'payload': payload,
          if (orderIndex != null) 'orderIndex': orderIndex,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty cue create response',
        );
      }
      return Cue.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// PATCH a cue. Type cannot change — the backend 400s if you try.
  /// Pass only the fields you're patching.
  Future<Cue> update(String cueId, Map<String, dynamic> patch) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/cues/$cueId',
        data: patch,
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty cue update response',
        );
      }
      return Cue.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> delete(String cueId) async {
    try {
      await _dio.delete<void>('/api/cues/$cueId');
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  ApiException _unwrap(DioException e) {
    final err = e.error;
    if (err is ApiException) return err;
    return ApiException(
      code: 'NETWORK_ERROR',
      statusCode: e.response?.statusCode ?? 0,
      message: e.message ?? 'Network error',
    );
  }
}

/// Serialise [CueType] to the wire enum value the backend expects.
/// Mirrors the `@JsonValue` tags on the enum; extracted so the wire
/// format is a single source of truth for both read (freezed fromJson)
/// and write (this repo) paths.
String _cueTypeToJson(CueType t) {
  switch (t) {
    case CueType.mcq:
      return 'MCQ';
    case CueType.blanks:
      return 'BLANKS';
    case CueType.matching:
      return 'MATCHING';
    case CueType.voice:
      return 'VOICE';
  }
}
