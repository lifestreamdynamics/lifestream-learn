// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mfa.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MfaMethods _$MfaMethodsFromJson(Map<String, dynamic> json) {
  return _MfaMethods.fromJson(json);
}

/// @nodoc
mixin _$MfaMethods {
  bool get totp => throw _privateConstructorUsedError;
  int get webauthnCount => throw _privateConstructorUsedError;
  bool get hasBackupCodes => throw _privateConstructorUsedError;
  int get backupCodesRemaining => throw _privateConstructorUsedError;

  /// Serializes this MfaMethods to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MfaMethods
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MfaMethodsCopyWith<MfaMethods> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MfaMethodsCopyWith<$Res> {
  factory $MfaMethodsCopyWith(
    MfaMethods value,
    $Res Function(MfaMethods) then,
  ) = _$MfaMethodsCopyWithImpl<$Res, MfaMethods>;
  @useResult
  $Res call({
    bool totp,
    int webauthnCount,
    bool hasBackupCodes,
    int backupCodesRemaining,
  });
}

/// @nodoc
class _$MfaMethodsCopyWithImpl<$Res, $Val extends MfaMethods>
    implements $MfaMethodsCopyWith<$Res> {
  _$MfaMethodsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MfaMethods
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totp = null,
    Object? webauthnCount = null,
    Object? hasBackupCodes = null,
    Object? backupCodesRemaining = null,
  }) {
    return _then(
      _value.copyWith(
            totp: null == totp
                ? _value.totp
                : totp // ignore: cast_nullable_to_non_nullable
                      as bool,
            webauthnCount: null == webauthnCount
                ? _value.webauthnCount
                : webauthnCount // ignore: cast_nullable_to_non_nullable
                      as int,
            hasBackupCodes: null == hasBackupCodes
                ? _value.hasBackupCodes
                : hasBackupCodes // ignore: cast_nullable_to_non_nullable
                      as bool,
            backupCodesRemaining: null == backupCodesRemaining
                ? _value.backupCodesRemaining
                : backupCodesRemaining // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MfaMethodsImplCopyWith<$Res>
    implements $MfaMethodsCopyWith<$Res> {
  factory _$$MfaMethodsImplCopyWith(
    _$MfaMethodsImpl value,
    $Res Function(_$MfaMethodsImpl) then,
  ) = __$$MfaMethodsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool totp,
    int webauthnCount,
    bool hasBackupCodes,
    int backupCodesRemaining,
  });
}

/// @nodoc
class __$$MfaMethodsImplCopyWithImpl<$Res>
    extends _$MfaMethodsCopyWithImpl<$Res, _$MfaMethodsImpl>
    implements _$$MfaMethodsImplCopyWith<$Res> {
  __$$MfaMethodsImplCopyWithImpl(
    _$MfaMethodsImpl _value,
    $Res Function(_$MfaMethodsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MfaMethods
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totp = null,
    Object? webauthnCount = null,
    Object? hasBackupCodes = null,
    Object? backupCodesRemaining = null,
  }) {
    return _then(
      _$MfaMethodsImpl(
        totp: null == totp
            ? _value.totp
            : totp // ignore: cast_nullable_to_non_nullable
                  as bool,
        webauthnCount: null == webauthnCount
            ? _value.webauthnCount
            : webauthnCount // ignore: cast_nullable_to_non_nullable
                  as int,
        hasBackupCodes: null == hasBackupCodes
            ? _value.hasBackupCodes
            : hasBackupCodes // ignore: cast_nullable_to_non_nullable
                  as bool,
        backupCodesRemaining: null == backupCodesRemaining
            ? _value.backupCodesRemaining
            : backupCodesRemaining // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MfaMethodsImpl implements _MfaMethods {
  const _$MfaMethodsImpl({
    required this.totp,
    this.webauthnCount = 0,
    this.hasBackupCodes = false,
    this.backupCodesRemaining = 0,
  });

  factory _$MfaMethodsImpl.fromJson(Map<String, dynamic> json) =>
      _$$MfaMethodsImplFromJson(json);

  @override
  final bool totp;
  @override
  @JsonKey()
  final int webauthnCount;
  @override
  @JsonKey()
  final bool hasBackupCodes;
  @override
  @JsonKey()
  final int backupCodesRemaining;

  @override
  String toString() {
    return 'MfaMethods(totp: $totp, webauthnCount: $webauthnCount, hasBackupCodes: $hasBackupCodes, backupCodesRemaining: $backupCodesRemaining)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MfaMethodsImpl &&
            (identical(other.totp, totp) || other.totp == totp) &&
            (identical(other.webauthnCount, webauthnCount) ||
                other.webauthnCount == webauthnCount) &&
            (identical(other.hasBackupCodes, hasBackupCodes) ||
                other.hasBackupCodes == hasBackupCodes) &&
            (identical(other.backupCodesRemaining, backupCodesRemaining) ||
                other.backupCodesRemaining == backupCodesRemaining));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    totp,
    webauthnCount,
    hasBackupCodes,
    backupCodesRemaining,
  );

  /// Create a copy of MfaMethods
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MfaMethodsImplCopyWith<_$MfaMethodsImpl> get copyWith =>
      __$$MfaMethodsImplCopyWithImpl<_$MfaMethodsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MfaMethodsImplToJson(this);
  }
}

abstract class _MfaMethods implements MfaMethods {
  const factory _MfaMethods({
    required final bool totp,
    final int webauthnCount,
    final bool hasBackupCodes,
    final int backupCodesRemaining,
  }) = _$MfaMethodsImpl;

  factory _MfaMethods.fromJson(Map<String, dynamic> json) =
      _$MfaMethodsImpl.fromJson;

  @override
  bool get totp;
  @override
  int get webauthnCount;
  @override
  bool get hasBackupCodes;
  @override
  int get backupCodesRemaining;

  /// Create a copy of MfaMethods
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MfaMethodsImplCopyWith<_$MfaMethodsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TotpEnrolmentStart _$TotpEnrolmentStartFromJson(Map<String, dynamic> json) {
  return _TotpEnrolmentStart.fromJson(json);
}

/// @nodoc
mixin _$TotpEnrolmentStart {
  String get secret => throw _privateConstructorUsedError;
  String get qrDataUrl => throw _privateConstructorUsedError;
  String get otpauthUrl => throw _privateConstructorUsedError;
  String get pendingEnrolmentToken => throw _privateConstructorUsedError;

  /// Serializes this TotpEnrolmentStart to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TotpEnrolmentStart
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TotpEnrolmentStartCopyWith<TotpEnrolmentStart> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TotpEnrolmentStartCopyWith<$Res> {
  factory $TotpEnrolmentStartCopyWith(
    TotpEnrolmentStart value,
    $Res Function(TotpEnrolmentStart) then,
  ) = _$TotpEnrolmentStartCopyWithImpl<$Res, TotpEnrolmentStart>;
  @useResult
  $Res call({
    String secret,
    String qrDataUrl,
    String otpauthUrl,
    String pendingEnrolmentToken,
  });
}

/// @nodoc
class _$TotpEnrolmentStartCopyWithImpl<$Res, $Val extends TotpEnrolmentStart>
    implements $TotpEnrolmentStartCopyWith<$Res> {
  _$TotpEnrolmentStartCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TotpEnrolmentStart
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? secret = null,
    Object? qrDataUrl = null,
    Object? otpauthUrl = null,
    Object? pendingEnrolmentToken = null,
  }) {
    return _then(
      _value.copyWith(
            secret: null == secret
                ? _value.secret
                : secret // ignore: cast_nullable_to_non_nullable
                      as String,
            qrDataUrl: null == qrDataUrl
                ? _value.qrDataUrl
                : qrDataUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            otpauthUrl: null == otpauthUrl
                ? _value.otpauthUrl
                : otpauthUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            pendingEnrolmentToken: null == pendingEnrolmentToken
                ? _value.pendingEnrolmentToken
                : pendingEnrolmentToken // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TotpEnrolmentStartImplCopyWith<$Res>
    implements $TotpEnrolmentStartCopyWith<$Res> {
  factory _$$TotpEnrolmentStartImplCopyWith(
    _$TotpEnrolmentStartImpl value,
    $Res Function(_$TotpEnrolmentStartImpl) then,
  ) = __$$TotpEnrolmentStartImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String secret,
    String qrDataUrl,
    String otpauthUrl,
    String pendingEnrolmentToken,
  });
}

/// @nodoc
class __$$TotpEnrolmentStartImplCopyWithImpl<$Res>
    extends _$TotpEnrolmentStartCopyWithImpl<$Res, _$TotpEnrolmentStartImpl>
    implements _$$TotpEnrolmentStartImplCopyWith<$Res> {
  __$$TotpEnrolmentStartImplCopyWithImpl(
    _$TotpEnrolmentStartImpl _value,
    $Res Function(_$TotpEnrolmentStartImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TotpEnrolmentStart
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? secret = null,
    Object? qrDataUrl = null,
    Object? otpauthUrl = null,
    Object? pendingEnrolmentToken = null,
  }) {
    return _then(
      _$TotpEnrolmentStartImpl(
        secret: null == secret
            ? _value.secret
            : secret // ignore: cast_nullable_to_non_nullable
                  as String,
        qrDataUrl: null == qrDataUrl
            ? _value.qrDataUrl
            : qrDataUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        otpauthUrl: null == otpauthUrl
            ? _value.otpauthUrl
            : otpauthUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        pendingEnrolmentToken: null == pendingEnrolmentToken
            ? _value.pendingEnrolmentToken
            : pendingEnrolmentToken // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TotpEnrolmentStartImpl implements _TotpEnrolmentStart {
  const _$TotpEnrolmentStartImpl({
    required this.secret,
    required this.qrDataUrl,
    required this.otpauthUrl,
    required this.pendingEnrolmentToken,
  });

  factory _$TotpEnrolmentStartImpl.fromJson(Map<String, dynamic> json) =>
      _$$TotpEnrolmentStartImplFromJson(json);

  @override
  final String secret;
  @override
  final String qrDataUrl;
  @override
  final String otpauthUrl;
  @override
  final String pendingEnrolmentToken;

  @override
  String toString() {
    return 'TotpEnrolmentStart(secret: $secret, qrDataUrl: $qrDataUrl, otpauthUrl: $otpauthUrl, pendingEnrolmentToken: $pendingEnrolmentToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TotpEnrolmentStartImpl &&
            (identical(other.secret, secret) || other.secret == secret) &&
            (identical(other.qrDataUrl, qrDataUrl) ||
                other.qrDataUrl == qrDataUrl) &&
            (identical(other.otpauthUrl, otpauthUrl) ||
                other.otpauthUrl == otpauthUrl) &&
            (identical(other.pendingEnrolmentToken, pendingEnrolmentToken) ||
                other.pendingEnrolmentToken == pendingEnrolmentToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    secret,
    qrDataUrl,
    otpauthUrl,
    pendingEnrolmentToken,
  );

  /// Create a copy of TotpEnrolmentStart
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TotpEnrolmentStartImplCopyWith<_$TotpEnrolmentStartImpl> get copyWith =>
      __$$TotpEnrolmentStartImplCopyWithImpl<_$TotpEnrolmentStartImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TotpEnrolmentStartImplToJson(this);
  }
}

abstract class _TotpEnrolmentStart implements TotpEnrolmentStart {
  const factory _TotpEnrolmentStart({
    required final String secret,
    required final String qrDataUrl,
    required final String otpauthUrl,
    required final String pendingEnrolmentToken,
  }) = _$TotpEnrolmentStartImpl;

  factory _TotpEnrolmentStart.fromJson(Map<String, dynamic> json) =
      _$TotpEnrolmentStartImpl.fromJson;

  @override
  String get secret;
  @override
  String get qrDataUrl;
  @override
  String get otpauthUrl;
  @override
  String get pendingEnrolmentToken;

  /// Create a copy of TotpEnrolmentStart
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TotpEnrolmentStartImplCopyWith<_$TotpEnrolmentStartImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TotpBackupCodesResponse _$TotpBackupCodesResponseFromJson(
  Map<String, dynamic> json,
) {
  return _TotpBackupCodesResponse.fromJson(json);
}

/// @nodoc
mixin _$TotpBackupCodesResponse {
  List<String> get backupCodes => throw _privateConstructorUsedError;

  /// Serializes this TotpBackupCodesResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TotpBackupCodesResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TotpBackupCodesResponseCopyWith<TotpBackupCodesResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TotpBackupCodesResponseCopyWith<$Res> {
  factory $TotpBackupCodesResponseCopyWith(
    TotpBackupCodesResponse value,
    $Res Function(TotpBackupCodesResponse) then,
  ) = _$TotpBackupCodesResponseCopyWithImpl<$Res, TotpBackupCodesResponse>;
  @useResult
  $Res call({List<String> backupCodes});
}

/// @nodoc
class _$TotpBackupCodesResponseCopyWithImpl<
  $Res,
  $Val extends TotpBackupCodesResponse
>
    implements $TotpBackupCodesResponseCopyWith<$Res> {
  _$TotpBackupCodesResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TotpBackupCodesResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? backupCodes = null}) {
    return _then(
      _value.copyWith(
            backupCodes: null == backupCodes
                ? _value.backupCodes
                : backupCodes // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TotpBackupCodesResponseImplCopyWith<$Res>
    implements $TotpBackupCodesResponseCopyWith<$Res> {
  factory _$$TotpBackupCodesResponseImplCopyWith(
    _$TotpBackupCodesResponseImpl value,
    $Res Function(_$TotpBackupCodesResponseImpl) then,
  ) = __$$TotpBackupCodesResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String> backupCodes});
}

/// @nodoc
class __$$TotpBackupCodesResponseImplCopyWithImpl<$Res>
    extends
        _$TotpBackupCodesResponseCopyWithImpl<
          $Res,
          _$TotpBackupCodesResponseImpl
        >
    implements _$$TotpBackupCodesResponseImplCopyWith<$Res> {
  __$$TotpBackupCodesResponseImplCopyWithImpl(
    _$TotpBackupCodesResponseImpl _value,
    $Res Function(_$TotpBackupCodesResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TotpBackupCodesResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? backupCodes = null}) {
    return _then(
      _$TotpBackupCodesResponseImpl(
        backupCodes: null == backupCodes
            ? _value._backupCodes
            : backupCodes // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TotpBackupCodesResponseImpl implements _TotpBackupCodesResponse {
  const _$TotpBackupCodesResponseImpl({required final List<String> backupCodes})
    : _backupCodes = backupCodes;

  factory _$TotpBackupCodesResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$TotpBackupCodesResponseImplFromJson(json);

  final List<String> _backupCodes;
  @override
  List<String> get backupCodes {
    if (_backupCodes is EqualUnmodifiableListView) return _backupCodes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_backupCodes);
  }

  @override
  String toString() {
    return 'TotpBackupCodesResponse(backupCodes: $backupCodes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TotpBackupCodesResponseImpl &&
            const DeepCollectionEquality().equals(
              other._backupCodes,
              _backupCodes,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_backupCodes),
  );

  /// Create a copy of TotpBackupCodesResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TotpBackupCodesResponseImplCopyWith<_$TotpBackupCodesResponseImpl>
  get copyWith =>
      __$$TotpBackupCodesResponseImplCopyWithImpl<
        _$TotpBackupCodesResponseImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TotpBackupCodesResponseImplToJson(this);
  }
}

abstract class _TotpBackupCodesResponse implements TotpBackupCodesResponse {
  const factory _TotpBackupCodesResponse({
    required final List<String> backupCodes,
  }) = _$TotpBackupCodesResponseImpl;

  factory _TotpBackupCodesResponse.fromJson(Map<String, dynamic> json) =
      _$TotpBackupCodesResponseImpl.fromJson;

  @override
  List<String> get backupCodes;

  /// Create a copy of TotpBackupCodesResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TotpBackupCodesResponseImplCopyWith<_$TotpBackupCodesResponseImpl>
  get copyWith => throw _privateConstructorUsedError;
}
