import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/achievement.dart';
import '../models/progress.dart';

/// Slice P2 — progress aggregation endpoints live under `/api/me/progress`.
///
/// Methods are thin read-only wrappers. Error normalisation follows the
/// same `_unwrap(DioException) -> ApiException` idiom used by every other
/// repository in this app.
class ProgressRepository {
  ProgressRepository(this._dio);

  final Dio _dio;

  /// Overall progress dashboard: summary + per-course list. A fresh user
  /// with zero enrollments gets a summary-with-zeroes + empty perCourse.
  Future<OverallProgress> fetchOverall() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/me/progress',
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty /api/me/progress response',
        );
      }
      return OverallProgress.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Per-course detail (summary + lesson breakdown). Throws on 404 when
  /// the user is not enrolled in the course.
  Future<CourseProgressDetail> fetchCourse(String courseId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/me/progress/courses/$courseId',
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty course progress response',
        );
      }
      return CourseProgressDetail.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Per-lesson review (one `CueOutcome` per cue). The server never
  /// returns a `correctAnswerSummary` for unattempted cues — the
  /// invariant is load-bearing (security: pre-leaking the answer would
  /// defeat the cue engine).
  Future<LessonReview> fetchLesson(String videoId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/me/progress/lessons/$videoId',
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty lesson review response',
        );
      }
      return LessonReview.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Slice P3 — list the caller's achievement catalog split into
  /// unlocked + locked. Unlock *evaluation* happens server-side on
  /// `GET /api/me/progress` (pull-not-push) — this endpoint is a
  /// read of the current state for the achievement grid UI.
  Future<AchievementsResponse> fetchAchievements() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/me/achievements',
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty /api/me/achievements response',
        );
      }
      return AchievementsResponse.fromJson(data);
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
