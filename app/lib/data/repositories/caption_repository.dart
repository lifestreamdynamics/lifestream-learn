import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/caption.dart';

/// Manages caption tracks for a video. Mirrors the raw-body upload
/// pattern from [MeRepository.uploadAvatar].
class CaptionRepository {
  CaptionRepository(this._dio);

  final Dio _dio;

  /// Upload a raw VTT or SRT file.
  ///
  /// `contentType` must be `text/vtt` or `application/x-subrip`.
  /// The body is sent verbatim — no JSON wrapping, no multipart.
  Future<CaptionUploadResult> upload({
    required String videoId,
    required String language,
    required Uint8List bytes,
    required String contentType,
    bool setDefault = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/videos/$videoId/captions',
        data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        queryParameters: <String, dynamic>{
          'language': language,
          if (setDefault) 'setDefault': '1',
        },
        options: Options(
          contentType: contentType,
          headers: <String, dynamic>{
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty caption upload response',
        );
      }
      return CaptionUploadResult.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// List uploaded caption tracks for a video.
  Future<List<CaptionSummary>> list(String videoId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/videos/$videoId/captions',
      );
      final raw = response.data?['captions'];
      if (raw is! List) return const <CaptionSummary>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(CaptionSummary.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Delete a caption track by BCP-47 language code.
  Future<void> delete({
    required String videoId,
    required String language,
  }) async {
    try {
      await _dio.delete<void>('/api/videos/$videoId/captions/$language');
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
