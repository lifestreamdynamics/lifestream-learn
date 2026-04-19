// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'designer_application.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DesignerApplicationImpl _$$DesignerApplicationImplFromJson(
  Map<String, dynamic> json,
) => _$DesignerApplicationImpl(
  id: json['id'] as String,
  userId: json['userId'] as String,
  status: $enumDecode(_$AppStatusEnumMap, json['status']),
  note: json['note'] as String?,
  reviewerNote: json['reviewerNote'] as String?,
  submittedAt: DateTime.parse(json['submittedAt'] as String),
  reviewedAt: json['reviewedAt'] == null
      ? null
      : DateTime.parse(json['reviewedAt'] as String),
  reviewedBy: json['reviewedBy'] as String?,
);

Map<String, dynamic> _$$DesignerApplicationImplToJson(
  _$DesignerApplicationImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'status': _$AppStatusEnumMap[instance.status]!,
  'note': instance.note,
  'reviewerNote': instance.reviewerNote,
  'submittedAt': instance.submittedAt.toIso8601String(),
  'reviewedAt': instance.reviewedAt?.toIso8601String(),
  'reviewedBy': instance.reviewedBy,
};

const _$AppStatusEnumMap = {
  AppStatus.pending: 'PENDING',
  AppStatus.approved: 'APPROVED',
  AppStatus.rejected: 'REJECTED',
};

_$DesignerApplicationPageImpl _$$DesignerApplicationPageImplFromJson(
  Map<String, dynamic> json,
) => _$DesignerApplicationPageImpl(
  items: (json['items'] as List<dynamic>)
      .map((e) => DesignerApplication.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextCursor: json['nextCursor'] as String?,
  hasMore: json['hasMore'] as bool,
);

Map<String, dynamic> _$$DesignerApplicationPageImplToJson(
  _$DesignerApplicationPageImpl instance,
) => <String, dynamic>{
  'items': instance.items,
  'nextCursor': instance.nextCursor,
  'hasMore': instance.hasMore,
};
