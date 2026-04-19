// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FeedEntryImpl _$$FeedEntryImplFromJson(Map<String, dynamic> json) =>
    _$FeedEntryImpl(
      video: VideoSummary.fromJson(json['video'] as Map<String, dynamic>),
      course: CourseSummary.fromJson(json['course'] as Map<String, dynamic>),
      cueCount: (json['cueCount'] as num).toInt(),
      hasAttempted: json['hasAttempted'] as bool,
    );

Map<String, dynamic> _$$FeedEntryImplToJson(_$FeedEntryImpl instance) =>
    <String, dynamic>{
      'video': instance.video,
      'course': instance.course,
      'cueCount': instance.cueCount,
      'hasAttempted': instance.hasAttempted,
    };

_$FeedPageImpl _$$FeedPageImplFromJson(Map<String, dynamic> json) =>
    _$FeedPageImpl(
      items: (json['items'] as List<dynamic>)
          .map((e) => FeedEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool,
    );

Map<String, dynamic> _$$FeedPageImplToJson(_$FeedPageImpl instance) =>
    <String, dynamic>{
      'items': instance.items,
      'nextCursor': instance.nextCursor,
      'hasMore': instance.hasMore,
    };
