// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'achievement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Achievement _$AchievementFromJson(Map<String, dynamic> json) {
  return _Achievement.fromJson(json);
}

/// @nodoc
mixin _$Achievement {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get iconKey => throw _privateConstructorUsedError;
  Map<String, dynamic> get criteriaJson => throw _privateConstructorUsedError;

  /// Serializes this Achievement to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Achievement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AchievementCopyWith<Achievement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AchievementCopyWith<$Res> {
  factory $AchievementCopyWith(
    Achievement value,
    $Res Function(Achievement) then,
  ) = _$AchievementCopyWithImpl<$Res, Achievement>;
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    String iconKey,
    Map<String, dynamic> criteriaJson,
  });
}

/// @nodoc
class _$AchievementCopyWithImpl<$Res, $Val extends Achievement>
    implements $AchievementCopyWith<$Res> {
  _$AchievementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Achievement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? iconKey = null,
    Object? criteriaJson = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            iconKey: null == iconKey
                ? _value.iconKey
                : iconKey // ignore: cast_nullable_to_non_nullable
                      as String,
            criteriaJson: null == criteriaJson
                ? _value.criteriaJson
                : criteriaJson // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AchievementImplCopyWith<$Res>
    implements $AchievementCopyWith<$Res> {
  factory _$$AchievementImplCopyWith(
    _$AchievementImpl value,
    $Res Function(_$AchievementImpl) then,
  ) = __$$AchievementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    String iconKey,
    Map<String, dynamic> criteriaJson,
  });
}

/// @nodoc
class __$$AchievementImplCopyWithImpl<$Res>
    extends _$AchievementCopyWithImpl<$Res, _$AchievementImpl>
    implements _$$AchievementImplCopyWith<$Res> {
  __$$AchievementImplCopyWithImpl(
    _$AchievementImpl _value,
    $Res Function(_$AchievementImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Achievement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? iconKey = null,
    Object? criteriaJson = null,
  }) {
    return _then(
      _$AchievementImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        iconKey: null == iconKey
            ? _value.iconKey
            : iconKey // ignore: cast_nullable_to_non_nullable
                  as String,
        criteriaJson: null == criteriaJson
            ? _value._criteriaJson
            : criteriaJson // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AchievementImpl implements _Achievement {
  const _$AchievementImpl({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required final Map<String, dynamic> criteriaJson,
  }) : _criteriaJson = criteriaJson;

  factory _$AchievementImpl.fromJson(Map<String, dynamic> json) =>
      _$$AchievementImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final String iconKey;
  final Map<String, dynamic> _criteriaJson;
  @override
  Map<String, dynamic> get criteriaJson {
    if (_criteriaJson is EqualUnmodifiableMapView) return _criteriaJson;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_criteriaJson);
  }

  @override
  String toString() {
    return 'Achievement(id: $id, title: $title, description: $description, iconKey: $iconKey, criteriaJson: $criteriaJson)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AchievementImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.iconKey, iconKey) || other.iconKey == iconKey) &&
            const DeepCollectionEquality().equals(
              other._criteriaJson,
              _criteriaJson,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    description,
    iconKey,
    const DeepCollectionEquality().hash(_criteriaJson),
  );

  /// Create a copy of Achievement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AchievementImplCopyWith<_$AchievementImpl> get copyWith =>
      __$$AchievementImplCopyWithImpl<_$AchievementImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AchievementImplToJson(this);
  }
}

abstract class _Achievement implements Achievement {
  const factory _Achievement({
    required final String id,
    required final String title,
    required final String description,
    required final String iconKey,
    required final Map<String, dynamic> criteriaJson,
  }) = _$AchievementImpl;

  factory _Achievement.fromJson(Map<String, dynamic> json) =
      _$AchievementImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get description;
  @override
  String get iconKey;
  @override
  Map<String, dynamic> get criteriaJson;

  /// Create a copy of Achievement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AchievementImplCopyWith<_$AchievementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AchievementsResponse _$AchievementsResponseFromJson(Map<String, dynamic> json) {
  return _AchievementsResponse.fromJson(json);
}

/// @nodoc
mixin _$AchievementsResponse {
  List<Achievement> get unlocked => throw _privateConstructorUsedError;
  List<Achievement> get locked =>
      throw _privateConstructorUsedError; // Server sends `{ [slug]: ISO-8601 }`; freezed+json_serializable
  // decode to `DateTime` per-value. Map<String, DateTime> on the client.
  Map<String, DateTime> get unlockedAtByAchievementId =>
      throw _privateConstructorUsedError;

  /// Serializes this AchievementsResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AchievementsResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AchievementsResponseCopyWith<AchievementsResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AchievementsResponseCopyWith<$Res> {
  factory $AchievementsResponseCopyWith(
    AchievementsResponse value,
    $Res Function(AchievementsResponse) then,
  ) = _$AchievementsResponseCopyWithImpl<$Res, AchievementsResponse>;
  @useResult
  $Res call({
    List<Achievement> unlocked,
    List<Achievement> locked,
    Map<String, DateTime> unlockedAtByAchievementId,
  });
}

/// @nodoc
class _$AchievementsResponseCopyWithImpl<
  $Res,
  $Val extends AchievementsResponse
>
    implements $AchievementsResponseCopyWith<$Res> {
  _$AchievementsResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AchievementsResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unlocked = null,
    Object? locked = null,
    Object? unlockedAtByAchievementId = null,
  }) {
    return _then(
      _value.copyWith(
            unlocked: null == unlocked
                ? _value.unlocked
                : unlocked // ignore: cast_nullable_to_non_nullable
                      as List<Achievement>,
            locked: null == locked
                ? _value.locked
                : locked // ignore: cast_nullable_to_non_nullable
                      as List<Achievement>,
            unlockedAtByAchievementId: null == unlockedAtByAchievementId
                ? _value.unlockedAtByAchievementId
                : unlockedAtByAchievementId // ignore: cast_nullable_to_non_nullable
                      as Map<String, DateTime>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AchievementsResponseImplCopyWith<$Res>
    implements $AchievementsResponseCopyWith<$Res> {
  factory _$$AchievementsResponseImplCopyWith(
    _$AchievementsResponseImpl value,
    $Res Function(_$AchievementsResponseImpl) then,
  ) = __$$AchievementsResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Achievement> unlocked,
    List<Achievement> locked,
    Map<String, DateTime> unlockedAtByAchievementId,
  });
}

/// @nodoc
class __$$AchievementsResponseImplCopyWithImpl<$Res>
    extends _$AchievementsResponseCopyWithImpl<$Res, _$AchievementsResponseImpl>
    implements _$$AchievementsResponseImplCopyWith<$Res> {
  __$$AchievementsResponseImplCopyWithImpl(
    _$AchievementsResponseImpl _value,
    $Res Function(_$AchievementsResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AchievementsResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unlocked = null,
    Object? locked = null,
    Object? unlockedAtByAchievementId = null,
  }) {
    return _then(
      _$AchievementsResponseImpl(
        unlocked: null == unlocked
            ? _value._unlocked
            : unlocked // ignore: cast_nullable_to_non_nullable
                  as List<Achievement>,
        locked: null == locked
            ? _value._locked
            : locked // ignore: cast_nullable_to_non_nullable
                  as List<Achievement>,
        unlockedAtByAchievementId: null == unlockedAtByAchievementId
            ? _value._unlockedAtByAchievementId
            : unlockedAtByAchievementId // ignore: cast_nullable_to_non_nullable
                  as Map<String, DateTime>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AchievementsResponseImpl implements _AchievementsResponse {
  const _$AchievementsResponseImpl({
    required final List<Achievement> unlocked,
    required final List<Achievement> locked,
    required final Map<String, DateTime> unlockedAtByAchievementId,
  }) : _unlocked = unlocked,
       _locked = locked,
       _unlockedAtByAchievementId = unlockedAtByAchievementId;

  factory _$AchievementsResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$AchievementsResponseImplFromJson(json);

  final List<Achievement> _unlocked;
  @override
  List<Achievement> get unlocked {
    if (_unlocked is EqualUnmodifiableListView) return _unlocked;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_unlocked);
  }

  final List<Achievement> _locked;
  @override
  List<Achievement> get locked {
    if (_locked is EqualUnmodifiableListView) return _locked;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_locked);
  }

  // Server sends `{ [slug]: ISO-8601 }`; freezed+json_serializable
  // decode to `DateTime` per-value. Map<String, DateTime> on the client.
  final Map<String, DateTime> _unlockedAtByAchievementId;
  // Server sends `{ [slug]: ISO-8601 }`; freezed+json_serializable
  // decode to `DateTime` per-value. Map<String, DateTime> on the client.
  @override
  Map<String, DateTime> get unlockedAtByAchievementId {
    if (_unlockedAtByAchievementId is EqualUnmodifiableMapView)
      return _unlockedAtByAchievementId;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_unlockedAtByAchievementId);
  }

  @override
  String toString() {
    return 'AchievementsResponse(unlocked: $unlocked, locked: $locked, unlockedAtByAchievementId: $unlockedAtByAchievementId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AchievementsResponseImpl &&
            const DeepCollectionEquality().equals(other._unlocked, _unlocked) &&
            const DeepCollectionEquality().equals(other._locked, _locked) &&
            const DeepCollectionEquality().equals(
              other._unlockedAtByAchievementId,
              _unlockedAtByAchievementId,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_unlocked),
    const DeepCollectionEquality().hash(_locked),
    const DeepCollectionEquality().hash(_unlockedAtByAchievementId),
  );

  /// Create a copy of AchievementsResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AchievementsResponseImplCopyWith<_$AchievementsResponseImpl>
  get copyWith =>
      __$$AchievementsResponseImplCopyWithImpl<_$AchievementsResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AchievementsResponseImplToJson(this);
  }
}

abstract class _AchievementsResponse implements AchievementsResponse {
  const factory _AchievementsResponse({
    required final List<Achievement> unlocked,
    required final List<Achievement> locked,
    required final Map<String, DateTime> unlockedAtByAchievementId,
  }) = _$AchievementsResponseImpl;

  factory _AchievementsResponse.fromJson(Map<String, dynamic> json) =
      _$AchievementsResponseImpl.fromJson;

  @override
  List<Achievement> get unlocked;
  @override
  List<Achievement> get locked; // Server sends `{ [slug]: ISO-8601 }`; freezed+json_serializable
  // decode to `DateTime` per-value. Map<String, DateTime> on the client.
  @override
  Map<String, DateTime> get unlockedAtByAchievementId;

  /// Create a copy of AchievementsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AchievementsResponseImplCopyWith<_$AchievementsResponseImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AchievementSummary _$AchievementSummaryFromJson(Map<String, dynamic> json) {
  return _AchievementSummary.fromJson(json);
}

/// @nodoc
mixin _$AchievementSummary {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get iconKey => throw _privateConstructorUsedError;
  DateTime get unlockedAt => throw _privateConstructorUsedError;

  /// Serializes this AchievementSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AchievementSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AchievementSummaryCopyWith<AchievementSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AchievementSummaryCopyWith<$Res> {
  factory $AchievementSummaryCopyWith(
    AchievementSummary value,
    $Res Function(AchievementSummary) then,
  ) = _$AchievementSummaryCopyWithImpl<$Res, AchievementSummary>;
  @useResult
  $Res call({String id, String title, String iconKey, DateTime unlockedAt});
}

/// @nodoc
class _$AchievementSummaryCopyWithImpl<$Res, $Val extends AchievementSummary>
    implements $AchievementSummaryCopyWith<$Res> {
  _$AchievementSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AchievementSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? iconKey = null,
    Object? unlockedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            iconKey: null == iconKey
                ? _value.iconKey
                : iconKey // ignore: cast_nullable_to_non_nullable
                      as String,
            unlockedAt: null == unlockedAt
                ? _value.unlockedAt
                : unlockedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AchievementSummaryImplCopyWith<$Res>
    implements $AchievementSummaryCopyWith<$Res> {
  factory _$$AchievementSummaryImplCopyWith(
    _$AchievementSummaryImpl value,
    $Res Function(_$AchievementSummaryImpl) then,
  ) = __$$AchievementSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, String iconKey, DateTime unlockedAt});
}

/// @nodoc
class __$$AchievementSummaryImplCopyWithImpl<$Res>
    extends _$AchievementSummaryCopyWithImpl<$Res, _$AchievementSummaryImpl>
    implements _$$AchievementSummaryImplCopyWith<$Res> {
  __$$AchievementSummaryImplCopyWithImpl(
    _$AchievementSummaryImpl _value,
    $Res Function(_$AchievementSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AchievementSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? iconKey = null,
    Object? unlockedAt = null,
  }) {
    return _then(
      _$AchievementSummaryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        iconKey: null == iconKey
            ? _value.iconKey
            : iconKey // ignore: cast_nullable_to_non_nullable
                  as String,
        unlockedAt: null == unlockedAt
            ? _value.unlockedAt
            : unlockedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AchievementSummaryImpl implements _AchievementSummary {
  const _$AchievementSummaryImpl({
    required this.id,
    required this.title,
    required this.iconKey,
    required this.unlockedAt,
  });

  factory _$AchievementSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$AchievementSummaryImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String iconKey;
  @override
  final DateTime unlockedAt;

  @override
  String toString() {
    return 'AchievementSummary(id: $id, title: $title, iconKey: $iconKey, unlockedAt: $unlockedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AchievementSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.iconKey, iconKey) || other.iconKey == iconKey) &&
            (identical(other.unlockedAt, unlockedAt) ||
                other.unlockedAt == unlockedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, iconKey, unlockedAt);

  /// Create a copy of AchievementSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AchievementSummaryImplCopyWith<_$AchievementSummaryImpl> get copyWith =>
      __$$AchievementSummaryImplCopyWithImpl<_$AchievementSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AchievementSummaryImplToJson(this);
  }
}

abstract class _AchievementSummary implements AchievementSummary {
  const factory _AchievementSummary({
    required final String id,
    required final String title,
    required final String iconKey,
    required final DateTime unlockedAt,
  }) = _$AchievementSummaryImpl;

  factory _AchievementSummary.fromJson(Map<String, dynamic> json) =
      _$AchievementSummaryImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get iconKey;
  @override
  DateTime get unlockedAt;

  /// Create a copy of AchievementSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AchievementSummaryImplCopyWith<_$AchievementSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
