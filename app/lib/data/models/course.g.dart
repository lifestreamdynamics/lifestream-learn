// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CourseImpl _$$CourseImplFromJson(Map<String, dynamic> json) => _$CourseImpl(
  id: json['id'] as String,
  slug: json['slug'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  coverImageUrl: json['coverImageUrl'] as String?,
  ownerId: json['ownerId'] as String,
  published: json['published'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$CourseImplToJson(_$CourseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'title': instance.title,
      'description': instance.description,
      'coverImageUrl': instance.coverImageUrl,
      'ownerId': instance.ownerId,
      'published': instance.published,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_$CourseDetailImpl _$$CourseDetailImplFromJson(Map<String, dynamic> json) =>
    _$CourseDetailImpl(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      coverImageUrl: json['coverImageUrl'] as String?,
      ownerId: json['ownerId'] as String,
      published: json['published'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      videos:
          (json['videos'] as List<dynamic>?)
              ?.map(
                (e) => CourseVideoSummary.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <CourseVideoSummary>[],
    );

Map<String, dynamic> _$$CourseDetailImplToJson(_$CourseDetailImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'title': instance.title,
      'description': instance.description,
      'coverImageUrl': instance.coverImageUrl,
      'ownerId': instance.ownerId,
      'published': instance.published,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'videos': instance.videos,
    };

_$CourseSummaryImpl _$$CourseSummaryImplFromJson(Map<String, dynamic> json) =>
    _$CourseSummaryImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      coverImageUrl: json['coverImageUrl'] as String?,
    );

Map<String, dynamic> _$$CourseSummaryImplToJson(_$CourseSummaryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'coverImageUrl': instance.coverImageUrl,
    };

_$CoursePageImpl _$$CoursePageImplFromJson(Map<String, dynamic> json) =>
    _$CoursePageImpl(
      items: (json['items'] as List<dynamic>)
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool,
    );

Map<String, dynamic> _$$CoursePageImplToJson(_$CoursePageImpl instance) =>
    <String, dynamic>{
      'items': instance.items,
      'nextCursor': instance.nextCursor,
      'hasMore': instance.hasMore,
    };
