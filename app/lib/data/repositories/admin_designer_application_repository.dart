import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/designer_application.dart';

/// Admin-only repository for reviewing designer applications.
///
/// The backend router gates `/api/admin/*` at `requireRole(ADMIN)`, so
/// non-admins just get 403 — but keeping this repository separate from
/// the learner-facing one makes the call sites self-documenting and
/// makes it easier to lint later (e.g. tree-shake admin bits from a
/// non-admin build).
class AdminDesignerApplicationRepository {
  AdminDesignerApplicationRepository(this._dio);

  final Dio _dio;

  /// `GET /api/admin/designer-applications?status=&cursor=&limit=`.
  Future<DesignerApplicationPage> list({
    String? status,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/admin/designer-applications',
        queryParameters: <String, dynamic>{
          'limit': limit,
          if (status != null) 'status': status,
          if (cursor != null) 'cursor': cursor,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty admin designer-applications response',
        );
      }
      return DesignerApplicationPage.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// `PATCH /api/admin/designer-applications/:id` — approve/reject.
  /// Approve atomically flips the applicant's role LEARNER →
  /// COURSE_DESIGNER on the backend. The reviewer note is optional.
  Future<DesignerApplication> review(
    String id, {
    required AppStatus status,
    String? reviewerNote,
  }) async {
    if (status == AppStatus.pending) {
      // Safeguard: sending `status: 'PENDING'` in a review call is a
      // programming error — the backend zod schema only allows APPROVED
      // or REJECTED and would return 400.
      throw ArgumentError('review status must be APPROVED or REJECTED');
    }
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/admin/designer-applications/$id',
        data: <String, dynamic>{
          'status': status == AppStatus.approved ? 'APPROVED' : 'REJECTED',
          if (reviewerNote != null && reviewerNote.isNotEmpty)
            'reviewerNote': reviewerNote,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty admin review response',
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
