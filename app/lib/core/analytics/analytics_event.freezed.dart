// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AnalyticsEvent _$AnalyticsEventFromJson(Map<String, dynamic> json) {
  return _AnalyticsEvent.fromJson(json);
}

/// @nodoc
mixin _$AnalyticsEvent {
  String get eventType => throw _privateConstructorUsedError;
  String get occurredAt =>
      throw _privateConstructorUsedError; // Null-valued optional fields must be OMITTED from the JSON, not
  // serialized as `null`. The backend's Zod schema is `.strict()` and
  // its `.uuid().optional()` rejects an explicit `null` — `.optional()`
  // admits "key missing" / `undefined`, not `null`. Without this flag,
  // every session_start / session_end event 400s.
  @JsonKey(includeIfNull: false)
  String? get videoId => throw _privateConstructorUsedError;
  @JsonKey(includeIfNull: false)
  String? get cueId => throw _privateConstructorUsedError;
  @JsonKey(includeIfNull: false)
  Map<String, dynamic>? get payload => throw _privateConstructorUsedError;

  /// Serializes this AnalyticsEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalyticsEventCopyWith<AnalyticsEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalyticsEventCopyWith<$Res> {
  factory $AnalyticsEventCopyWith(
    AnalyticsEvent value,
    $Res Function(AnalyticsEvent) then,
  ) = _$AnalyticsEventCopyWithImpl<$Res, AnalyticsEvent>;
  @useResult
  $Res call({
    String eventType,
    String occurredAt,
    @JsonKey(includeIfNull: false) String? videoId,
    @JsonKey(includeIfNull: false) String? cueId,
    @JsonKey(includeIfNull: false) Map<String, dynamic>? payload,
  });
}

/// @nodoc
class _$AnalyticsEventCopyWithImpl<$Res, $Val extends AnalyticsEvent>
    implements $AnalyticsEventCopyWith<$Res> {
  _$AnalyticsEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventType = null,
    Object? occurredAt = null,
    Object? videoId = freezed,
    Object? cueId = freezed,
    Object? payload = freezed,
  }) {
    return _then(
      _value.copyWith(
            eventType: null == eventType
                ? _value.eventType
                : eventType // ignore: cast_nullable_to_non_nullable
                      as String,
            occurredAt: null == occurredAt
                ? _value.occurredAt
                : occurredAt // ignore: cast_nullable_to_non_nullable
                      as String,
            videoId: freezed == videoId
                ? _value.videoId
                : videoId // ignore: cast_nullable_to_non_nullable
                      as String?,
            cueId: freezed == cueId
                ? _value.cueId
                : cueId // ignore: cast_nullable_to_non_nullable
                      as String?,
            payload: freezed == payload
                ? _value.payload
                : payload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AnalyticsEventImplCopyWith<$Res>
    implements $AnalyticsEventCopyWith<$Res> {
  factory _$$AnalyticsEventImplCopyWith(
    _$AnalyticsEventImpl value,
    $Res Function(_$AnalyticsEventImpl) then,
  ) = __$$AnalyticsEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String eventType,
    String occurredAt,
    @JsonKey(includeIfNull: false) String? videoId,
    @JsonKey(includeIfNull: false) String? cueId,
    @JsonKey(includeIfNull: false) Map<String, dynamic>? payload,
  });
}

/// @nodoc
class __$$AnalyticsEventImplCopyWithImpl<$Res>
    extends _$AnalyticsEventCopyWithImpl<$Res, _$AnalyticsEventImpl>
    implements _$$AnalyticsEventImplCopyWith<$Res> {
  __$$AnalyticsEventImplCopyWithImpl(
    _$AnalyticsEventImpl _value,
    $Res Function(_$AnalyticsEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventType = null,
    Object? occurredAt = null,
    Object? videoId = freezed,
    Object? cueId = freezed,
    Object? payload = freezed,
  }) {
    return _then(
      _$AnalyticsEventImpl(
        eventType: null == eventType
            ? _value.eventType
            : eventType // ignore: cast_nullable_to_non_nullable
                  as String,
        occurredAt: null == occurredAt
            ? _value.occurredAt
            : occurredAt // ignore: cast_nullable_to_non_nullable
                  as String,
        videoId: freezed == videoId
            ? _value.videoId
            : videoId // ignore: cast_nullable_to_non_nullable
                  as String?,
        cueId: freezed == cueId
            ? _value.cueId
            : cueId // ignore: cast_nullable_to_non_nullable
                  as String?,
        payload: freezed == payload
            ? _value._payload
            : payload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AnalyticsEventImpl implements _AnalyticsEvent {
  const _$AnalyticsEventImpl({
    required this.eventType,
    required this.occurredAt,
    @JsonKey(includeIfNull: false) this.videoId,
    @JsonKey(includeIfNull: false) this.cueId,
    @JsonKey(includeIfNull: false) final Map<String, dynamic>? payload,
  }) : _payload = payload;

  factory _$AnalyticsEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnalyticsEventImplFromJson(json);

  @override
  final String eventType;
  @override
  final String occurredAt;
  // Null-valued optional fields must be OMITTED from the JSON, not
  // serialized as `null`. The backend's Zod schema is `.strict()` and
  // its `.uuid().optional()` rejects an explicit `null` — `.optional()`
  // admits "key missing" / `undefined`, not `null`. Without this flag,
  // every session_start / session_end event 400s.
  @override
  @JsonKey(includeIfNull: false)
  final String? videoId;
  @override
  @JsonKey(includeIfNull: false)
  final String? cueId;
  final Map<String, dynamic>? _payload;
  @override
  @JsonKey(includeIfNull: false)
  Map<String, dynamic>? get payload {
    final value = _payload;
    if (value == null) return null;
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'AnalyticsEvent(eventType: $eventType, occurredAt: $occurredAt, videoId: $videoId, cueId: $cueId, payload: $payload)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalyticsEventImpl &&
            (identical(other.eventType, eventType) ||
                other.eventType == eventType) &&
            (identical(other.occurredAt, occurredAt) ||
                other.occurredAt == occurredAt) &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.cueId, cueId) || other.cueId == cueId) &&
            const DeepCollectionEquality().equals(other._payload, _payload));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    eventType,
    occurredAt,
    videoId,
    cueId,
    const DeepCollectionEquality().hash(_payload),
  );

  /// Create a copy of AnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalyticsEventImplCopyWith<_$AnalyticsEventImpl> get copyWith =>
      __$$AnalyticsEventImplCopyWithImpl<_$AnalyticsEventImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AnalyticsEventImplToJson(this);
  }
}

abstract class _AnalyticsEvent implements AnalyticsEvent {
  const factory _AnalyticsEvent({
    required final String eventType,
    required final String occurredAt,
    @JsonKey(includeIfNull: false) final String? videoId,
    @JsonKey(includeIfNull: false) final String? cueId,
    @JsonKey(includeIfNull: false) final Map<String, dynamic>? payload,
  }) = _$AnalyticsEventImpl;

  factory _AnalyticsEvent.fromJson(Map<String, dynamic> json) =
      _$AnalyticsEventImpl.fromJson;

  @override
  String get eventType;
  @override
  String get occurredAt; // Null-valued optional fields must be OMITTED from the JSON, not
  // serialized as `null`. The backend's Zod schema is `.strict()` and
  // its `.uuid().optional()` rejects an explicit `null` — `.optional()`
  // admits "key missing" / `undefined`, not `null`. Without this flag,
  // every session_start / session_end event 400s.
  @override
  @JsonKey(includeIfNull: false)
  String? get videoId;
  @override
  @JsonKey(includeIfNull: false)
  String? get cueId;
  @override
  @JsonKey(includeIfNull: false)
  Map<String, dynamic>? get payload;

  /// Create a copy of AnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalyticsEventImplCopyWith<_$AnalyticsEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
