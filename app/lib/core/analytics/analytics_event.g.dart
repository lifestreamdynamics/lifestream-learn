// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnalyticsEventImpl _$$AnalyticsEventImplFromJson(Map<String, dynamic> json) =>
    _$AnalyticsEventImpl(
      eventType: json['eventType'] as String,
      occurredAt: json['occurredAt'] as String,
      videoId: json['videoId'] as String?,
      cueId: json['cueId'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$AnalyticsEventImplToJson(
  _$AnalyticsEventImpl instance,
) => <String, dynamic>{
  'eventType': instance.eventType,
  'occurredAt': instance.occurredAt,
  if (instance.videoId case final value?) 'videoId': value,
  if (instance.cueId case final value?) 'cueId': value,
  if (instance.payload case final value?) 'payload': value,
};
