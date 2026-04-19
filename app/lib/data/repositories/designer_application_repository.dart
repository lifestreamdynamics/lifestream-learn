import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/designer_application.dart';

/// Learner-facing read/write for the caller's own designer application.
///
/// Admin-facing endpoints (list + review) live on
/// `AdminDesignerApplicationRepository`; kept separate so a learner build
/// that's stripped of admin routes can't accidentally hit them.
class DesignerApplicationRepository {
  DesignerApplicationRepository(this._dio);

  final Dio _dio;

  /// `GET /api/designer-applications/me` — returns the caller's own row
  /// or `null` when they've never applied. 404 is the "hasn't applied"
  /// signal; we map it to `null` rather than surfacing it as an error so
  /// the screen's state machine stays boring (null → show the form).
  Future<DesignerApplication?> getMy() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/designer-applications/me',
      );
      final data = response.data;
      if (data == null) return null;
      return DesignerApplication.fromJson(data);
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is ApiException && inner.statusCode == 404) {
        return null;
      }
      // Also handle the case where the envelope interceptor didn't produce
      // a typed ApiException (e.g. non-JSON body). A 404 in the raw
      // response is still "no application" — don't bubble it as an error.
      if (e.response?.statusCode == 404) return null;
      throw _unwrap(e);
    }
  }

  /// `POST /api/designer-applications` — submits (or resurrects a
  /// REJECTED row back to PENDING — the backend handles that
  /// transparently).
  Future<DesignerApplication> submit({String? note}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/designer-applications',
        data: <String, dynamic>{
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty designer-application response',
        );
      }
      return DesignerApplication.fromJson(data);
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
