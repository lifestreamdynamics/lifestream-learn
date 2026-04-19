// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CueImpl _$$CueImplFromJson(Map<String, dynamic> json) => _$CueImpl(
  id: json['id'] as String,
  videoId: json['videoId'] as String,
  atMs: (json['atMs'] as num).toInt(),
  pause: json['pause'] as bool,
  type: $enumDecode(_$CueTypeEnumMap, json['type']),
  payload: json['payload'] as Map<String, dynamic>,
  orderIndex: (json['orderIndex'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$CueImplToJson(_$CueImpl instance) => <String, dynamic>{
  'id': instance.id,
  'videoId': instance.videoId,
  'atMs': instance.atMs,
  'pause': instance.pause,
  'type': _$CueTypeEnumMap[instance.type]!,
  'payload': instance.payload,
  'orderIndex': instance.orderIndex,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$CueTypeEnumMap = {
  CueType.mcq: 'MCQ',
  CueType.blanks: 'BLANKS',
  CueType.matching: 'MATCHING',
  CueType.voice: 'VOICE',
};

_$AttemptImpl _$$AttemptImplFromJson(Map<String, dynamic> json) =>
    _$AttemptImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      videoId: json['videoId'] as String,
      cueId: json['cueId'] as String,
      correct: json['correct'] as bool,
      scoreJson: json['scoreJson'] as Map<String, dynamic>?,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
    );

Map<String, dynamic> _$$AttemptImplToJson(_$AttemptImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'videoId': instance.videoId,
      'cueId': instance.cueId,
      'correct': instance.correct,
      'scoreJson': instance.scoreJson,
      'submittedAt': instance.submittedAt.toIso8601String(),
    };

_$AttemptResultImpl _$$AttemptResultImplFromJson(Map<String, dynamic> json) =>
    _$AttemptResultImpl(
      attempt: Attempt.fromJson(json['attempt'] as Map<String, dynamic>),
      correct: json['correct'] as bool,
      scoreJson: json['scoreJson'] as Map<String, dynamic>?,
      explanation: json['explanation'] as String?,
    );

Map<String, dynamic> _$$AttemptResultImplToJson(_$AttemptResultImpl instance) =>
    <String, dynamic>{
      'attempt': instance.attempt,
      'correct': instance.correct,
      'scoreJson': instance.scoreJson,
      'explanation': instance.explanation,
    };
