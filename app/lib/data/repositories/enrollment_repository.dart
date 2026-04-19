import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Progress-ping wrapper around `PATCH /api/enrollments/:courseId/progress`.
///
/// The player calls this every ~5s while playing, fire-and-forget. A
/// failed ping must NEVER surface to the learner or interrupt playback —
/// the whole point of a silent API is that a 500 or a dropped connection
/// is a no-op. Debouncing lives at the call site (the player) so that
/// seek-heavy workloads collapse into a single write.
class EnrollmentRepository {
  EnrollmentRepository(this._dio);

  final Dio _dio;

  /// Update last-watched position. Returns normally on both 2xx and error
  /// paths; errors are caught and swallowed (debug-logged in debug builds
  /// only — never prints the bearer or URL). The return type is `void`
  /// because the caller genuinely does not care.
  Future<void> updateProgress(
    String courseId,
    String videoId,
    int posMs,
  ) async {
    try {
      await _dio.patch<void>(
        '/api/enrollments/$courseId/progress',
        data: <String, dynamic>{
          'lastVideoId': videoId,
          'lastPosMs': posMs,
        },
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        // Safe: status + code only, no tokens, no URL.
        debugPrint(
          'EnrollmentRepository.updateProgress non-fatal: '
          '${e.response?.statusCode ?? 0} ${e.type}',
        );
      }
      // Swallow.
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnrollmentRepository.updateProgress non-fatal: $e');
      }
      // Swallow any other error too — progress pings are best-effort.
    }
  }
}
