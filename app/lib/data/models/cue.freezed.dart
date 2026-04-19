// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cue.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Cue _$CueFromJson(Map<String, dynamic> json) {
  return _Cue.fromJson(json);
}

/// @nodoc
mixin _$Cue {
  String get id => throw _privateConstructorUsedError;
  String get videoId => throw _privateConstructorUsedError;
  int get atMs => throw _privateConstructorUsedError;
  bool get pause => throw _privateConstructorUsedError;
  CueType get type => throw _privateConstructorUsedError;
  Map<String, dynamic> get payload => throw _privateConstructorUsedError;
  int get orderIndex => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Cue to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Cue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CueCopyWith<Cue> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CueCopyWith<$Res> {
  factory $CueCopyWith(Cue value, $Res Function(Cue) then) =
      _$CueCopyWithImpl<$Res, Cue>;
  @useResult
  $Res call({
    String id,
    String videoId,
    int atMs,
    bool pause,
    CueType type,
    Map<String, dynamic> payload,
    int orderIndex,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$CueCopyWithImpl<$Res, $Val extends Cue> implements $CueCopyWith<$Res> {
  _$CueCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Cue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? videoId = null,
    Object? atMs = null,
    Object? pause = null,
    Object? type = null,
    Object? payload = null,
    Object? orderIndex = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            videoId: null == videoId
                ? _value.videoId
                : videoId // ignore: cast_nullable_to_non_nullable
                      as String,
            atMs: null == atMs
                ? _value.atMs
                : atMs // ignore: cast_nullable_to_non_nullable
                      as int,
            pause: null == pause
                ? _value.pause
                : pause // ignore: cast_nullable_to_non_nullable
                      as bool,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as CueType,
            payload: null == payload
                ? _value.payload
                : payload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            orderIndex: null == orderIndex
                ? _value.orderIndex
                : orderIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CueImplCopyWith<$Res> implements $CueCopyWith<$Res> {
  factory _$$CueImplCopyWith(_$CueImpl value, $Res Function(_$CueImpl) then) =
      __$$CueImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String videoId,
    int atMs,
    bool pause,
    CueType type,
    Map<String, dynamic> payload,
    int orderIndex,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$CueImplCopyWithImpl<$Res> extends _$CueCopyWithImpl<$Res, _$CueImpl>
    implements _$$CueImplCopyWith<$Res> {
  __$$CueImplCopyWithImpl(_$CueImpl _value, $Res Function(_$CueImpl) _then)
    : super(_value, _then);

  /// Create a copy of Cue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? videoId = null,
    Object? atMs = null,
    Object? pause = null,
    Object? type = null,
    Object? payload = null,
    Object? orderIndex = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$CueImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        videoId: null == videoId
            ? _value.videoId
            : videoId // ignore: cast_nullable_to_non_nullable
                  as String,
        atMs: null == atMs
            ? _value.atMs
            : atMs // ignore: cast_nullable_to_non_nullable
                  as int,
        pause: null == pause
            ? _value.pause
            : pause // ignore: cast_nullable_to_non_nullable
                  as bool,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as CueType,
        payload: null == payload
            ? _value._payload
            : payload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        orderIndex: null == orderIndex
            ? _value.orderIndex
            : orderIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CueImpl implements _Cue {
  const _$CueImpl({
    required this.id,
    required this.videoId,
    required this.atMs,
    required this.pause,
    required this.type,
    required final Map<String, dynamic> payload,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  }) : _payload = payload;

  factory _$CueImpl.fromJson(Map<String, dynamic> json) =>
      _$$CueImplFromJson(json);

  @override
  final String id;
  @override
  final String videoId;
  @override
  final int atMs;
  @override
  final bool pause;
  @override
  final CueType type;
  final Map<String, dynamic> _payload;
  @override
  Map<String, dynamic> get payload {
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_payload);
  }

  @override
  final int orderIndex;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Cue(id: $id, videoId: $videoId, atMs: $atMs, pause: $pause, type: $type, payload: $payload, orderIndex: $orderIndex, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CueImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.atMs, atMs) || other.atMs == atMs) &&
            (identical(other.pause, pause) || other.pause == pause) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._payload, _payload) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
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
    videoId,
    atMs,
    pause,
    type,
    const DeepCollectionEquality().hash(_payload),
    orderIndex,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Cue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CueImplCopyWith<_$CueImpl> get copyWith =>
      __$$CueImplCopyWithImpl<_$CueImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CueImplToJson(this);
  }
}

abstract class _Cue implements Cue {
  const factory _Cue({
    required final String id,
    required final String videoId,
    required final int atMs,
    required final bool pause,
    required final CueType type,
    required final Map<String, dynamic> payload,
    required final int orderIndex,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$CueImpl;

  factory _Cue.fromJson(Map<String, dynamic> json) = _$CueImpl.fromJson;

  @override
  String get id;
  @override
  String get videoId;
  @override
  int get atMs;
  @override
  bool get pause;
  @override
  CueType get type;
  @override
  Map<String, dynamic> get payload;
  @override
  int get orderIndex;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Cue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CueImplCopyWith<_$CueImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Attempt _$AttemptFromJson(Map<String, dynamic> json) {
  return _Attempt.fromJson(json);
}

/// @nodoc
mixin _$Attempt {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get videoId => throw _privateConstructorUsedError;
  String get cueId => throw _privateConstructorUsedError;
  bool get correct => throw _privateConstructorUsedError;
  Map<String, dynamic>? get scoreJson => throw _privateConstructorUsedError;
  DateTime get submittedAt => throw _privateConstructorUsedError;

  /// Serializes this Attempt to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Attempt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttemptCopyWith<Attempt> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttemptCopyWith<$Res> {
  factory $AttemptCopyWith(Attempt value, $Res Function(Attempt) then) =
      _$AttemptCopyWithImpl<$Res, Attempt>;
  @useResult
  $Res call({
    String id,
    String userId,
    String videoId,
    String cueId,
    bool correct,
    Map<String, dynamic>? scoreJson,
    DateTime submittedAt,
  });
}

/// @nodoc
class _$AttemptCopyWithImpl<$Res, $Val extends Attempt>
    implements $AttemptCopyWith<$Res> {
  _$AttemptCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Attempt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? videoId = null,
    Object? cueId = null,
    Object? correct = null,
    Object? scoreJson = freezed,
    Object? submittedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            videoId: null == videoId
                ? _value.videoId
                : videoId // ignore: cast_nullable_to_non_nullable
                      as String,
            cueId: null == cueId
                ? _value.cueId
                : cueId // ignore: cast_nullable_to_non_nullable
                      as String,
            correct: null == correct
                ? _value.correct
                : correct // ignore: cast_nullable_to_non_nullable
                      as bool,
            scoreJson: freezed == scoreJson
                ? _value.scoreJson
                : scoreJson // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            submittedAt: null == submittedAt
                ? _value.submittedAt
                : submittedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttemptImplCopyWith<$Res> implements $AttemptCopyWith<$Res> {
  factory _$$AttemptImplCopyWith(
    _$AttemptImpl value,
    $Res Function(_$AttemptImpl) then,
  ) = __$$AttemptImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String videoId,
    String cueId,
    bool correct,
    Map<String, dynamic>? scoreJson,
    DateTime submittedAt,
  });
}

/// @nodoc
class __$$AttemptImplCopyWithImpl<$Res>
    extends _$AttemptCopyWithImpl<$Res, _$AttemptImpl>
    implements _$$AttemptImplCopyWith<$Res> {
  __$$AttemptImplCopyWithImpl(
    _$AttemptImpl _value,
    $Res Function(_$AttemptImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Attempt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? videoId = null,
    Object? cueId = null,
    Object? correct = null,
    Object? scoreJson = freezed,
    Object? submittedAt = null,
  }) {
    return _then(
      _$AttemptImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        videoId: null == videoId
            ? _value.videoId
            : videoId // ignore: cast_nullable_to_non_nullable
                  as String,
        cueId: null == cueId
            ? _value.cueId
            : cueId // ignore: cast_nullable_to_non_nullable
                  as String,
        correct: null == correct
            ? _value.correct
            : correct // ignore: cast_nullable_to_non_nullable
                  as bool,
        scoreJson: freezed == scoreJson
            ? _value._scoreJson
            : scoreJson // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        submittedAt: null == submittedAt
            ? _value.submittedAt
            : submittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AttemptImpl implements _Attempt {
  const _$AttemptImpl({
    required this.id,
    required this.userId,
    required this.videoId,
    required this.cueId,
    required this.correct,
    final Map<String, dynamic>? scoreJson,
    required this.submittedAt,
  }) : _scoreJson = scoreJson;

  factory _$AttemptImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttemptImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String videoId;
  @override
  final String cueId;
  @override
  final bool correct;
  final Map<String, dynamic>? _scoreJson;
  @override
  Map<String, dynamic>? get scoreJson {
    final value = _scoreJson;
    if (value == null) return null;
    if (_scoreJson is EqualUnmodifiableMapView) return _scoreJson;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime submittedAt;

  @override
  String toString() {
    return 'Attempt(id: $id, userId: $userId, videoId: $videoId, cueId: $cueId, correct: $correct, scoreJson: $scoreJson, submittedAt: $submittedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttemptImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.cueId, cueId) || other.cueId == cueId) &&
            (identical(other.correct, correct) || other.correct == correct) &&
            const DeepCollectionEquality().equals(
              other._scoreJson,
              _scoreJson,
            ) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    videoId,
    cueId,
    correct,
    const DeepCollectionEquality().hash(_scoreJson),
    submittedAt,
  );

  /// Create a copy of Attempt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttemptImplCopyWith<_$AttemptImpl> get copyWith =>
      __$$AttemptImplCopyWithImpl<_$AttemptImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttemptImplToJson(this);
  }
}

abstract class _Attempt implements Attempt {
  const factory _Attempt({
    required final String id,
    required final String userId,
    required final String videoId,
    required final String cueId,
    required final bool correct,
    final Map<String, dynamic>? scoreJson,
    required final DateTime submittedAt,
  }) = _$AttemptImpl;

  factory _Attempt.fromJson(Map<String, dynamic> json) = _$AttemptImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get videoId;
  @override
  String get cueId;
  @override
  bool get correct;
  @override
  Map<String, dynamic>? get scoreJson;
  @override
  DateTime get submittedAt;

  /// Create a copy of Attempt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttemptImplCopyWith<_$AttemptImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AttemptResult _$AttemptResultFromJson(Map<String, dynamic> json) {
  return _AttemptResult.fromJson(json);
}

/// @nodoc
mixin _$AttemptResult {
  Attempt get attempt => throw _privateConstructorUsedError;
  bool get correct => throw _privateConstructorUsedError;
  Map<String, dynamic>? get scoreJson => throw _privateConstructorUsedError;
  String? get explanation => throw _privateConstructorUsedError;

  /// Serializes this AttemptResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AttemptResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttemptResultCopyWith<AttemptResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttemptResultCopyWith<$Res> {
  factory $AttemptResultCopyWith(
    AttemptResult value,
    $Res Function(AttemptResult) then,
  ) = _$AttemptResultCopyWithImpl<$Res, AttemptResult>;
  @useResult
  $Res call({
    Attempt attempt,
    bool correct,
    Map<String, dynamic>? scoreJson,
    String? explanation,
  });

  $AttemptCopyWith<$Res> get attempt;
}

/// @nodoc
class _$AttemptResultCopyWithImpl<$Res, $Val extends AttemptResult>
    implements $AttemptResultCopyWith<$Res> {
  _$AttemptResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttemptResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? attempt = null,
    Object? correct = null,
    Object? scoreJson = freezed,
    Object? explanation = freezed,
  }) {
    return _then(
      _value.copyWith(
            attempt: null == attempt
                ? _value.attempt
                : attempt // ignore: cast_nullable_to_non_nullable
                      as Attempt,
            correct: null == correct
                ? _value.correct
                : correct // ignore: cast_nullable_to_non_nullable
                      as bool,
            scoreJson: freezed == scoreJson
                ? _value.scoreJson
                : scoreJson // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            explanation: freezed == explanation
                ? _value.explanation
                : explanation // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of AttemptResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AttemptCopyWith<$Res> get attempt {
    return $AttemptCopyWith<$Res>(_value.attempt, (value) {
      return _then(_value.copyWith(attempt: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AttemptResultImplCopyWith<$Res>
    implements $AttemptResultCopyWith<$Res> {
  factory _$$AttemptResultImplCopyWith(
    _$AttemptResultImpl value,
    $Res Function(_$AttemptResultImpl) then,
  ) = __$$AttemptResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Attempt attempt,
    bool correct,
    Map<String, dynamic>? scoreJson,
    String? explanation,
  });

  @override
  $AttemptCopyWith<$Res> get attempt;
}

/// @nodoc
class __$$AttemptResultImplCopyWithImpl<$Res>
    extends _$AttemptResultCopyWithImpl<$Res, _$AttemptResultImpl>
    implements _$$AttemptResultImplCopyWith<$Res> {
  __$$AttemptResultImplCopyWithImpl(
    _$AttemptResultImpl _value,
    $Res Function(_$AttemptResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttemptResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? attempt = null,
    Object? correct = null,
    Object? scoreJson = freezed,
    Object? explanation = freezed,
  }) {
    return _then(
      _$AttemptResultImpl(
        attempt: null == attempt
            ? _value.attempt
            : attempt // ignore: cast_nullable_to_non_nullable
                  as Attempt,
        correct: null == correct
            ? _value.correct
            : correct // ignore: cast_nullable_to_non_nullable
                  as bool,
        scoreJson: freezed == scoreJson
            ? _value._scoreJson
            : scoreJson // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        explanation: freezed == explanation
            ? _value.explanation
            : explanation // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AttemptResultImpl implements _AttemptResult {
  const _$AttemptResultImpl({
    required this.attempt,
    required this.correct,
    final Map<String, dynamic>? scoreJson,
    this.explanation,
  }) : _scoreJson = scoreJson;

  factory _$AttemptResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttemptResultImplFromJson(json);

  @override
  final Attempt attempt;
  @override
  final bool correct;
  final Map<String, dynamic>? _scoreJson;
  @override
  Map<String, dynamic>? get scoreJson {
    final value = _scoreJson;
    if (value == null) return null;
    if (_scoreJson is EqualUnmodifiableMapView) return _scoreJson;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? explanation;

  @override
  String toString() {
    return 'AttemptResult(attempt: $attempt, correct: $correct, scoreJson: $scoreJson, explanation: $explanation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttemptResultImpl &&
            (identical(other.attempt, attempt) || other.attempt == attempt) &&
            (identical(other.correct, correct) || other.correct == correct) &&
            const DeepCollectionEquality().equals(
              other._scoreJson,
              _scoreJson,
            ) &&
            (identical(other.explanation, explanation) ||
                other.explanation == explanation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    attempt,
    correct,
    const DeepCollectionEquality().hash(_scoreJson),
    explanation,
  );

  /// Create a copy of AttemptResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttemptResultImplCopyWith<_$AttemptResultImpl> get copyWith =>
      __$$AttemptResultImplCopyWithImpl<_$AttemptResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttemptResultImplToJson(this);
  }
}

abstract class _AttemptResult implements AttemptResult {
  const factory _AttemptResult({
    required final Attempt attempt,
    required final bool correct,
    final Map<String, dynamic>? scoreJson,
    final String? explanation,
  }) = _$AttemptResultImpl;

  factory _AttemptResult.fromJson(Map<String, dynamic> json) =
      _$AttemptResultImpl.fromJson;

  @override
  Attempt get attempt;
  @override
  bool get correct;
  @override
  Map<String, dynamic>? get scoreJson;
  @override
  String? get explanation;

  /// Create a copy of AttemptResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttemptResultImplCopyWith<_$AttemptResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
