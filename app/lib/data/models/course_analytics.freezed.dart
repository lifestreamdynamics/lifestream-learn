// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'course_analytics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PerCueTypeAccuracy _$PerCueTypeAccuracyFromJson(Map<String, dynamic> json) {
  return _PerCueTypeAccuracy.fromJson(json);
}

/// @nodoc
mixin _$PerCueTypeAccuracy {
  @JsonKey(name: 'MCQ')
  double? get mcq => throw _privateConstructorUsedError;
  @JsonKey(name: 'BLANKS')
  double? get blanks => throw _privateConstructorUsedError;
  @JsonKey(name: 'MATCHING')
  double? get matching => throw _privateConstructorUsedError;

  /// Serializes this PerCueTypeAccuracy to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PerCueTypeAccuracy
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PerCueTypeAccuracyCopyWith<PerCueTypeAccuracy> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PerCueTypeAccuracyCopyWith<$Res> {
  factory $PerCueTypeAccuracyCopyWith(
    PerCueTypeAccuracy value,
    $Res Function(PerCueTypeAccuracy) then,
  ) = _$PerCueTypeAccuracyCopyWithImpl<$Res, PerCueTypeAccuracy>;
  @useResult
  $Res call({
    @JsonKey(name: 'MCQ') double? mcq,
    @JsonKey(name: 'BLANKS') double? blanks,
    @JsonKey(name: 'MATCHING') double? matching,
  });
}

/// @nodoc
class _$PerCueTypeAccuracyCopyWithImpl<$Res, $Val extends PerCueTypeAccuracy>
    implements $PerCueTypeAccuracyCopyWith<$Res> {
  _$PerCueTypeAccuracyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PerCueTypeAccuracy
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mcq = freezed,
    Object? blanks = freezed,
    Object? matching = freezed,
  }) {
    return _then(
      _value.copyWith(
            mcq: freezed == mcq
                ? _value.mcq
                : mcq // ignore: cast_nullable_to_non_nullable
                      as double?,
            blanks: freezed == blanks
                ? _value.blanks
                : blanks // ignore: cast_nullable_to_non_nullable
                      as double?,
            matching: freezed == matching
                ? _value.matching
                : matching // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PerCueTypeAccuracyImplCopyWith<$Res>
    implements $PerCueTypeAccuracyCopyWith<$Res> {
  factory _$$PerCueTypeAccuracyImplCopyWith(
    _$PerCueTypeAccuracyImpl value,
    $Res Function(_$PerCueTypeAccuracyImpl) then,
  ) = __$$PerCueTypeAccuracyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'MCQ') double? mcq,
    @JsonKey(name: 'BLANKS') double? blanks,
    @JsonKey(name: 'MATCHING') double? matching,
  });
}

/// @nodoc
class __$$PerCueTypeAccuracyImplCopyWithImpl<$Res>
    extends _$PerCueTypeAccuracyCopyWithImpl<$Res, _$PerCueTypeAccuracyImpl>
    implements _$$PerCueTypeAccuracyImplCopyWith<$Res> {
  __$$PerCueTypeAccuracyImplCopyWithImpl(
    _$PerCueTypeAccuracyImpl _value,
    $Res Function(_$PerCueTypeAccuracyImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PerCueTypeAccuracy
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mcq = freezed,
    Object? blanks = freezed,
    Object? matching = freezed,
  }) {
    return _then(
      _$PerCueTypeAccuracyImpl(
        mcq: freezed == mcq
            ? _value.mcq
            : mcq // ignore: cast_nullable_to_non_nullable
                  as double?,
        blanks: freezed == blanks
            ? _value.blanks
            : blanks // ignore: cast_nullable_to_non_nullable
                  as double?,
        matching: freezed == matching
            ? _value.matching
            : matching // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PerCueTypeAccuracyImpl implements _PerCueTypeAccuracy {
  const _$PerCueTypeAccuracyImpl({
    @JsonKey(name: 'MCQ') this.mcq,
    @JsonKey(name: 'BLANKS') this.blanks,
    @JsonKey(name: 'MATCHING') this.matching,
  });

  factory _$PerCueTypeAccuracyImpl.fromJson(Map<String, dynamic> json) =>
      _$$PerCueTypeAccuracyImplFromJson(json);

  @override
  @JsonKey(name: 'MCQ')
  final double? mcq;
  @override
  @JsonKey(name: 'BLANKS')
  final double? blanks;
  @override
  @JsonKey(name: 'MATCHING')
  final double? matching;

  @override
  String toString() {
    return 'PerCueTypeAccuracy(mcq: $mcq, blanks: $blanks, matching: $matching)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PerCueTypeAccuracyImpl &&
            (identical(other.mcq, mcq) || other.mcq == mcq) &&
            (identical(other.blanks, blanks) || other.blanks == blanks) &&
            (identical(other.matching, matching) ||
                other.matching == matching));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mcq, blanks, matching);

  /// Create a copy of PerCueTypeAccuracy
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PerCueTypeAccuracyImplCopyWith<_$PerCueTypeAccuracyImpl> get copyWith =>
      __$$PerCueTypeAccuracyImplCopyWithImpl<_$PerCueTypeAccuracyImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PerCueTypeAccuracyImplToJson(this);
  }
}

abstract class _PerCueTypeAccuracy implements PerCueTypeAccuracy {
  const factory _PerCueTypeAccuracy({
    @JsonKey(name: 'MCQ') final double? mcq,
    @JsonKey(name: 'BLANKS') final double? blanks,
    @JsonKey(name: 'MATCHING') final double? matching,
  }) = _$PerCueTypeAccuracyImpl;

  factory _PerCueTypeAccuracy.fromJson(Map<String, dynamic> json) =
      _$PerCueTypeAccuracyImpl.fromJson;

  @override
  @JsonKey(name: 'MCQ')
  double? get mcq;
  @override
  @JsonKey(name: 'BLANKS')
  double? get blanks;
  @override
  @JsonKey(name: 'MATCHING')
  double? get matching;

  /// Create a copy of PerCueTypeAccuracy
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PerCueTypeAccuracyImplCopyWith<_$PerCueTypeAccuracyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CourseAnalytics _$CourseAnalyticsFromJson(Map<String, dynamic> json) {
  return _CourseAnalytics.fromJson(json);
}

/// @nodoc
mixin _$CourseAnalytics {
  int get totalViews => throw _privateConstructorUsedError;
  double get completionRate => throw _privateConstructorUsedError;
  PerCueTypeAccuracy get perCueTypeAccuracy =>
      throw _privateConstructorUsedError;

  /// Serializes this CourseAnalytics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CourseAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseAnalyticsCopyWith<CourseAnalytics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseAnalyticsCopyWith<$Res> {
  factory $CourseAnalyticsCopyWith(
    CourseAnalytics value,
    $Res Function(CourseAnalytics) then,
  ) = _$CourseAnalyticsCopyWithImpl<$Res, CourseAnalytics>;
  @useResult
  $Res call({
    int totalViews,
    double completionRate,
    PerCueTypeAccuracy perCueTypeAccuracy,
  });

  $PerCueTypeAccuracyCopyWith<$Res> get perCueTypeAccuracy;
}

/// @nodoc
class _$CourseAnalyticsCopyWithImpl<$Res, $Val extends CourseAnalytics>
    implements $CourseAnalyticsCopyWith<$Res> {
  _$CourseAnalyticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourseAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalViews = null,
    Object? completionRate = null,
    Object? perCueTypeAccuracy = null,
  }) {
    return _then(
      _value.copyWith(
            totalViews: null == totalViews
                ? _value.totalViews
                : totalViews // ignore: cast_nullable_to_non_nullable
                      as int,
            completionRate: null == completionRate
                ? _value.completionRate
                : completionRate // ignore: cast_nullable_to_non_nullable
                      as double,
            perCueTypeAccuracy: null == perCueTypeAccuracy
                ? _value.perCueTypeAccuracy
                : perCueTypeAccuracy // ignore: cast_nullable_to_non_nullable
                      as PerCueTypeAccuracy,
          )
          as $Val,
    );
  }

  /// Create a copy of CourseAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PerCueTypeAccuracyCopyWith<$Res> get perCueTypeAccuracy {
    return $PerCueTypeAccuracyCopyWith<$Res>(_value.perCueTypeAccuracy, (
      value,
    ) {
      return _then(_value.copyWith(perCueTypeAccuracy: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CourseAnalyticsImplCopyWith<$Res>
    implements $CourseAnalyticsCopyWith<$Res> {
  factory _$$CourseAnalyticsImplCopyWith(
    _$CourseAnalyticsImpl value,
    $Res Function(_$CourseAnalyticsImpl) then,
  ) = __$$CourseAnalyticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int totalViews,
    double completionRate,
    PerCueTypeAccuracy perCueTypeAccuracy,
  });

  @override
  $PerCueTypeAccuracyCopyWith<$Res> get perCueTypeAccuracy;
}

/// @nodoc
class __$$CourseAnalyticsImplCopyWithImpl<$Res>
    extends _$CourseAnalyticsCopyWithImpl<$Res, _$CourseAnalyticsImpl>
    implements _$$CourseAnalyticsImplCopyWith<$Res> {
  __$$CourseAnalyticsImplCopyWithImpl(
    _$CourseAnalyticsImpl _value,
    $Res Function(_$CourseAnalyticsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourseAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalViews = null,
    Object? completionRate = null,
    Object? perCueTypeAccuracy = null,
  }) {
    return _then(
      _$CourseAnalyticsImpl(
        totalViews: null == totalViews
            ? _value.totalViews
            : totalViews // ignore: cast_nullable_to_non_nullable
                  as int,
        completionRate: null == completionRate
            ? _value.completionRate
            : completionRate // ignore: cast_nullable_to_non_nullable
                  as double,
        perCueTypeAccuracy: null == perCueTypeAccuracy
            ? _value.perCueTypeAccuracy
            : perCueTypeAccuracy // ignore: cast_nullable_to_non_nullable
                  as PerCueTypeAccuracy,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CourseAnalyticsImpl implements _CourseAnalytics {
  const _$CourseAnalyticsImpl({
    required this.totalViews,
    required this.completionRate,
    required this.perCueTypeAccuracy,
  });

  factory _$CourseAnalyticsImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseAnalyticsImplFromJson(json);

  @override
  final int totalViews;
  @override
  final double completionRate;
  @override
  final PerCueTypeAccuracy perCueTypeAccuracy;

  @override
  String toString() {
    return 'CourseAnalytics(totalViews: $totalViews, completionRate: $completionRate, perCueTypeAccuracy: $perCueTypeAccuracy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseAnalyticsImpl &&
            (identical(other.totalViews, totalViews) ||
                other.totalViews == totalViews) &&
            (identical(other.completionRate, completionRate) ||
                other.completionRate == completionRate) &&
            (identical(other.perCueTypeAccuracy, perCueTypeAccuracy) ||
                other.perCueTypeAccuracy == perCueTypeAccuracy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, totalViews, completionRate, perCueTypeAccuracy);

  /// Create a copy of CourseAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseAnalyticsImplCopyWith<_$CourseAnalyticsImpl> get copyWith =>
      __$$CourseAnalyticsImplCopyWithImpl<_$CourseAnalyticsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseAnalyticsImplToJson(this);
  }
}

abstract class _CourseAnalytics implements CourseAnalytics {
  const factory _CourseAnalytics({
    required final int totalViews,
    required final double completionRate,
    required final PerCueTypeAccuracy perCueTypeAccuracy,
  }) = _$CourseAnalyticsImpl;

  factory _CourseAnalytics.fromJson(Map<String, dynamic> json) =
      _$CourseAnalyticsImpl.fromJson;

  @override
  int get totalViews;
  @override
  double get completionRate;
  @override
  PerCueTypeAccuracy get perCueTypeAccuracy;

  /// Create a copy of CourseAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseAnalyticsImplCopyWith<_$CourseAnalyticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
