// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SessionImpl _$$SessionImplFromJson(Map<String, dynamic> json) =>
    _$SessionImpl(
      id: json['id'] as String,
      deviceLabel: json['deviceLabel'] as String?,
      ipHashPrefix: json['ipHashPrefix'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
      current: json['current'] as bool? ?? false,
    );

Map<String, dynamic> _$$SessionImplToJson(_$SessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'deviceLabel': instance.deviceLabel,
      'ipHashPrefix': instance.ipHashPrefix,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastSeenAt': instance.lastSeenAt.toIso8601String(),
      'current': instance.current,
    };
