import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/cue.dart';

/// Submit cue responses and retrieve grading results.
///
/// **Grading is authoritative on the server.** The client never computes
/// a `correct` flag — it only renders what the server returns. The
/// server also never echoes the cue's secret fields (e.g. MCQ
/// `answerIndex`, MATCHING `pairs`), so a compromised client cannot
/// extract answers by inspecting attempt responses.
class AttemptRepository {
  AttemptRepository(this._dio);

  final Dio _dio;

  /// Submit a response for a cue. The response shape is per-type:
  /// - MCQ: `{choiceIndex: int}`
  /// - BLANKS: `{answers: List<String>}`
  /// - MATCHING: `{userPairs: List<List<int>>}`  (each inner pair is `[leftIdx, rightIdx]`)
  ///
  /// Throws `ApiException` on validation (400) or access (403) errors.
  Future<AttemptResult> submit({
    required String cueId,
    required Map<String, dynamic> response,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/attempts',
        data: <String, dynamic>{
          'cueId': cueId,
          'response': response,
        },
      );
      final data = res.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty attempt response',
        );
      }
      return AttemptResult.fromJson(data);
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
