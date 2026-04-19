// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VideoSummaryImpl _$$VideoSummaryImplFromJson(Map<String, dynamic> json) =>
    _$VideoSummaryImpl(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      title: json['title'] as String,
      orderIndex: (json['orderIndex'] as num).toInt(),
      status: $enumDecode(_$VideoStatusEnumMap, json['status']),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$VideoSummaryImplToJson(_$VideoSummaryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'courseId': instance.courseId,
      'title': instance.title,
      'orderIndex': instance.orderIndex,
      'status': _$VideoStatusEnumMap[instance.status]!,
      'durationMs': instance.durationMs,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$VideoStatusEnumMap = {
  VideoStatus.uploading: 'UPLOADING',
  VideoStatus.transcoding: 'TRANSCODING',
  VideoStatus.ready: 'READY',
  VideoStatus.failed: 'FAILED',
};

_$CourseVideoSummaryImpl _$$CourseVideoSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$CourseVideoSummaryImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  orderIndex: (json['orderIndex'] as num).toInt(),
  status: $enumDecode(_$VideoStatusEnumMap, json['status']),
  durationMs: (json['durationMs'] as num?)?.toInt(),
);

Map<String, dynamic> _$$CourseVideoSummaryImplToJson(
  _$CourseVideoSummaryImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'orderIndex': instance.orderIndex,
  'status': _$VideoStatusEnumMap[instance.status]!,
  'durationMs': instance.durationMs,
};

_$PlaybackInfoImpl _$$PlaybackInfoImplFromJson(Map<String, dynamic> json) =>
    _$PlaybackInfoImpl(
      masterPlaylistUrl: json['masterPlaylistUrl'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$$PlaybackInfoImplToJson(_$PlaybackInfoImpl instance) =>
    <String, dynamic>{
      'masterPlaylistUrl': instance.masterPlaylistUrl,
      'expiresAt': instance.expiresAt.toIso8601String(),
    };
