import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/course.dart';
import '../models/enrollment.dart';

/// Wraps the `/api/courses` and `/api/enrollments` endpoints the learner UI
/// talks to in Slice D (browse published courses, view detail, enroll, list
/// own enrollments).
class CourseRepository {
  CourseRepository(this._dio);

  final Dio _dio;

  /// Paginated list of published courses. Anonymous-safe on the server, but
  /// we still send the bearer header (via the interceptor) so an admin/
  /// designer can see everything they're entitled to while on the browse
  /// tab. `published=true` keeps the list learner-relevant.
  Future<CoursePage> published({String? cursor, int limit = 20}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/courses',
        queryParameters: <String, dynamic>{
          'limit': limit,
          'published': true,
          if (cursor != null) 'cursor': cursor,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty course list response',
        );
      }
      return CoursePage.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Idempotent: `POST /api/enrollments` returns 201 on first enroll, 200
  /// if the learner was already enrolled. Either way the body is the
  /// `Enrollment` row so we can render "Enrolled" immediately.
  Future<Enrollment> enroll(String courseId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/enrollments',
        data: <String, String>{'courseId': courseId},
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty enroll response',
        );
      }
      return Enrollment.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// The caller's own enrollments, newest first. Used by the "My Courses"
  /// tab. Server returns an array, not a paginated envelope.
  Future<List<EnrollmentWithCourse>> myEnrollments() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/enrollments');
      final data = response.data ?? <dynamic>[];
      return data
          .map((e) => EnrollmentWithCourse.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Course metadata + its videos. `/api/courses/:id` is public for
  /// published courses; our Dio still attaches a bearer so designers see
  /// their own unpublished work too.
  Future<CourseDetail> getById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/courses/$id');
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty course response',
        );
      }
      return CourseDetail.fromJson(data);
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
