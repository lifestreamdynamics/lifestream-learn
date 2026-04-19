import 'package:dio/dio.dart';

import '../../core/analytics/analytics_event.dart';
import '../../core/http/error_envelope.dart';

/// Wraps `POST /api/events`. A typed thin repository so the analytics
/// buffer can be unit-tested by swapping this for a fake, without
/// pulling Dio into every test.
///
/// The repository propagates errors — it does NOT swallow them. The
/// buffer is the component that decides whether to retry, drop, or
/// surface.
class EventsRepository {
  EventsRepository(this._dio);

  final Dio _dio;

  /// POST a batch of 1..100 analytics events.
  /// - 2xx → returns normally.
  /// - 4xx → throws `ApiException(statusCode: 4xx)` (buffer drops batch).
  /// - 5xx / network → throws `ApiException` (buffer schedules retry).
  Future<void> submitBatch(List<AnalyticsEvent> events) async {
    if (events.isEmpty) return;
    try {
      await _dio.post<dynamic>(
        '/api/events',
        data: events.map((e) => e.toJson()).toList(growable: false),
      );
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is ApiException) {
        throw inner;
      }
      throw ApiException(
        code: 'NETWORK_ERROR',
        statusCode: e.response?.statusCode ?? 0,
        message: e.message ?? 'Network error',
      );
    }
  }
}
