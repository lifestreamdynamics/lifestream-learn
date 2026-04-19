// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'designer_application.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DesignerApplication _$DesignerApplicationFromJson(Map<String, dynamic> json) {
  return _DesignerApplication.fromJson(json);
}

/// @nodoc
mixin _$DesignerApplication {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  AppStatus get status => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  String? get reviewerNote => throw _privateConstructorUsedError;
  DateTime get submittedAt => throw _privateConstructorUsedError;
  DateTime? get reviewedAt => throw _privateConstructorUsedError;
  String? get reviewedBy => throw _privateConstructorUsedError;

  /// Serializes this DesignerApplication to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DesignerApplication
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DesignerApplicationCopyWith<DesignerApplication> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DesignerApplicationCopyWith<$Res> {
  factory $DesignerApplicationCopyWith(
    DesignerApplication value,
    $Res Function(DesignerApplication) then,
  ) = _$DesignerApplicationCopyWithImpl<$Res, DesignerApplication>;
  @useResult
  $Res call({
    String id,
    String userId,
    AppStatus status,
    String? note,
    String? reviewerNote,
    DateTime submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  });
}

/// @nodoc
class _$DesignerApplicationCopyWithImpl<$Res, $Val extends DesignerApplication>
    implements $DesignerApplicationCopyWith<$Res> {
  _$DesignerApplicationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DesignerApplication
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? status = null,
    Object? note = freezed,
    Object? reviewerNote = freezed,
    Object? submittedAt = null,
    Object? reviewedAt = freezed,
    Object? reviewedBy = freezed,
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
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as AppStatus,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            reviewerNote: freezed == reviewerNote
                ? _value.reviewerNote
                : reviewerNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            submittedAt: null == submittedAt
                ? _value.submittedAt
                : submittedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            reviewedAt: freezed == reviewedAt
                ? _value.reviewedAt
                : reviewedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            reviewedBy: freezed == reviewedBy
                ? _value.reviewedBy
                : reviewedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DesignerApplicationImplCopyWith<$Res>
    implements $DesignerApplicationCopyWith<$Res> {
  factory _$$DesignerApplicationImplCopyWith(
    _$DesignerApplicationImpl value,
    $Res Function(_$DesignerApplicationImpl) then,
  ) = __$$DesignerApplicationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    AppStatus status,
    String? note,
    String? reviewerNote,
    DateTime submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  });
}

/// @nodoc
class __$$DesignerApplicationImplCopyWithImpl<$Res>
    extends _$DesignerApplicationCopyWithImpl<$Res, _$DesignerApplicationImpl>
    implements _$$DesignerApplicationImplCopyWith<$Res> {
  __$$DesignerApplicationImplCopyWithImpl(
    _$DesignerApplicationImpl _value,
    $Res Function(_$DesignerApplicationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DesignerApplication
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? status = null,
    Object? note = freezed,
    Object? reviewerNote = freezed,
    Object? submittedAt = null,
    Object? reviewedAt = freezed,
    Object? reviewedBy = freezed,
  }) {
    return _then(
      _$DesignerApplicationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as AppStatus,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewerNote: freezed == reviewerNote
            ? _value.reviewerNote
            : reviewerNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        submittedAt: null == submittedAt
            ? _value.submittedAt
            : submittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        reviewedAt: freezed == reviewedAt
            ? _value.reviewedAt
            : reviewedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        reviewedBy: freezed == reviewedBy
            ? _value.reviewedBy
            : reviewedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DesignerApplicationImpl implements _DesignerApplication {
  const _$DesignerApplicationImpl({
    required this.id,
    required this.userId,
    required this.status,
    this.note,
    this.reviewerNote,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory _$DesignerApplicationImpl.fromJson(Map<String, dynamic> json) =>
      _$$DesignerApplicationImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final AppStatus status;
  @override
  final String? note;
  @override
  final String? reviewerNote;
  @override
  final DateTime submittedAt;
  @override
  final DateTime? reviewedAt;
  @override
  final String? reviewedBy;

  @override
  String toString() {
    return 'DesignerApplication(id: $id, userId: $userId, status: $status, note: $note, reviewerNote: $reviewerNote, submittedAt: $submittedAt, reviewedAt: $reviewedAt, reviewedBy: $reviewedBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DesignerApplicationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.reviewerNote, reviewerNote) ||
                other.reviewerNote == reviewerNote) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.reviewedBy, reviewedBy) ||
                other.reviewedBy == reviewedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    status,
    note,
    reviewerNote,
    submittedAt,
    reviewedAt,
    reviewedBy,
  );

  /// Create a copy of DesignerApplication
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DesignerApplicationImplCopyWith<_$DesignerApplicationImpl> get copyWith =>
      __$$DesignerApplicationImplCopyWithImpl<_$DesignerApplicationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DesignerApplicationImplToJson(this);
  }
}

abstract class _DesignerApplication implements DesignerApplication {
  const factory _DesignerApplication({
    required final String id,
    required final String userId,
    required final AppStatus status,
    final String? note,
    final String? reviewerNote,
    required final DateTime submittedAt,
    final DateTime? reviewedAt,
    final String? reviewedBy,
  }) = _$DesignerApplicationImpl;

  factory _DesignerApplication.fromJson(Map<String, dynamic> json) =
      _$DesignerApplicationImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  AppStatus get status;
  @override
  String? get note;
  @override
  String? get reviewerNote;
  @override
  DateTime get submittedAt;
  @override
  DateTime? get reviewedAt;
  @override
  String? get reviewedBy;

  /// Create a copy of DesignerApplication
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DesignerApplicationImplCopyWith<_$DesignerApplicationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DesignerApplicationPage _$DesignerApplicationPageFromJson(
  Map<String, dynamic> json,
) {
  return _DesignerApplicationPage.fromJson(json);
}

/// @nodoc
mixin _$DesignerApplicationPage {
  List<DesignerApplication> get items => throw _privateConstructorUsedError;
  String? get nextCursor => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;

  /// Serializes this DesignerApplicationPage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DesignerApplicationPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DesignerApplicationPageCopyWith<DesignerApplicationPage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DesignerApplicationPageCopyWith<$Res> {
  factory $DesignerApplicationPageCopyWith(
    DesignerApplicationPage value,
    $Res Function(DesignerApplicationPage) then,
  ) = _$DesignerApplicationPageCopyWithImpl<$Res, DesignerApplicationPage>;
  @useResult
  $Res call({
    List<DesignerApplication> items,
    String? nextCursor,
    bool hasMore,
  });
}

/// @nodoc
class _$DesignerApplicationPageCopyWithImpl<
  $Res,
  $Val extends DesignerApplicationPage
>
    implements $DesignerApplicationPageCopyWith<$Res> {
  _$DesignerApplicationPageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DesignerApplicationPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? nextCursor = freezed,
    Object? hasMore = null,
  }) {
    return _then(
      _value.copyWith(
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<DesignerApplication>,
            nextCursor: freezed == nextCursor
                ? _value.nextCursor
                : nextCursor // ignore: cast_nullable_to_non_nullable
                      as String?,
            hasMore: null == hasMore
                ? _value.hasMore
                : hasMore // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DesignerApplicationPageImplCopyWith<$Res>
    implements $DesignerApplicationPageCopyWith<$Res> {
  factory _$$DesignerApplicationPageImplCopyWith(
    _$DesignerApplicationPageImpl value,
    $Res Function(_$DesignerApplicationPageImpl) then,
  ) = __$$DesignerApplicationPageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<DesignerApplication> items,
    String? nextCursor,
    bool hasMore,
  });
}

/// @nodoc
class __$$DesignerApplicationPageImplCopyWithImpl<$Res>
    extends
        _$DesignerApplicationPageCopyWithImpl<
          $Res,
          _$DesignerApplicationPageImpl
        >
    implements _$$DesignerApplicationPageImplCopyWith<$Res> {
  __$$DesignerApplicationPageImplCopyWithImpl(
    _$DesignerApplicationPageImpl _value,
    $Res Function(_$DesignerApplicationPageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DesignerApplicationPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? nextCursor = freezed,
    Object? hasMore = null,
  }) {
    return _then(
      _$DesignerApplicationPageImpl(
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<DesignerApplication>,
        nextCursor: freezed == nextCursor
            ? _value.nextCursor
            : nextCursor // ignore: cast_nullable_to_non_nullable
                  as String?,
        hasMore: null == hasMore
            ? _value.hasMore
            : hasMore // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DesignerApplicationPageImpl implements _DesignerApplicationPage {
  const _$DesignerApplicationPageImpl({
    required final List<DesignerApplication> items,
    this.nextCursor,
    required this.hasMore,
  }) : _items = items;

  factory _$DesignerApplicationPageImpl.fromJson(Map<String, dynamic> json) =>
      _$$DesignerApplicationPageImplFromJson(json);

  final List<DesignerApplication> _items;
  @override
  List<DesignerApplication> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final String? nextCursor;
  @override
  final bool hasMore;

  @override
  String toString() {
    return 'DesignerApplicationPage(items: $items, nextCursor: $nextCursor, hasMore: $hasMore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DesignerApplicationPageImpl &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.nextCursor, nextCursor) ||
                other.nextCursor == nextCursor) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_items),
    nextCursor,
    hasMore,
  );

  /// Create a copy of DesignerApplicationPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DesignerApplicationPageImplCopyWith<_$DesignerApplicationPageImpl>
  get copyWith =>
      __$$DesignerApplicationPageImplCopyWithImpl<
        _$DesignerApplicationPageImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DesignerApplicationPageImplToJson(this);
  }
}

abstract class _DesignerApplicationPage implements DesignerApplicationPage {
  const factory _DesignerApplicationPage({
    required final List<DesignerApplication> items,
    final String? nextCursor,
    required final bool hasMore,
  }) = _$DesignerApplicationPageImpl;

  factory _DesignerApplicationPage.fromJson(Map<String, dynamic> json) =
      _$DesignerApplicationPageImpl.fromJson;

  @override
  List<DesignerApplication> get items;
  @override
  String? get nextCursor;
  @override
  bool get hasMore;

  /// Create a copy of DesignerApplicationPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DesignerApplicationPageImplCopyWith<_$DesignerApplicationPageImpl>
  get copyWith => throw _privateConstructorUsedError;
}
