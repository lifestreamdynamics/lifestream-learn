// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AchievementImpl _$$AchievementImplFromJson(Map<String, dynamic> json) =>
    _$AchievementImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      iconKey: json['iconKey'] as String,
      criteriaJson: json['criteriaJson'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$$AchievementImplToJson(_$AchievementImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'iconKey': instance.iconKey,
      'criteriaJson': instance.criteriaJson,
    };

_$AchievementsResponseImpl _$$AchievementsResponseImplFromJson(
  Map<String, dynamic> json,
) => _$AchievementsResponseImpl(
  unlocked: (json['unlocked'] as List<dynamic>)
      .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
      .toList(),
  locked: (json['locked'] as List<dynamic>)
      .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
      .toList(),
  unlockedAtByAchievementId:
      (json['unlockedAtByAchievementId'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, DateTime.parse(e as String)),
      ),
);

Map<String, dynamic> _$$AchievementsResponseImplToJson(
  _$AchievementsResponseImpl instance,
) => <String, dynamic>{
  'unlocked': instance.unlocked,
  'locked': instance.locked,
  'unlockedAtByAchievementId': instance.unlockedAtByAchievementId.map(
    (k, e) => MapEntry(k, e.toIso8601String()),
  ),
};

_$AchievementSummaryImpl _$$AchievementSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$AchievementSummaryImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  iconKey: json['iconKey'] as String,
  unlockedAt: DateTime.parse(json['unlockedAt'] as String),
);

Map<String, dynamic> _$$AchievementSummaryImplToJson(
  _$AchievementSummaryImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'iconKey': instance.iconKey,
  'unlockedAt': instance.unlockedAt.toIso8601String(),
};
