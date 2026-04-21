// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

User _$UserFromJson(Map<String, dynamic> json) {
  return _User.fromJson(json);
}

/// @nodoc
mixin _$User {
  String get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  UserRole get role =>
      throw _privateConstructorUsedError; // Slice P1 — profile screen additions. All optional on the client so
  // the model stays backward-compatible with older `/api/auth/me`
  // payloads (e.g. between rolling app + API upgrades).
  //
  // - `createdAt`: ISO-8601 string on the wire; freezed + json_serializable
  //   decode to a DateTime automatically.
  // - `avatarKey`: object-storage key, not a URL. The media-serving
  //   route arrives in a later slice; the ProfileHeader widget
  //   composes a display URL then. For now, a non-null key is a
  //   signal that an avatar exists; we still render initials.
  // - `useGravatar`: opt-in fallback flag (defaults off to match
  //   backend default).
  // - `preferences`: free-form bag (theme / playback / a11y) — Slice
  //   P4 introduces a strongly-typed wrapper on top.
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String? get avatarKey => throw _privateConstructorUsedError;
  bool get useGravatar => throw _privateConstructorUsedError;
  Map<String, dynamic>? get preferences => throw _privateConstructorUsedError;

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call({
    String id,
    String email,
    String displayName,
    UserRole role,
    DateTime? createdAt,
    String? avatarKey,
    bool useGravatar,
    Map<String, dynamic>? preferences,
  });
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? displayName = null,
    Object? role = null,
    Object? createdAt = freezed,
    Object? avatarKey = freezed,
    Object? useGravatar = null,
    Object? preferences = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as UserRole,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            avatarKey: freezed == avatarKey
                ? _value.avatarKey
                : avatarKey // ignore: cast_nullable_to_non_nullable
                      as String?,
            useGravatar: null == useGravatar
                ? _value.useGravatar
                : useGravatar // ignore: cast_nullable_to_non_nullable
                      as bool,
            preferences: freezed == preferences
                ? _value.preferences
                : preferences // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
    _$UserImpl value,
    $Res Function(_$UserImpl) then,
  ) = __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String email,
    String displayName,
    UserRole role,
    DateTime? createdAt,
    String? avatarKey,
    bool useGravatar,
    Map<String, dynamic>? preferences,
  });
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
    : super(_value, _then);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? displayName = null,
    Object? role = null,
    Object? createdAt = freezed,
    Object? avatarKey = freezed,
    Object? useGravatar = null,
    Object? preferences = freezed,
  }) {
    return _then(
      _$UserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as UserRole,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        avatarKey: freezed == avatarKey
            ? _value.avatarKey
            : avatarKey // ignore: cast_nullable_to_non_nullable
                  as String?,
        useGravatar: null == useGravatar
            ? _value.useGravatar
            : useGravatar // ignore: cast_nullable_to_non_nullable
                  as bool,
        preferences: freezed == preferences
            ? _value._preferences
            : preferences // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserImpl implements _User {
  const _$UserImpl({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.createdAt,
    this.avatarKey,
    this.useGravatar = false,
    final Map<String, dynamic>? preferences,
  }) : _preferences = preferences;

  factory _$UserImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserImplFromJson(json);

  @override
  final String id;
  @override
  final String email;
  @override
  final String displayName;
  @override
  final UserRole role;
  // Slice P1 — profile screen additions. All optional on the client so
  // the model stays backward-compatible with older `/api/auth/me`
  // payloads (e.g. between rolling app + API upgrades).
  //
  // - `createdAt`: ISO-8601 string on the wire; freezed + json_serializable
  //   decode to a DateTime automatically.
  // - `avatarKey`: object-storage key, not a URL. The media-serving
  //   route arrives in a later slice; the ProfileHeader widget
  //   composes a display URL then. For now, a non-null key is a
  //   signal that an avatar exists; we still render initials.
  // - `useGravatar`: opt-in fallback flag (defaults off to match
  //   backend default).
  // - `preferences`: free-form bag (theme / playback / a11y) — Slice
  //   P4 introduces a strongly-typed wrapper on top.
  @override
  final DateTime? createdAt;
  @override
  final String? avatarKey;
  @override
  @JsonKey()
  final bool useGravatar;
  final Map<String, dynamic>? _preferences;
  @override
  Map<String, dynamic>? get preferences {
    final value = _preferences;
    if (value == null) return null;
    if (_preferences is EqualUnmodifiableMapView) return _preferences;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName, role: $role, createdAt: $createdAt, avatarKey: $avatarKey, useGravatar: $useGravatar, preferences: $preferences)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.avatarKey, avatarKey) ||
                other.avatarKey == avatarKey) &&
            (identical(other.useGravatar, useGravatar) ||
                other.useGravatar == useGravatar) &&
            const DeepCollectionEquality().equals(
              other._preferences,
              _preferences,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    email,
    displayName,
    role,
    createdAt,
    avatarKey,
    useGravatar,
    const DeepCollectionEquality().hash(_preferences),
  );

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserImplToJson(this);
  }
}

abstract class _User implements User {
  const factory _User({
    required final String id,
    required final String email,
    required final String displayName,
    required final UserRole role,
    final DateTime? createdAt,
    final String? avatarKey,
    final bool useGravatar,
    final Map<String, dynamic>? preferences,
  }) = _$UserImpl;

  factory _User.fromJson(Map<String, dynamic> json) = _$UserImpl.fromJson;

  @override
  String get id;
  @override
  String get email;
  @override
  String get displayName;
  @override
  UserRole get role; // Slice P1 — profile screen additions. All optional on the client so
  // the model stays backward-compatible with older `/api/auth/me`
  // payloads (e.g. between rolling app + API upgrades).
  //
  // - `createdAt`: ISO-8601 string on the wire; freezed + json_serializable
  //   decode to a DateTime automatically.
  // - `avatarKey`: object-storage key, not a URL. The media-serving
  //   route arrives in a later slice; the ProfileHeader widget
  //   composes a display URL then. For now, a non-null key is a
  //   signal that an avatar exists; we still render initials.
  // - `useGravatar`: opt-in fallback flag (defaults off to match
  //   backend default).
  // - `preferences`: free-form bag (theme / playback / a11y) — Slice
  //   P4 introduces a strongly-typed wrapper on top.
  @override
  DateTime? get createdAt;
  @override
  String? get avatarKey;
  @override
  bool get useGravatar;
  @override
  Map<String, dynamic>? get preferences;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
