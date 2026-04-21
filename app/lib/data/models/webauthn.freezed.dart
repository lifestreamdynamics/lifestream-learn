// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'webauthn.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WebauthnCredential _$WebauthnCredentialFromJson(Map<String, dynamic> json) {
  return _WebauthnCredential.fromJson(json);
}

/// @nodoc
mixin _$WebauthnCredential {
  String get id => throw _privateConstructorUsedError;
  String get credentialId => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get lastUsedAt => throw _privateConstructorUsedError;
  List<String> get transports => throw _privateConstructorUsedError;
  String? get aaguid => throw _privateConstructorUsedError;

  /// Serializes this WebauthnCredential to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WebauthnCredential
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WebauthnCredentialCopyWith<WebauthnCredential> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WebauthnCredentialCopyWith<$Res> {
  factory $WebauthnCredentialCopyWith(
    WebauthnCredential value,
    $Res Function(WebauthnCredential) then,
  ) = _$WebauthnCredentialCopyWithImpl<$Res, WebauthnCredential>;
  @useResult
  $Res call({
    String id,
    String credentialId,
    String? label,
    DateTime createdAt,
    DateTime? lastUsedAt,
    List<String> transports,
    String? aaguid,
  });
}

/// @nodoc
class _$WebauthnCredentialCopyWithImpl<$Res, $Val extends WebauthnCredential>
    implements $WebauthnCredentialCopyWith<$Res> {
  _$WebauthnCredentialCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WebauthnCredential
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? credentialId = null,
    Object? label = freezed,
    Object? createdAt = null,
    Object? lastUsedAt = freezed,
    Object? transports = null,
    Object? aaguid = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            credentialId: null == credentialId
                ? _value.credentialId
                : credentialId // ignore: cast_nullable_to_non_nullable
                      as String,
            label: freezed == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            lastUsedAt: freezed == lastUsedAt
                ? _value.lastUsedAt
                : lastUsedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            transports: null == transports
                ? _value.transports
                : transports // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            aaguid: freezed == aaguid
                ? _value.aaguid
                : aaguid // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WebauthnCredentialImplCopyWith<$Res>
    implements $WebauthnCredentialCopyWith<$Res> {
  factory _$$WebauthnCredentialImplCopyWith(
    _$WebauthnCredentialImpl value,
    $Res Function(_$WebauthnCredentialImpl) then,
  ) = __$$WebauthnCredentialImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String credentialId,
    String? label,
    DateTime createdAt,
    DateTime? lastUsedAt,
    List<String> transports,
    String? aaguid,
  });
}

/// @nodoc
class __$$WebauthnCredentialImplCopyWithImpl<$Res>
    extends _$WebauthnCredentialCopyWithImpl<$Res, _$WebauthnCredentialImpl>
    implements _$$WebauthnCredentialImplCopyWith<$Res> {
  __$$WebauthnCredentialImplCopyWithImpl(
    _$WebauthnCredentialImpl _value,
    $Res Function(_$WebauthnCredentialImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WebauthnCredential
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? credentialId = null,
    Object? label = freezed,
    Object? createdAt = null,
    Object? lastUsedAt = freezed,
    Object? transports = null,
    Object? aaguid = freezed,
  }) {
    return _then(
      _$WebauthnCredentialImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        credentialId: null == credentialId
            ? _value.credentialId
            : credentialId // ignore: cast_nullable_to_non_nullable
                  as String,
        label: freezed == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        lastUsedAt: freezed == lastUsedAt
            ? _value.lastUsedAt
            : lastUsedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        transports: null == transports
            ? _value._transports
            : transports // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        aaguid: freezed == aaguid
            ? _value.aaguid
            : aaguid // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WebauthnCredentialImpl implements _WebauthnCredential {
  const _$WebauthnCredentialImpl({
    required this.id,
    required this.credentialId,
    this.label,
    required this.createdAt,
    this.lastUsedAt,
    final List<String> transports = const <String>[],
    this.aaguid,
  }) : _transports = transports;

  factory _$WebauthnCredentialImpl.fromJson(Map<String, dynamic> json) =>
      _$$WebauthnCredentialImplFromJson(json);

  @override
  final String id;
  @override
  final String credentialId;
  @override
  final String? label;
  @override
  final DateTime createdAt;
  @override
  final DateTime? lastUsedAt;
  final List<String> _transports;
  @override
  @JsonKey()
  List<String> get transports {
    if (_transports is EqualUnmodifiableListView) return _transports;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_transports);
  }

  @override
  final String? aaguid;

  @override
  String toString() {
    return 'WebauthnCredential(id: $id, credentialId: $credentialId, label: $label, createdAt: $createdAt, lastUsedAt: $lastUsedAt, transports: $transports, aaguid: $aaguid)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WebauthnCredentialImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.credentialId, credentialId) ||
                other.credentialId == credentialId) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastUsedAt, lastUsedAt) ||
                other.lastUsedAt == lastUsedAt) &&
            const DeepCollectionEquality().equals(
              other._transports,
              _transports,
            ) &&
            (identical(other.aaguid, aaguid) || other.aaguid == aaguid));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    credentialId,
    label,
    createdAt,
    lastUsedAt,
    const DeepCollectionEquality().hash(_transports),
    aaguid,
  );

  /// Create a copy of WebauthnCredential
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WebauthnCredentialImplCopyWith<_$WebauthnCredentialImpl> get copyWith =>
      __$$WebauthnCredentialImplCopyWithImpl<_$WebauthnCredentialImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WebauthnCredentialImplToJson(this);
  }
}

abstract class _WebauthnCredential implements WebauthnCredential {
  const factory _WebauthnCredential({
    required final String id,
    required final String credentialId,
    final String? label,
    required final DateTime createdAt,
    final DateTime? lastUsedAt,
    final List<String> transports,
    final String? aaguid,
  }) = _$WebauthnCredentialImpl;

  factory _WebauthnCredential.fromJson(Map<String, dynamic> json) =
      _$WebauthnCredentialImpl.fromJson;

  @override
  String get id;
  @override
  String get credentialId;
  @override
  String? get label;
  @override
  DateTime get createdAt;
  @override
  DateTime? get lastUsedAt;
  @override
  List<String> get transports;
  @override
  String? get aaguid;

  /// Create a copy of WebauthnCredential
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WebauthnCredentialImplCopyWith<_$WebauthnCredentialImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WebauthnRegistrationOptions _$WebauthnRegistrationOptionsFromJson(
  Map<String, dynamic> json,
) {
  return _WebauthnRegistrationOptions.fromJson(json);
}

/// @nodoc
mixin _$WebauthnRegistrationOptions {
  Map<String, dynamic> get options => throw _privateConstructorUsedError;
  String get pendingToken => throw _privateConstructorUsedError;

  /// Serializes this WebauthnRegistrationOptions to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WebauthnRegistrationOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WebauthnRegistrationOptionsCopyWith<WebauthnRegistrationOptions>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WebauthnRegistrationOptionsCopyWith<$Res> {
  factory $WebauthnRegistrationOptionsCopyWith(
    WebauthnRegistrationOptions value,
    $Res Function(WebauthnRegistrationOptions) then,
  ) =
      _$WebauthnRegistrationOptionsCopyWithImpl<
        $Res,
        WebauthnRegistrationOptions
      >;
  @useResult
  $Res call({Map<String, dynamic> options, String pendingToken});
}

/// @nodoc
class _$WebauthnRegistrationOptionsCopyWithImpl<
  $Res,
  $Val extends WebauthnRegistrationOptions
>
    implements $WebauthnRegistrationOptionsCopyWith<$Res> {
  _$WebauthnRegistrationOptionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WebauthnRegistrationOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? options = null, Object? pendingToken = null}) {
    return _then(
      _value.copyWith(
            options: null == options
                ? _value.options
                : options // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            pendingToken: null == pendingToken
                ? _value.pendingToken
                : pendingToken // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WebauthnRegistrationOptionsImplCopyWith<$Res>
    implements $WebauthnRegistrationOptionsCopyWith<$Res> {
  factory _$$WebauthnRegistrationOptionsImplCopyWith(
    _$WebauthnRegistrationOptionsImpl value,
    $Res Function(_$WebauthnRegistrationOptionsImpl) then,
  ) = __$$WebauthnRegistrationOptionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<String, dynamic> options, String pendingToken});
}

/// @nodoc
class __$$WebauthnRegistrationOptionsImplCopyWithImpl<$Res>
    extends
        _$WebauthnRegistrationOptionsCopyWithImpl<
          $Res,
          _$WebauthnRegistrationOptionsImpl
        >
    implements _$$WebauthnRegistrationOptionsImplCopyWith<$Res> {
  __$$WebauthnRegistrationOptionsImplCopyWithImpl(
    _$WebauthnRegistrationOptionsImpl _value,
    $Res Function(_$WebauthnRegistrationOptionsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WebauthnRegistrationOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? options = null, Object? pendingToken = null}) {
    return _then(
      _$WebauthnRegistrationOptionsImpl(
        options: null == options
            ? _value._options
            : options // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        pendingToken: null == pendingToken
            ? _value.pendingToken
            : pendingToken // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WebauthnRegistrationOptionsImpl
    implements _WebauthnRegistrationOptions {
  const _$WebauthnRegistrationOptionsImpl({
    required final Map<String, dynamic> options,
    required this.pendingToken,
  }) : _options = options;

  factory _$WebauthnRegistrationOptionsImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$WebauthnRegistrationOptionsImplFromJson(json);

  final Map<String, dynamic> _options;
  @override
  Map<String, dynamic> get options {
    if (_options is EqualUnmodifiableMapView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_options);
  }

  @override
  final String pendingToken;

  @override
  String toString() {
    return 'WebauthnRegistrationOptions(options: $options, pendingToken: $pendingToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WebauthnRegistrationOptionsImpl &&
            const DeepCollectionEquality().equals(other._options, _options) &&
            (identical(other.pendingToken, pendingToken) ||
                other.pendingToken == pendingToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_options),
    pendingToken,
  );

  /// Create a copy of WebauthnRegistrationOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WebauthnRegistrationOptionsImplCopyWith<_$WebauthnRegistrationOptionsImpl>
  get copyWith =>
      __$$WebauthnRegistrationOptionsImplCopyWithImpl<
        _$WebauthnRegistrationOptionsImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WebauthnRegistrationOptionsImplToJson(this);
  }
}

abstract class _WebauthnRegistrationOptions
    implements WebauthnRegistrationOptions {
  const factory _WebauthnRegistrationOptions({
    required final Map<String, dynamic> options,
    required final String pendingToken,
  }) = _$WebauthnRegistrationOptionsImpl;

  factory _WebauthnRegistrationOptions.fromJson(Map<String, dynamic> json) =
      _$WebauthnRegistrationOptionsImpl.fromJson;

  @override
  Map<String, dynamic> get options;
  @override
  String get pendingToken;

  /// Create a copy of WebauthnRegistrationOptions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WebauthnRegistrationOptionsImplCopyWith<_$WebauthnRegistrationOptionsImpl>
  get copyWith => throw _privateConstructorUsedError;
}

WebauthnAssertionOptions _$WebauthnAssertionOptionsFromJson(
  Map<String, dynamic> json,
) {
  return _WebauthnAssertionOptions.fromJson(json);
}

/// @nodoc
mixin _$WebauthnAssertionOptions {
  Map<String, dynamic> get options => throw _privateConstructorUsedError;
  String get challengeToken => throw _privateConstructorUsedError;

  /// Serializes this WebauthnAssertionOptions to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WebauthnAssertionOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WebauthnAssertionOptionsCopyWith<WebauthnAssertionOptions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WebauthnAssertionOptionsCopyWith<$Res> {
  factory $WebauthnAssertionOptionsCopyWith(
    WebauthnAssertionOptions value,
    $Res Function(WebauthnAssertionOptions) then,
  ) = _$WebauthnAssertionOptionsCopyWithImpl<$Res, WebauthnAssertionOptions>;
  @useResult
  $Res call({Map<String, dynamic> options, String challengeToken});
}

/// @nodoc
class _$WebauthnAssertionOptionsCopyWithImpl<
  $Res,
  $Val extends WebauthnAssertionOptions
>
    implements $WebauthnAssertionOptionsCopyWith<$Res> {
  _$WebauthnAssertionOptionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WebauthnAssertionOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? options = null, Object? challengeToken = null}) {
    return _then(
      _value.copyWith(
            options: null == options
                ? _value.options
                : options // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            challengeToken: null == challengeToken
                ? _value.challengeToken
                : challengeToken // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WebauthnAssertionOptionsImplCopyWith<$Res>
    implements $WebauthnAssertionOptionsCopyWith<$Res> {
  factory _$$WebauthnAssertionOptionsImplCopyWith(
    _$WebauthnAssertionOptionsImpl value,
    $Res Function(_$WebauthnAssertionOptionsImpl) then,
  ) = __$$WebauthnAssertionOptionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<String, dynamic> options, String challengeToken});
}

/// @nodoc
class __$$WebauthnAssertionOptionsImplCopyWithImpl<$Res>
    extends
        _$WebauthnAssertionOptionsCopyWithImpl<
          $Res,
          _$WebauthnAssertionOptionsImpl
        >
    implements _$$WebauthnAssertionOptionsImplCopyWith<$Res> {
  __$$WebauthnAssertionOptionsImplCopyWithImpl(
    _$WebauthnAssertionOptionsImpl _value,
    $Res Function(_$WebauthnAssertionOptionsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WebauthnAssertionOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? options = null, Object? challengeToken = null}) {
    return _then(
      _$WebauthnAssertionOptionsImpl(
        options: null == options
            ? _value._options
            : options // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        challengeToken: null == challengeToken
            ? _value.challengeToken
            : challengeToken // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WebauthnAssertionOptionsImpl implements _WebauthnAssertionOptions {
  const _$WebauthnAssertionOptionsImpl({
    required final Map<String, dynamic> options,
    required this.challengeToken,
  }) : _options = options;

  factory _$WebauthnAssertionOptionsImpl.fromJson(Map<String, dynamic> json) =>
      _$$WebauthnAssertionOptionsImplFromJson(json);

  final Map<String, dynamic> _options;
  @override
  Map<String, dynamic> get options {
    if (_options is EqualUnmodifiableMapView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_options);
  }

  @override
  final String challengeToken;

  @override
  String toString() {
    return 'WebauthnAssertionOptions(options: $options, challengeToken: $challengeToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WebauthnAssertionOptionsImpl &&
            const DeepCollectionEquality().equals(other._options, _options) &&
            (identical(other.challengeToken, challengeToken) ||
                other.challengeToken == challengeToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_options),
    challengeToken,
  );

  /// Create a copy of WebauthnAssertionOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WebauthnAssertionOptionsImplCopyWith<_$WebauthnAssertionOptionsImpl>
  get copyWith =>
      __$$WebauthnAssertionOptionsImplCopyWithImpl<
        _$WebauthnAssertionOptionsImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WebauthnAssertionOptionsImplToJson(this);
  }
}

abstract class _WebauthnAssertionOptions implements WebauthnAssertionOptions {
  const factory _WebauthnAssertionOptions({
    required final Map<String, dynamic> options,
    required final String challengeToken,
  }) = _$WebauthnAssertionOptionsImpl;

  factory _WebauthnAssertionOptions.fromJson(Map<String, dynamic> json) =
      _$WebauthnAssertionOptionsImpl.fromJson;

  @override
  Map<String, dynamic> get options;
  @override
  String get challengeToken;

  /// Create a copy of WebauthnAssertionOptions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WebauthnAssertionOptionsImplCopyWith<_$WebauthnAssertionOptionsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
