import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';

import '../../core/http/error_envelope.dart';
import '../../data/models/video.dart';

/// Thin helper that fetches a signed WebVTT URL and returns a
/// `video_player`-compatible [ClosedCaptionFile].
///
/// Callers catch [ApiException] on failure, log it, and fall back to
/// no-captions — the video keeps playing regardless.
class CaptionLoader {
  CaptionLoader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Fetches the signed VTT file and returns a [WebVTTCaptionFile]
  /// suitable for `VideoPlayerController.setClosedCaptionFile`.
  ///
  /// Throws [ApiException] on HTTP failures or an empty response body.
  Future<ClosedCaptionFile> load(CaptionTrack track) async {
    try {
      final resp = await _dio.get<String>(
        track.url,
        options: Options(
          // Force response as UTF-8 text. Dio may otherwise misinterpret
          // the Content-Type for non-JSON content as binary.
          responseType: ResponseType.plain,
        ),
      );
      final body = resp.data;
      if (body == null || body.isEmpty) {
        throw const ApiException(
          code: 'EMPTY_CAPTION',
          statusCode: 0,
          message: 'Caption file was empty',
        );
      }
      return WebVTTCaptionFile(body);
    } on ApiException {
      rethrow;
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
      message: e.message ?? 'Caption fetch failed',
    );
  }
}
