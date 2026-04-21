// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
  id: json['id'] as String,
  email: json['email'] as String,
  displayName: json['displayName'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  avatarKey: json['avatarKey'] as String?,
  useGravatar: json['useGravatar'] as bool? ?? false,
  preferences: json['preferences'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'role': _$UserRoleEnumMap[instance.role]!,
      'createdAt': instance.createdAt?.toIso8601String(),
      'avatarKey': instance.avatarKey,
      'useGravatar': instance.useGravatar,
      'preferences': instance.preferences,
    };

const _$UserRoleEnumMap = {
  UserRole.admin: 'ADMIN',
  UserRole.courseDesigner: 'COURSE_DESIGNER',
  UserRole.learner: 'LEARNER',
};
