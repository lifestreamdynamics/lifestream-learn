// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CaptionTrackImpl _$$CaptionTrackImplFromJson(Map<String, dynamic> json) =>
    _$CaptionTrackImpl(
      language: json['language'] as String,
      url: json['url'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$$CaptionTrackImplToJson(_$CaptionTrackImpl instance) =>
    <String, dynamic>{
      'language': instance.language,
      'url': instance.url,
      'expiresAt': instance.expiresAt.toIso8601String(),
    };

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
      captions:
          (json['captions'] as List<dynamic>?)
              ?.map((e) => CaptionTrack.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <CaptionTrack>[],
      defaultCaptionLanguage: json['defaultCaptionLanguage'] as String?,
    );

Map<String, dynamic> _$$PlaybackInfoImplToJson(_$PlaybackInfoImpl instance) =>
    <String, dynamic>{
      'masterPlaylistUrl': instance.masterPlaylistUrl,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'captions': instance.captions,
      'defaultCaptionLanguage': instance.defaultCaptionLanguage,
    };

_$VideoUploadTicketImpl _$$VideoUploadTicketImplFromJson(
  Map<String, dynamic> json,
) => _$VideoUploadTicketImpl(
  videoId: json['videoId'] as String,
  video: VideoSummary.fromJson(json['video'] as Map<String, dynamic>),
  uploadUrl: json['uploadUrl'] as String,
  uploadHeaders: Map<String, String>.from(json['uploadHeaders'] as Map),
  sourceKey: json['sourceKey'] as String,
);

Map<String, dynamic> _$$VideoUploadTicketImplToJson(
  _$VideoUploadTicketImpl instance,
) => <String, dynamic>{
  'videoId': instance.videoId,
  'video': instance.video,
  'uploadUrl': instance.uploadUrl,
  'uploadHeaders': instance.uploadHeaders,
  'sourceKey': instance.sourceKey,
};
