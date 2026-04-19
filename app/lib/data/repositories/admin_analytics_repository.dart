import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/course_analytics.dart';

/// Admin-only analytics aggregates. Thin wrapper over
/// `GET /api/admin/analytics/courses/:id`.
class AdminAnalyticsRepository {
  AdminAnalyticsRepository(this._dio);

  final Dio _dio;

  Future<CourseAnalytics> course(String courseId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/admin/analytics/courses/$courseId',
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty course analytics response',
        );
      }
      return CourseAnalytics.fromJson(data);
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
