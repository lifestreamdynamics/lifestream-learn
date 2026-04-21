// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caption.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CaptionSummaryImpl _$$CaptionSummaryImplFromJson(Map<String, dynamic> json) =>
    _$CaptionSummaryImpl(
      language: json['language'] as String,
      bytes: (json['bytes'] as num).toInt(),
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );

Map<String, dynamic> _$$CaptionSummaryImplToJson(
  _$CaptionSummaryImpl instance,
) => <String, dynamic>{
  'language': instance.language,
  'bytes': instance.bytes,
  'uploadedAt': instance.uploadedAt.toIso8601String(),
};

_$CaptionUploadResultImpl _$$CaptionUploadResultImplFromJson(
  Map<String, dynamic> json,
) => _$CaptionUploadResultImpl(
  language: json['language'] as String,
  bytes: (json['bytes'] as num).toInt(),
  uploadedAt: DateTime.parse(json['uploadedAt'] as String),
);

Map<String, dynamic> _$$CaptionUploadResultImplToJson(
  _$CaptionUploadResultImpl instance,
) => <String, dynamic>{
  'language': instance.language,
  'bytes': instance.bytes,
  'uploadedAt': instance.uploadedAt.toIso8601String(),
};
