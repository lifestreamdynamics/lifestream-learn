import 'package:dio/dio.dart';

import '../../core/http/error_envelope.dart';
import '../models/feed_entry.dart';

/// Thin wrapper around `GET /api/feed`. Paginated with an opaque cursor the
/// server hands back verbatim.
class FeedRepository {
  FeedRepository(this._dio);

  final Dio _dio;

  /// Fetch one page. Default limit matches the server default (20).
  /// Max limit per server config is 50 — we leave validation to the server.
  Future<FeedPage> page({String? cursor, int limit = 20}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/feed',
        queryParameters: <String, dynamic>{
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 0,
          message: 'Empty feed response',
        );
      }
      return FeedPage.fromJson(data);
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
