// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CaptionTrack _$CaptionTrackFromJson(Map<String, dynamic> json) {
  return _CaptionTrack.fromJson(json);
}

/// @nodoc
mixin _$CaptionTrack {
  String get language => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;

  /// Serializes this CaptionTrack to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CaptionTrack
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CaptionTrackCopyWith<CaptionTrack> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CaptionTrackCopyWith<$Res> {
  factory $CaptionTrackCopyWith(
    CaptionTrack value,
    $Res Function(CaptionTrack) then,
  ) = _$CaptionTrackCopyWithImpl<$Res, CaptionTrack>;
  @useResult
  $Res call({String language, String url, DateTime expiresAt});
}

/// @nodoc
class _$CaptionTrackCopyWithImpl<$Res, $Val extends CaptionTrack>
    implements $CaptionTrackCopyWith<$Res> {
  _$CaptionTrackCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CaptionTrack
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? language = null,
    Object? url = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _value.copyWith(
            language: null == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                      as String,
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CaptionTrackImplCopyWith<$Res>
    implements $CaptionTrackCopyWith<$Res> {
  factory _$$CaptionTrackImplCopyWith(
    _$CaptionTrackImpl value,
    $Res Function(_$CaptionTrackImpl) then,
  ) = __$$CaptionTrackImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String language, String url, DateTime expiresAt});
}

/// @nodoc
class __$$CaptionTrackImplCopyWithImpl<$Res>
    extends _$CaptionTrackCopyWithImpl<$Res, _$CaptionTrackImpl>
    implements _$$CaptionTrackImplCopyWith<$Res> {
  __$$CaptionTrackImplCopyWithImpl(
    _$CaptionTrackImpl _value,
    $Res Function(_$CaptionTrackImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CaptionTrack
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? language = null,
    Object? url = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _$CaptionTrackImpl(
        language: null == language
            ? _value.language
            : language // ignore: cast_nullable_to_non_nullable
                  as String,
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CaptionTrackImpl implements _CaptionTrack {
  const _$CaptionTrackImpl({
    required this.language,
    required this.url,
    required this.expiresAt,
  });

  factory _$CaptionTrackImpl.fromJson(Map<String, dynamic> json) =>
      _$$CaptionTrackImplFromJson(json);

  @override
  final String language;
  @override
  final String url;
  @override
  final DateTime expiresAt;

  @override
  String toString() {
    return 'CaptionTrack(language: $language, url: $url, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CaptionTrackImpl &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, language, url, expiresAt);

  /// Create a copy of CaptionTrack
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CaptionTrackImplCopyWith<_$CaptionTrackImpl> get copyWith =>
      __$$CaptionTrackImplCopyWithImpl<_$CaptionTrackImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CaptionTrackImplToJson(this);
  }
}

abstract class _CaptionTrack implements CaptionTrack {
  const factory _CaptionTrack({
    required final String language,
    required final String url,
    required final DateTime expiresAt,
  }) = _$CaptionTrackImpl;

  factory _CaptionTrack.fromJson(Map<String, dynamic> json) =
      _$CaptionTrackImpl.fromJson;

  @override
  String get language;
  @override
  String get url;
  @override
  DateTime get expiresAt;

  /// Create a copy of CaptionTrack
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CaptionTrackImplCopyWith<_$CaptionTrackImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VideoSummary _$VideoSummaryFromJson(Map<String, dynamic> json) {
  return _VideoSummary.fromJson(json);
}

/// @nodoc
mixin _$VideoSummary {
  String get id => throw _privateConstructorUsedError;
  String get courseId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  int get orderIndex => throw _privateConstructorUsedError;
  VideoStatus get status => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;

  /// BCP-47 caption language to surface as default in the designer UI
  /// (matching caption row gets a "default" marker) and the player
  /// (used for caption auto-selection). Null when no default is set.
  String? get defaultCaptionLanguage => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this VideoSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VideoSummaryCopyWith<VideoSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoSummaryCopyWith<$Res> {
  factory $VideoSummaryCopyWith(
    VideoSummary value,
    $Res Function(VideoSummary) then,
  ) = _$VideoSummaryCopyWithImpl<$Res, VideoSummary>;
  @useResult
  $Res call({
    String id,
    String courseId,
    String title,
    int orderIndex,
    VideoStatus status,
    int? durationMs,
    String? defaultCaptionLanguage,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$VideoSummaryCopyWithImpl<$Res, $Val extends VideoSummary>
    implements $VideoSummaryCopyWith<$Res> {
  _$VideoSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? courseId = null,
    Object? title = null,
    Object? orderIndex = null,
    Object? status = null,
    Object? durationMs = freezed,
    Object? defaultCaptionLanguage = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            courseId: null == courseId
                ? _value.courseId
                : courseId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            orderIndex: null == orderIndex
                ? _value.orderIndex
                : orderIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as VideoStatus,
            durationMs: freezed == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int?,
            defaultCaptionLanguage: freezed == defaultCaptionLanguage
                ? _value.defaultCaptionLanguage
                : defaultCaptionLanguage // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VideoSummaryImplCopyWith<$Res>
    implements $VideoSummaryCopyWith<$Res> {
  factory _$$VideoSummaryImplCopyWith(
    _$VideoSummaryImpl value,
    $Res Function(_$VideoSummaryImpl) then,
  ) = __$$VideoSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String courseId,
    String title,
    int orderIndex,
    VideoStatus status,
    int? durationMs,
    String? defaultCaptionLanguage,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$VideoSummaryImplCopyWithImpl<$Res>
    extends _$VideoSummaryCopyWithImpl<$Res, _$VideoSummaryImpl>
    implements _$$VideoSummaryImplCopyWith<$Res> {
  __$$VideoSummaryImplCopyWithImpl(
    _$VideoSummaryImpl _value,
    $Res Function(_$VideoSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? courseId = null,
    Object? title = null,
    Object? orderIndex = null,
    Object? status = null,
    Object? durationMs = freezed,
    Object? defaultCaptionLanguage = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$VideoSummaryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        courseId: null == courseId
            ? _value.courseId
            : courseId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        orderIndex: null == orderIndex
            ? _value.orderIndex
            : orderIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as VideoStatus,
        durationMs: freezed == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int?,
        defaultCaptionLanguage: freezed == defaultCaptionLanguage
            ? _value.defaultCaptionLanguage
            : defaultCaptionLanguage // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VideoSummaryImpl implements _VideoSummary {
  const _$VideoSummaryImpl({
    required this.id,
    required this.courseId,
    required this.title,
    required this.orderIndex,
    required this.status,
    this.durationMs,
    this.defaultCaptionLanguage,
    required this.createdAt,
    this.updatedAt,
  });

  factory _$VideoSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$VideoSummaryImplFromJson(json);

  @override
  final String id;
  @override
  final String courseId;
  @override
  final String title;
  @override
  final int orderIndex;
  @override
  final VideoStatus status;
  @override
  final int? durationMs;

  /// BCP-47 caption language to surface as default in the designer UI
  /// (matching caption row gets a "default" marker) and the player
  /// (used for caption auto-selection). Null when no default is set.
  @override
  final String? defaultCaptionLanguage;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'VideoSummary(id: $id, courseId: $courseId, title: $title, orderIndex: $orderIndex, status: $status, durationMs: $durationMs, defaultCaptionLanguage: $defaultCaptionLanguage, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.courseId, courseId) ||
                other.courseId == courseId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.defaultCaptionLanguage, defaultCaptionLanguage) ||
                other.defaultCaptionLanguage == defaultCaptionLanguage) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    courseId,
    title,
    orderIndex,
    status,
    durationMs,
    defaultCaptionLanguage,
    createdAt,
    updatedAt,
  );

  /// Create a copy of VideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoSummaryImplCopyWith<_$VideoSummaryImpl> get copyWith =>
      __$$VideoSummaryImplCopyWithImpl<_$VideoSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VideoSummaryImplToJson(this);
  }
}

abstract class _VideoSummary implements VideoSummary {
  const factory _VideoSummary({
    required final String id,
    required final String courseId,
    required final String title,
    required final int orderIndex,
    required final VideoStatus status,
    final int? durationMs,
    final String? defaultCaptionLanguage,
    required final DateTime createdAt,
    final DateTime? updatedAt,
  }) = _$VideoSummaryImpl;

  factory _VideoSummary.fromJson(Map<String, dynamic> json) =
      _$VideoSummaryImpl.fromJson;

  @override
  String get id;
  @override
  String get courseId;
  @override
  String get title;
  @override
  int get orderIndex;
  @override
  VideoStatus get status;
  @override
  int? get durationMs;

  /// BCP-47 caption language to surface as default in the designer UI
  /// (matching caption row gets a "default" marker) and the player
  /// (used for caption auto-selection). Null when no default is set.
  @override
  String? get defaultCaptionLanguage;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of VideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VideoSummaryImplCopyWith<_$VideoSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CourseVideoSummary _$CourseVideoSummaryFromJson(Map<String, dynamic> json) {
  return _CourseVideoSummary.fromJson(json);
}

/// @nodoc
mixin _$CourseVideoSummary {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  int get orderIndex => throw _privateConstructorUsedError;
  VideoStatus get status => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;

  /// Serializes this CourseVideoSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CourseVideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseVideoSummaryCopyWith<CourseVideoSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseVideoSummaryCopyWith<$Res> {
  factory $CourseVideoSummaryCopyWith(
    CourseVideoSummary value,
    $Res Function(CourseVideoSummary) then,
  ) = _$CourseVideoSummaryCopyWithImpl<$Res, CourseVideoSummary>;
  @useResult
  $Res call({
    String id,
    String title,
    int orderIndex,
    VideoStatus status,
    int? durationMs,
  });
}

/// @nodoc
class _$CourseVideoSummaryCopyWithImpl<$Res, $Val extends CourseVideoSummary>
    implements $CourseVideoSummaryCopyWith<$Res> {
  _$CourseVideoSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourseVideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? orderIndex = null,
    Object? status = null,
    Object? durationMs = freezed,
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
            orderIndex: null == orderIndex
                ? _value.orderIndex
                : orderIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as VideoStatus,
            durationMs: freezed == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourseVideoSummaryImplCopyWith<$Res>
    implements $CourseVideoSummaryCopyWith<$Res> {
  factory _$$CourseVideoSummaryImplCopyWith(
    _$CourseVideoSummaryImpl value,
    $Res Function(_$CourseVideoSummaryImpl) then,
  ) = __$$CourseVideoSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    int orderIndex,
    VideoStatus status,
    int? durationMs,
  });
}

/// @nodoc
class __$$CourseVideoSummaryImplCopyWithImpl<$Res>
    extends _$CourseVideoSummaryCopyWithImpl<$Res, _$CourseVideoSummaryImpl>
    implements _$$CourseVideoSummaryImplCopyWith<$Res> {
  __$$CourseVideoSummaryImplCopyWithImpl(
    _$CourseVideoSummaryImpl _value,
    $Res Function(_$CourseVideoSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourseVideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? orderIndex = null,
    Object? status = null,
    Object? durationMs = freezed,
  }) {
    return _then(
      _$CourseVideoSummaryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        orderIndex: null == orderIndex
            ? _value.orderIndex
            : orderIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as VideoStatus,
        durationMs: freezed == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CourseVideoSummaryImpl implements _CourseVideoSummary {
  const _$CourseVideoSummaryImpl({
    required this.id,
    required this.title,
    required this.orderIndex,
    required this.status,
    this.durationMs,
  });

  factory _$CourseVideoSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseVideoSummaryImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final int orderIndex;
  @override
  final VideoStatus status;
  @override
  final int? durationMs;

  @override
  String toString() {
    return 'CourseVideoSummary(id: $id, title: $title, orderIndex: $orderIndex, status: $status, durationMs: $durationMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseVideoSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, orderIndex, status, durationMs);

  /// Create a copy of CourseVideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseVideoSummaryImplCopyWith<_$CourseVideoSummaryImpl> get copyWith =>
      __$$CourseVideoSummaryImplCopyWithImpl<_$CourseVideoSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseVideoSummaryImplToJson(this);
  }
}

abstract class _CourseVideoSummary implements CourseVideoSummary {
  const factory _CourseVideoSummary({
    required final String id,
    required final String title,
    required final int orderIndex,
    required final VideoStatus status,
    final int? durationMs,
  }) = _$CourseVideoSummaryImpl;

  factory _CourseVideoSummary.fromJson(Map<String, dynamic> json) =
      _$CourseVideoSummaryImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  int get orderIndex;
  @override
  VideoStatus get status;
  @override
  int? get durationMs;

  /// Create a copy of CourseVideoSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseVideoSummaryImplCopyWith<_$CourseVideoSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlaybackInfo _$PlaybackInfoFromJson(Map<String, dynamic> json) {
  return _PlaybackInfo.fromJson(json);
}

/// @nodoc
mixin _$PlaybackInfo {
  String get masterPlaylistUrl => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;
  List<CaptionTrack> get captions => throw _privateConstructorUsedError;
  String? get defaultCaptionLanguage => throw _privateConstructorUsedError;

  /// Serializes this PlaybackInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlaybackInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlaybackInfoCopyWith<PlaybackInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlaybackInfoCopyWith<$Res> {
  factory $PlaybackInfoCopyWith(
    PlaybackInfo value,
    $Res Function(PlaybackInfo) then,
  ) = _$PlaybackInfoCopyWithImpl<$Res, PlaybackInfo>;
  @useResult
  $Res call({
    String masterPlaylistUrl,
    DateTime expiresAt,
    List<CaptionTrack> captions,
    String? defaultCaptionLanguage,
  });
}

/// @nodoc
class _$PlaybackInfoCopyWithImpl<$Res, $Val extends PlaybackInfo>
    implements $PlaybackInfoCopyWith<$Res> {
  _$PlaybackInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlaybackInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? masterPlaylistUrl = null,
    Object? expiresAt = null,
    Object? captions = null,
    Object? defaultCaptionLanguage = freezed,
  }) {
    return _then(
      _value.copyWith(
            masterPlaylistUrl: null == masterPlaylistUrl
                ? _value.masterPlaylistUrl
                : masterPlaylistUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            captions: null == captions
                ? _value.captions
                : captions // ignore: cast_nullable_to_non_nullable
                      as List<CaptionTrack>,
            defaultCaptionLanguage: freezed == defaultCaptionLanguage
                ? _value.defaultCaptionLanguage
                : defaultCaptionLanguage // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlaybackInfoImplCopyWith<$Res>
    implements $PlaybackInfoCopyWith<$Res> {
  factory _$$PlaybackInfoImplCopyWith(
    _$PlaybackInfoImpl value,
    $Res Function(_$PlaybackInfoImpl) then,
  ) = __$$PlaybackInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String masterPlaylistUrl,
    DateTime expiresAt,
    List<CaptionTrack> captions,
    String? defaultCaptionLanguage,
  });
}

/// @nodoc
class __$$PlaybackInfoImplCopyWithImpl<$Res>
    extends _$PlaybackInfoCopyWithImpl<$Res, _$PlaybackInfoImpl>
    implements _$$PlaybackInfoImplCopyWith<$Res> {
  __$$PlaybackInfoImplCopyWithImpl(
    _$PlaybackInfoImpl _value,
    $Res Function(_$PlaybackInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlaybackInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? masterPlaylistUrl = null,
    Object? expiresAt = null,
    Object? captions = null,
    Object? defaultCaptionLanguage = freezed,
  }) {
    return _then(
      _$PlaybackInfoImpl(
        masterPlaylistUrl: null == masterPlaylistUrl
            ? _value.masterPlaylistUrl
            : masterPlaylistUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        captions: null == captions
            ? _value._captions
            : captions // ignore: cast_nullable_to_non_nullable
                  as List<CaptionTrack>,
        defaultCaptionLanguage: freezed == defaultCaptionLanguage
            ? _value.defaultCaptionLanguage
            : defaultCaptionLanguage // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlaybackInfoImpl implements _PlaybackInfo {
  const _$PlaybackInfoImpl({
    required this.masterPlaylistUrl,
    required this.expiresAt,
    final List<CaptionTrack> captions = const <CaptionTrack>[],
    this.defaultCaptionLanguage,
  }) : _captions = captions;

  factory _$PlaybackInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlaybackInfoImplFromJson(json);

  @override
  final String masterPlaylistUrl;
  @override
  final DateTime expiresAt;
  final List<CaptionTrack> _captions;
  @override
  @JsonKey()
  List<CaptionTrack> get captions {
    if (_captions is EqualUnmodifiableListView) return _captions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_captions);
  }

  @override
  final String? defaultCaptionLanguage;

  @override
  String toString() {
    return 'PlaybackInfo(masterPlaylistUrl: $masterPlaylistUrl, expiresAt: $expiresAt, captions: $captions, defaultCaptionLanguage: $defaultCaptionLanguage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlaybackInfoImpl &&
            (identical(other.masterPlaylistUrl, masterPlaylistUrl) ||
                other.masterPlaylistUrl == masterPlaylistUrl) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            const DeepCollectionEquality().equals(other._captions, _captions) &&
            (identical(other.defaultCaptionLanguage, defaultCaptionLanguage) ||
                other.defaultCaptionLanguage == defaultCaptionLanguage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    masterPlaylistUrl,
    expiresAt,
    const DeepCollectionEquality().hash(_captions),
    defaultCaptionLanguage,
  );

  /// Create a copy of PlaybackInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlaybackInfoImplCopyWith<_$PlaybackInfoImpl> get copyWith =>
      __$$PlaybackInfoImplCopyWithImpl<_$PlaybackInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlaybackInfoImplToJson(this);
  }
}

abstract class _PlaybackInfo implements PlaybackInfo {
  const factory _PlaybackInfo({
    required final String masterPlaylistUrl,
    required final DateTime expiresAt,
    final List<CaptionTrack> captions,
    final String? defaultCaptionLanguage,
  }) = _$PlaybackInfoImpl;

  factory _PlaybackInfo.fromJson(Map<String, dynamic> json) =
      _$PlaybackInfoImpl.fromJson;

  @override
  String get masterPlaylistUrl;
  @override
  DateTime get expiresAt;
  @override
  List<CaptionTrack> get captions;
  @override
  String? get defaultCaptionLanguage;

  /// Create a copy of PlaybackInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlaybackInfoImplCopyWith<_$PlaybackInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VideoUploadTicket _$VideoUploadTicketFromJson(Map<String, dynamic> json) {
  return _VideoUploadTicket.fromJson(json);
}

/// @nodoc
mixin _$VideoUploadTicket {
  String get videoId => throw _privateConstructorUsedError;
  VideoSummary get video => throw _privateConstructorUsedError;
  String get uploadUrl => throw _privateConstructorUsedError;
  Map<String, String> get uploadHeaders => throw _privateConstructorUsedError;
  String get sourceKey => throw _privateConstructorUsedError;

  /// Serializes this VideoUploadTicket to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VideoUploadTicket
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VideoUploadTicketCopyWith<VideoUploadTicket> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoUploadTicketCopyWith<$Res> {
  factory $VideoUploadTicketCopyWith(
    VideoUploadTicket value,
    $Res Function(VideoUploadTicket) then,
  ) = _$VideoUploadTicketCopyWithImpl<$Res, VideoUploadTicket>;
  @useResult
  $Res call({
    String videoId,
    VideoSummary video,
    String uploadUrl,
    Map<String, String> uploadHeaders,
    String sourceKey,
  });

  $VideoSummaryCopyWith<$Res> get video;
}

/// @nodoc
class _$VideoUploadTicketCopyWithImpl<$Res, $Val extends VideoUploadTicket>
    implements $VideoUploadTicketCopyWith<$Res> {
  _$VideoUploadTicketCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VideoUploadTicket
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? video = null,
    Object? uploadUrl = null,
    Object? uploadHeaders = null,
    Object? sourceKey = null,
  }) {
    return _then(
      _value.copyWith(
            videoId: null == videoId
                ? _value.videoId
                : videoId // ignore: cast_nullable_to_non_nullable
                      as String,
            video: null == video
                ? _value.video
                : video // ignore: cast_nullable_to_non_nullable
                      as VideoSummary,
            uploadUrl: null == uploadUrl
                ? _value.uploadUrl
                : uploadUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            uploadHeaders: null == uploadHeaders
                ? _value.uploadHeaders
                : uploadHeaders // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
            sourceKey: null == sourceKey
                ? _value.sourceKey
                : sourceKey // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }

  /// Create a copy of VideoUploadTicket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VideoSummaryCopyWith<$Res> get video {
    return $VideoSummaryCopyWith<$Res>(_value.video, (value) {
      return _then(_value.copyWith(video: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$VideoUploadTicketImplCopyWith<$Res>
    implements $VideoUploadTicketCopyWith<$Res> {
  factory _$$VideoUploadTicketImplCopyWith(
    _$VideoUploadTicketImpl value,
    $Res Function(_$VideoUploadTicketImpl) then,
  ) = __$$VideoUploadTicketImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String videoId,
    VideoSummary video,
    String uploadUrl,
    Map<String, String> uploadHeaders,
    String sourceKey,
  });

  @override
  $VideoSummaryCopyWith<$Res> get video;
}

/// @nodoc
class __$$VideoUploadTicketImplCopyWithImpl<$Res>
    extends _$VideoUploadTicketCopyWithImpl<$Res, _$VideoUploadTicketImpl>
    implements _$$VideoUploadTicketImplCopyWith<$Res> {
  __$$VideoUploadTicketImplCopyWithImpl(
    _$VideoUploadTicketImpl _value,
    $Res Function(_$VideoUploadTicketImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VideoUploadTicket
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? video = null,
    Object? uploadUrl = null,
    Object? uploadHeaders = null,
    Object? sourceKey = null,
  }) {
    return _then(
      _$VideoUploadTicketImpl(
        videoId: null == videoId
            ? _value.videoId
            : videoId // ignore: cast_nullable_to_non_nullable
                  as String,
        video: null == video
            ? _value.video
            : video // ignore: cast_nullable_to_non_nullable
                  as VideoSummary,
        uploadUrl: null == uploadUrl
            ? _value.uploadUrl
            : uploadUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        uploadHeaders: null == uploadHeaders
            ? _value._uploadHeaders
            : uploadHeaders // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
        sourceKey: null == sourceKey
            ? _value.sourceKey
            : sourceKey // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VideoUploadTicketImpl implements _VideoUploadTicket {
  const _$VideoUploadTicketImpl({
    required this.videoId,
    required this.video,
    required this.uploadUrl,
    required final Map<String, String> uploadHeaders,
    required this.sourceKey,
  }) : _uploadHeaders = uploadHeaders;

  factory _$VideoUploadTicketImpl.fromJson(Map<String, dynamic> json) =>
      _$$VideoUploadTicketImplFromJson(json);

  @override
  final String videoId;
  @override
  final VideoSummary video;
  @override
  final String uploadUrl;
  final Map<String, String> _uploadHeaders;
  @override
  Map<String, String> get uploadHeaders {
    if (_uploadHeaders is EqualUnmodifiableMapView) return _uploadHeaders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_uploadHeaders);
  }

  @override
  final String sourceKey;

  @override
  String toString() {
    return 'VideoUploadTicket(videoId: $videoId, video: $video, uploadUrl: $uploadUrl, uploadHeaders: $uploadHeaders, sourceKey: $sourceKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoUploadTicketImpl &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.video, video) || other.video == video) &&
            (identical(other.uploadUrl, uploadUrl) ||
                other.uploadUrl == uploadUrl) &&
            const DeepCollectionEquality().equals(
              other._uploadHeaders,
              _uploadHeaders,
            ) &&
            (identical(other.sourceKey, sourceKey) ||
                other.sourceKey == sourceKey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    videoId,
    video,
    uploadUrl,
    const DeepCollectionEquality().hash(_uploadHeaders),
    sourceKey,
  );

  /// Create a copy of VideoUploadTicket
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoUploadTicketImplCopyWith<_$VideoUploadTicketImpl> get copyWith =>
      __$$VideoUploadTicketImplCopyWithImpl<_$VideoUploadTicketImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$VideoUploadTicketImplToJson(this);
  }
}

abstract class _VideoUploadTicket implements VideoUploadTicket {
  const factory _VideoUploadTicket({
    required final String videoId,
    required final VideoSummary video,
    required final String uploadUrl,
    required final Map<String, String> uploadHeaders,
    required final String sourceKey,
  }) = _$VideoUploadTicketImpl;

  factory _VideoUploadTicket.fromJson(Map<String, dynamic> json) =
      _$VideoUploadTicketImpl.fromJson;

  @override
  String get videoId;
  @override
  VideoSummary get video;
  @override
  String get uploadUrl;
  @override
  Map<String, String> get uploadHeaders;
  @override
  String get sourceKey;

  /// Create a copy of VideoUploadTicket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VideoUploadTicketImplCopyWith<_$VideoUploadTicketImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
