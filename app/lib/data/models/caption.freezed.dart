// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'caption.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CaptionSummary _$CaptionSummaryFromJson(Map<String, dynamic> json) {
  return _CaptionSummary.fromJson(json);
}

/// @nodoc
mixin _$CaptionSummary {
  String get language => throw _privateConstructorUsedError;
  int get bytes => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;

  /// Serializes this CaptionSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CaptionSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CaptionSummaryCopyWith<CaptionSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CaptionSummaryCopyWith<$Res> {
  factory $CaptionSummaryCopyWith(
    CaptionSummary value,
    $Res Function(CaptionSummary) then,
  ) = _$CaptionSummaryCopyWithImpl<$Res, CaptionSummary>;
  @useResult
  $Res call({String language, int bytes, DateTime uploadedAt});
}

/// @nodoc
class _$CaptionSummaryCopyWithImpl<$Res, $Val extends CaptionSummary>
    implements $CaptionSummaryCopyWith<$Res> {
  _$CaptionSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CaptionSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? language = null,
    Object? bytes = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _value.copyWith(
            language: null == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                      as String,
            bytes: null == bytes
                ? _value.bytes
                : bytes // ignore: cast_nullable_to_non_nullable
                      as int,
            uploadedAt: null == uploadedAt
                ? _value.uploadedAt
                : uploadedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CaptionSummaryImplCopyWith<$Res>
    implements $CaptionSummaryCopyWith<$Res> {
  factory _$$CaptionSummaryImplCopyWith(
    _$CaptionSummaryImpl value,
    $Res Function(_$CaptionSummaryImpl) then,
  ) = __$$CaptionSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String language, int bytes, DateTime uploadedAt});
}

/// @nodoc
class __$$CaptionSummaryImplCopyWithImpl<$Res>
    extends _$CaptionSummaryCopyWithImpl<$Res, _$CaptionSummaryImpl>
    implements _$$CaptionSummaryImplCopyWith<$Res> {
  __$$CaptionSummaryImplCopyWithImpl(
    _$CaptionSummaryImpl _value,
    $Res Function(_$CaptionSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CaptionSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? language = null,
    Object? bytes = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _$CaptionSummaryImpl(
        language: null == language
            ? _value.language
            : language // ignore: cast_nullable_to_non_nullable
                  as String,
        bytes: null == bytes
            ? _value.bytes
            : bytes // ignore: cast_nullable_to_non_nullable
                  as int,
        uploadedAt: null == uploadedAt
            ? _value.uploadedAt
            : uploadedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CaptionSummaryImpl implements _CaptionSummary {
  const _$CaptionSummaryImpl({
    required this.language,
    required this.bytes,
    required this.uploadedAt,
  });

  factory _$CaptionSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CaptionSummaryImplFromJson(json);

  @override
  final String language;
  @override
  final int bytes;
  @override
  final DateTime uploadedAt;

  @override
  String toString() {
    return 'CaptionSummary(language: $language, bytes: $bytes, uploadedAt: $uploadedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CaptionSummaryImpl &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.bytes, bytes) || other.bytes == bytes) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, language, bytes, uploadedAt);

  /// Create a copy of CaptionSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CaptionSummaryImplCopyWith<_$CaptionSummaryImpl> get copyWith =>
      __$$CaptionSummaryImplCopyWithImpl<_$CaptionSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CaptionSummaryImplToJson(this);
  }
}

abstract class _CaptionSummary implements CaptionSummary {
  const factory _CaptionSummary({
    required final String language,
    required final int bytes,
    required final DateTime uploadedAt,
  }) = _$CaptionSummaryImpl;

  factory _CaptionSummary.fromJson(Map<String, dynamic> json) =
      _$CaptionSummaryImpl.fromJson;

  @override
  String get language;
  @override
  int get bytes;
  @override
  DateTime get uploadedAt;

  /// Create a copy of CaptionSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CaptionSummaryImplCopyWith<_$CaptionSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CaptionUploadResult _$CaptionUploadResultFromJson(Map<String, dynamic> json) {
  return _CaptionUploadResult.fromJson(json);
}

/// @nodoc
mixin _$CaptionUploadResult {
  String get language => throw _privateConstructorUsedError;
  int get bytes => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;

  /// Serializes this CaptionUploadResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CaptionUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CaptionUploadResultCopyWith<CaptionUploadResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CaptionUploadResultCopyWith<$Res> {
  factory $CaptionUploadResultCopyWith(
    CaptionUploadResult value,
    $Res Function(CaptionUploadResult) then,
  ) = _$CaptionUploadResultCopyWithImpl<$Res, CaptionUploadResult>;
  @useResult
  $Res call({String language, int bytes, DateTime uploadedAt});
}

/// @nodoc
class _$CaptionUploadResultCopyWithImpl<$Res, $Val extends CaptionUploadResult>
    implements $CaptionUploadResultCopyWith<$Res> {
  _$CaptionUploadResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CaptionUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? language = null,
    Object? bytes = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _value.copyWith(
            language: null == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                      as String,
            bytes: null == bytes
                ? _value.bytes
                : bytes // ignore: cast_nullable_to_non_nullable
                      as int,
            uploadedAt: null == uploadedAt
                ? _value.uploadedAt
                : uploadedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CaptionUploadResultImplCopyWith<$Res>
    implements $CaptionUploadResultCopyWith<$Res> {
  factory _$$CaptionUploadResultImplCopyWith(
    _$CaptionUploadResultImpl value,
    $Res Function(_$CaptionUploadResultImpl) then,
  ) = __$$CaptionUploadResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String language, int bytes, DateTime uploadedAt});
}

/// @nodoc
class __$$CaptionUploadResultImplCopyWithImpl<$Res>
    extends _$CaptionUploadResultCopyWithImpl<$Res, _$CaptionUploadResultImpl>
    implements _$$CaptionUploadResultImplCopyWith<$Res> {
  __$$CaptionUploadResultImplCopyWithImpl(
    _$CaptionUploadResultImpl _value,
    $Res Function(_$CaptionUploadResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CaptionUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? language = null,
    Object? bytes = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _$CaptionUploadResultImpl(
        language: null == language
            ? _value.language
            : language // ignore: cast_nullable_to_non_nullable
                  as String,
        bytes: null == bytes
            ? _value.bytes
            : bytes // ignore: cast_nullable_to_non_nullable
                  as int,
        uploadedAt: null == uploadedAt
            ? _value.uploadedAt
            : uploadedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CaptionUploadResultImpl implements _CaptionUploadResult {
  const _$CaptionUploadResultImpl({
    required this.language,
    required this.bytes,
    required this.uploadedAt,
  });

  factory _$CaptionUploadResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$CaptionUploadResultImplFromJson(json);

  @override
  final String language;
  @override
  final int bytes;
  @override
  final DateTime uploadedAt;

  @override
  String toString() {
    return 'CaptionUploadResult(language: $language, bytes: $bytes, uploadedAt: $uploadedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CaptionUploadResultImpl &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.bytes, bytes) || other.bytes == bytes) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, language, bytes, uploadedAt);

  /// Create a copy of CaptionUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CaptionUploadResultImplCopyWith<_$CaptionUploadResultImpl> get copyWith =>
      __$$CaptionUploadResultImplCopyWithImpl<_$CaptionUploadResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CaptionUploadResultImplToJson(this);
  }
}

abstract class _CaptionUploadResult implements CaptionUploadResult {
  const factory _CaptionUploadResult({
    required final String language,
    required final int bytes,
    required final DateTime uploadedAt,
  }) = _$CaptionUploadResultImpl;

  factory _CaptionUploadResult.fromJson(Map<String, dynamic> json) =
      _$CaptionUploadResultImpl.fromJson;

  @override
  String get language;
  @override
  int get bytes;
  @override
  DateTime get uploadedAt;

  /// Create a copy of CaptionUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CaptionUploadResultImplCopyWith<_$CaptionUploadResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
