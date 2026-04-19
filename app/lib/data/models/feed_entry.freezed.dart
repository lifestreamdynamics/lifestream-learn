// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FeedEntry _$FeedEntryFromJson(Map<String, dynamic> json) {
  return _FeedEntry.fromJson(json);
}

/// @nodoc
mixin _$FeedEntry {
  VideoSummary get video => throw _privateConstructorUsedError;
  CourseSummary get course => throw _privateConstructorUsedError;
  int get cueCount => throw _privateConstructorUsedError;
  bool get hasAttempted => throw _privateConstructorUsedError;

  /// Serializes this FeedEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeedEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedEntryCopyWith<FeedEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedEntryCopyWith<$Res> {
  factory $FeedEntryCopyWith(FeedEntry value, $Res Function(FeedEntry) then) =
      _$FeedEntryCopyWithImpl<$Res, FeedEntry>;
  @useResult
  $Res call({
    VideoSummary video,
    CourseSummary course,
    int cueCount,
    bool hasAttempted,
  });

  $VideoSummaryCopyWith<$Res> get video;
  $CourseSummaryCopyWith<$Res> get course;
}

/// @nodoc
class _$FeedEntryCopyWithImpl<$Res, $Val extends FeedEntry>
    implements $FeedEntryCopyWith<$Res> {
  _$FeedEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? video = null,
    Object? course = null,
    Object? cueCount = null,
    Object? hasAttempted = null,
  }) {
    return _then(
      _value.copyWith(
            video: null == video
                ? _value.video
                : video // ignore: cast_nullable_to_non_nullable
                      as VideoSummary,
            course: null == course
                ? _value.course
                : course // ignore: cast_nullable_to_non_nullable
                      as CourseSummary,
            cueCount: null == cueCount
                ? _value.cueCount
                : cueCount // ignore: cast_nullable_to_non_nullable
                      as int,
            hasAttempted: null == hasAttempted
                ? _value.hasAttempted
                : hasAttempted // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of FeedEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VideoSummaryCopyWith<$Res> get video {
    return $VideoSummaryCopyWith<$Res>(_value.video, (value) {
      return _then(_value.copyWith(video: value) as $Val);
    });
  }

  /// Create a copy of FeedEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CourseSummaryCopyWith<$Res> get course {
    return $CourseSummaryCopyWith<$Res>(_value.course, (value) {
      return _then(_value.copyWith(course: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FeedEntryImplCopyWith<$Res>
    implements $FeedEntryCopyWith<$Res> {
  factory _$$FeedEntryImplCopyWith(
    _$FeedEntryImpl value,
    $Res Function(_$FeedEntryImpl) then,
  ) = __$$FeedEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    VideoSummary video,
    CourseSummary course,
    int cueCount,
    bool hasAttempted,
  });

  @override
  $VideoSummaryCopyWith<$Res> get video;
  @override
  $CourseSummaryCopyWith<$Res> get course;
}

/// @nodoc
class __$$FeedEntryImplCopyWithImpl<$Res>
    extends _$FeedEntryCopyWithImpl<$Res, _$FeedEntryImpl>
    implements _$$FeedEntryImplCopyWith<$Res> {
  __$$FeedEntryImplCopyWithImpl(
    _$FeedEntryImpl _value,
    $Res Function(_$FeedEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeedEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? video = null,
    Object? course = null,
    Object? cueCount = null,
    Object? hasAttempted = null,
  }) {
    return _then(
      _$FeedEntryImpl(
        video: null == video
            ? _value.video
            : video // ignore: cast_nullable_to_non_nullable
                  as VideoSummary,
        course: null == course
            ? _value.course
            : course // ignore: cast_nullable_to_non_nullable
                  as CourseSummary,
        cueCount: null == cueCount
            ? _value.cueCount
            : cueCount // ignore: cast_nullable_to_non_nullable
                  as int,
        hasAttempted: null == hasAttempted
            ? _value.hasAttempted
            : hasAttempted // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedEntryImpl implements _FeedEntry {
  const _$FeedEntryImpl({
    required this.video,
    required this.course,
    required this.cueCount,
    required this.hasAttempted,
  });

  factory _$FeedEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedEntryImplFromJson(json);

  @override
  final VideoSummary video;
  @override
  final CourseSummary course;
  @override
  final int cueCount;
  @override
  final bool hasAttempted;

  @override
  String toString() {
    return 'FeedEntry(video: $video, course: $course, cueCount: $cueCount, hasAttempted: $hasAttempted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedEntryImpl &&
            (identical(other.video, video) || other.video == video) &&
            (identical(other.course, course) || other.course == course) &&
            (identical(other.cueCount, cueCount) ||
                other.cueCount == cueCount) &&
            (identical(other.hasAttempted, hasAttempted) ||
                other.hasAttempted == hasAttempted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, video, course, cueCount, hasAttempted);

  /// Create a copy of FeedEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedEntryImplCopyWith<_$FeedEntryImpl> get copyWith =>
      __$$FeedEntryImplCopyWithImpl<_$FeedEntryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedEntryImplToJson(this);
  }
}

abstract class _FeedEntry implements FeedEntry {
  const factory _FeedEntry({
    required final VideoSummary video,
    required final CourseSummary course,
    required final int cueCount,
    required final bool hasAttempted,
  }) = _$FeedEntryImpl;

  factory _FeedEntry.fromJson(Map<String, dynamic> json) =
      _$FeedEntryImpl.fromJson;

  @override
  VideoSummary get video;
  @override
  CourseSummary get course;
  @override
  int get cueCount;
  @override
  bool get hasAttempted;

  /// Create a copy of FeedEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedEntryImplCopyWith<_$FeedEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FeedPage _$FeedPageFromJson(Map<String, dynamic> json) {
  return _FeedPage.fromJson(json);
}

/// @nodoc
mixin _$FeedPage {
  List<FeedEntry> get items => throw _privateConstructorUsedError;
  String? get nextCursor => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;

  /// Serializes this FeedPage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeedPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedPageCopyWith<FeedPage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedPageCopyWith<$Res> {
  factory $FeedPageCopyWith(FeedPage value, $Res Function(FeedPage) then) =
      _$FeedPageCopyWithImpl<$Res, FeedPage>;
  @useResult
  $Res call({List<FeedEntry> items, String? nextCursor, bool hasMore});
}

/// @nodoc
class _$FeedPageCopyWithImpl<$Res, $Val extends FeedPage>
    implements $FeedPageCopyWith<$Res> {
  _$FeedPageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedPage
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
                      as List<FeedEntry>,
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
abstract class _$$FeedPageImplCopyWith<$Res>
    implements $FeedPageCopyWith<$Res> {
  factory _$$FeedPageImplCopyWith(
    _$FeedPageImpl value,
    $Res Function(_$FeedPageImpl) then,
  ) = __$$FeedPageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<FeedEntry> items, String? nextCursor, bool hasMore});
}

/// @nodoc
class __$$FeedPageImplCopyWithImpl<$Res>
    extends _$FeedPageCopyWithImpl<$Res, _$FeedPageImpl>
    implements _$$FeedPageImplCopyWith<$Res> {
  __$$FeedPageImplCopyWithImpl(
    _$FeedPageImpl _value,
    $Res Function(_$FeedPageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeedPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? nextCursor = freezed,
    Object? hasMore = null,
  }) {
    return _then(
      _$FeedPageImpl(
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<FeedEntry>,
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
class _$FeedPageImpl implements _FeedPage {
  const _$FeedPageImpl({
    required final List<FeedEntry> items,
    this.nextCursor,
    required this.hasMore,
  }) : _items = items;

  factory _$FeedPageImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedPageImplFromJson(json);

  final List<FeedEntry> _items;
  @override
  List<FeedEntry> get items {
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
    return 'FeedPage(items: $items, nextCursor: $nextCursor, hasMore: $hasMore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedPageImpl &&
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

  /// Create a copy of FeedPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedPageImplCopyWith<_$FeedPageImpl> get copyWith =>
      __$$FeedPageImplCopyWithImpl<_$FeedPageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedPageImplToJson(this);
  }
}

abstract class _FeedPage implements FeedPage {
  const factory _FeedPage({
    required final List<FeedEntry> items,
    final String? nextCursor,
    required final bool hasMore,
  }) = _$FeedPageImpl;

  factory _FeedPage.fromJson(Map<String, dynamic> json) =
      _$FeedPageImpl.fromJson;

  @override
  List<FeedEntry> get items;
  @override
  String? get nextCursor;
  @override
  bool get hasMore;

  /// Create a copy of FeedPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedPageImplCopyWith<_$FeedPageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
