// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'course.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Course _$CourseFromJson(Map<String, dynamic> json) {
  return _Course.fromJson(json);
}

/// @nodoc
mixin _$Course {
  String get id => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get coverImageUrl => throw _privateConstructorUsedError;
  String get ownerId => throw _privateConstructorUsedError;
  bool get published => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Course to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseCopyWith<Course> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseCopyWith<$Res> {
  factory $CourseCopyWith(Course value, $Res Function(Course) then) =
      _$CourseCopyWithImpl<$Res, Course>;
  @useResult
  $Res call({
    String id,
    String slug,
    String title,
    String description,
    String? coverImageUrl,
    String ownerId,
    bool published,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$CourseCopyWithImpl<$Res, $Val extends Course>
    implements $CourseCopyWith<$Res> {
  _$CourseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? title = null,
    Object? description = null,
    Object? coverImageUrl = freezed,
    Object? ownerId = null,
    Object? published = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            slug: null == slug
                ? _value.slug
                : slug // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            coverImageUrl: freezed == coverImageUrl
                ? _value.coverImageUrl
                : coverImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            ownerId: null == ownerId
                ? _value.ownerId
                : ownerId // ignore: cast_nullable_to_non_nullable
                      as String,
            published: null == published
                ? _value.published
                : published // ignore: cast_nullable_to_non_nullable
                      as bool,
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
abstract class _$$CourseImplCopyWith<$Res> implements $CourseCopyWith<$Res> {
  factory _$$CourseImplCopyWith(
    _$CourseImpl value,
    $Res Function(_$CourseImpl) then,
  ) = __$$CourseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String slug,
    String title,
    String description,
    String? coverImageUrl,
    String ownerId,
    bool published,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$CourseImplCopyWithImpl<$Res>
    extends _$CourseCopyWithImpl<$Res, _$CourseImpl>
    implements _$$CourseImplCopyWith<$Res> {
  __$$CourseImplCopyWithImpl(
    _$CourseImpl _value,
    $Res Function(_$CourseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? title = null,
    Object? description = null,
    Object? coverImageUrl = freezed,
    Object? ownerId = null,
    Object? published = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$CourseImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        slug: null == slug
            ? _value.slug
            : slug // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        coverImageUrl: freezed == coverImageUrl
            ? _value.coverImageUrl
            : coverImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        ownerId: null == ownerId
            ? _value.ownerId
            : ownerId // ignore: cast_nullable_to_non_nullable
                  as String,
        published: null == published
            ? _value.published
            : published // ignore: cast_nullable_to_non_nullable
                  as bool,
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
class _$CourseImpl implements _Course {
  const _$CourseImpl({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.coverImageUrl,
    required this.ownerId,
    required this.published,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _$CourseImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseImplFromJson(json);

  @override
  final String id;
  @override
  final String slug;
  @override
  final String title;
  @override
  final String description;
  @override
  final String? coverImageUrl;
  @override
  final String ownerId;
  @override
  final bool published;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Course(id: $id, slug: $slug, title: $title, description: $description, coverImageUrl: $coverImageUrl, ownerId: $ownerId, published: $published, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.published, published) ||
                other.published == published) &&
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
    slug,
    title,
    description,
    coverImageUrl,
    ownerId,
    published,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseImplCopyWith<_$CourseImpl> get copyWith =>
      __$$CourseImplCopyWithImpl<_$CourseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseImplToJson(this);
  }
}

abstract class _Course implements Course {
  const factory _Course({
    required final String id,
    required final String slug,
    required final String title,
    required final String description,
    final String? coverImageUrl,
    required final String ownerId,
    required final bool published,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$CourseImpl;

  factory _Course.fromJson(Map<String, dynamic> json) = _$CourseImpl.fromJson;

  @override
  String get id;
  @override
  String get slug;
  @override
  String get title;
  @override
  String get description;
  @override
  String? get coverImageUrl;
  @override
  String get ownerId;
  @override
  bool get published;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseImplCopyWith<_$CourseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CourseDetail _$CourseDetailFromJson(Map<String, dynamic> json) {
  return _CourseDetail.fromJson(json);
}

/// @nodoc
mixin _$CourseDetail {
  String get id => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get coverImageUrl => throw _privateConstructorUsedError;
  String get ownerId => throw _privateConstructorUsedError;
  bool get published => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  List<CourseVideoSummary> get videos => throw _privateConstructorUsedError;

  /// Serializes this CourseDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CourseDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseDetailCopyWith<CourseDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseDetailCopyWith<$Res> {
  factory $CourseDetailCopyWith(
    CourseDetail value,
    $Res Function(CourseDetail) then,
  ) = _$CourseDetailCopyWithImpl<$Res, CourseDetail>;
  @useResult
  $Res call({
    String id,
    String slug,
    String title,
    String description,
    String? coverImageUrl,
    String ownerId,
    bool published,
    DateTime createdAt,
    DateTime updatedAt,
    List<CourseVideoSummary> videos,
  });
}

/// @nodoc
class _$CourseDetailCopyWithImpl<$Res, $Val extends CourseDetail>
    implements $CourseDetailCopyWith<$Res> {
  _$CourseDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourseDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? title = null,
    Object? description = null,
    Object? coverImageUrl = freezed,
    Object? ownerId = null,
    Object? published = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? videos = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            slug: null == slug
                ? _value.slug
                : slug // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            coverImageUrl: freezed == coverImageUrl
                ? _value.coverImageUrl
                : coverImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            ownerId: null == ownerId
                ? _value.ownerId
                : ownerId // ignore: cast_nullable_to_non_nullable
                      as String,
            published: null == published
                ? _value.published
                : published // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            videos: null == videos
                ? _value.videos
                : videos // ignore: cast_nullable_to_non_nullable
                      as List<CourseVideoSummary>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourseDetailImplCopyWith<$Res>
    implements $CourseDetailCopyWith<$Res> {
  factory _$$CourseDetailImplCopyWith(
    _$CourseDetailImpl value,
    $Res Function(_$CourseDetailImpl) then,
  ) = __$$CourseDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String slug,
    String title,
    String description,
    String? coverImageUrl,
    String ownerId,
    bool published,
    DateTime createdAt,
    DateTime updatedAt,
    List<CourseVideoSummary> videos,
  });
}

/// @nodoc
class __$$CourseDetailImplCopyWithImpl<$Res>
    extends _$CourseDetailCopyWithImpl<$Res, _$CourseDetailImpl>
    implements _$$CourseDetailImplCopyWith<$Res> {
  __$$CourseDetailImplCopyWithImpl(
    _$CourseDetailImpl _value,
    $Res Function(_$CourseDetailImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourseDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? title = null,
    Object? description = null,
    Object? coverImageUrl = freezed,
    Object? ownerId = null,
    Object? published = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? videos = null,
  }) {
    return _then(
      _$CourseDetailImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        slug: null == slug
            ? _value.slug
            : slug // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        coverImageUrl: freezed == coverImageUrl
            ? _value.coverImageUrl
            : coverImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        ownerId: null == ownerId
            ? _value.ownerId
            : ownerId // ignore: cast_nullable_to_non_nullable
                  as String,
        published: null == published
            ? _value.published
            : published // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        videos: null == videos
            ? _value._videos
            : videos // ignore: cast_nullable_to_non_nullable
                  as List<CourseVideoSummary>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CourseDetailImpl implements _CourseDetail {
  const _$CourseDetailImpl({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.coverImageUrl,
    required this.ownerId,
    required this.published,
    required this.createdAt,
    required this.updatedAt,
    final List<CourseVideoSummary> videos = const <CourseVideoSummary>[],
  }) : _videos = videos;

  factory _$CourseDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseDetailImplFromJson(json);

  @override
  final String id;
  @override
  final String slug;
  @override
  final String title;
  @override
  final String description;
  @override
  final String? coverImageUrl;
  @override
  final String ownerId;
  @override
  final bool published;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final List<CourseVideoSummary> _videos;
  @override
  @JsonKey()
  List<CourseVideoSummary> get videos {
    if (_videos is EqualUnmodifiableListView) return _videos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_videos);
  }

  @override
  String toString() {
    return 'CourseDetail(id: $id, slug: $slug, title: $title, description: $description, coverImageUrl: $coverImageUrl, ownerId: $ownerId, published: $published, createdAt: $createdAt, updatedAt: $updatedAt, videos: $videos)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseDetailImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.published, published) ||
                other.published == published) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(other._videos, _videos));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    slug,
    title,
    description,
    coverImageUrl,
    ownerId,
    published,
    createdAt,
    updatedAt,
    const DeepCollectionEquality().hash(_videos),
  );

  /// Create a copy of CourseDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseDetailImplCopyWith<_$CourseDetailImpl> get copyWith =>
      __$$CourseDetailImplCopyWithImpl<_$CourseDetailImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseDetailImplToJson(this);
  }
}

abstract class _CourseDetail implements CourseDetail {
  const factory _CourseDetail({
    required final String id,
    required final String slug,
    required final String title,
    required final String description,
    final String? coverImageUrl,
    required final String ownerId,
    required final bool published,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final List<CourseVideoSummary> videos,
  }) = _$CourseDetailImpl;

  factory _CourseDetail.fromJson(Map<String, dynamic> json) =
      _$CourseDetailImpl.fromJson;

  @override
  String get id;
  @override
  String get slug;
  @override
  String get title;
  @override
  String get description;
  @override
  String? get coverImageUrl;
  @override
  String get ownerId;
  @override
  bool get published;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  List<CourseVideoSummary> get videos;

  /// Create a copy of CourseDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseDetailImplCopyWith<_$CourseDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CourseSummary _$CourseSummaryFromJson(Map<String, dynamic> json) {
  return _CourseSummary.fromJson(json);
}

/// @nodoc
mixin _$CourseSummary {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get coverImageUrl => throw _privateConstructorUsedError;

  /// Serializes this CourseSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseSummaryCopyWith<CourseSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseSummaryCopyWith<$Res> {
  factory $CourseSummaryCopyWith(
    CourseSummary value,
    $Res Function(CourseSummary) then,
  ) = _$CourseSummaryCopyWithImpl<$Res, CourseSummary>;
  @useResult
  $Res call({String id, String title, String? coverImageUrl});
}

/// @nodoc
class _$CourseSummaryCopyWithImpl<$Res, $Val extends CourseSummary>
    implements $CourseSummaryCopyWith<$Res> {
  _$CourseSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? coverImageUrl = freezed,
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
            coverImageUrl: freezed == coverImageUrl
                ? _value.coverImageUrl
                : coverImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourseSummaryImplCopyWith<$Res>
    implements $CourseSummaryCopyWith<$Res> {
  factory _$$CourseSummaryImplCopyWith(
    _$CourseSummaryImpl value,
    $Res Function(_$CourseSummaryImpl) then,
  ) = __$$CourseSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, String? coverImageUrl});
}

/// @nodoc
class __$$CourseSummaryImplCopyWithImpl<$Res>
    extends _$CourseSummaryCopyWithImpl<$Res, _$CourseSummaryImpl>
    implements _$$CourseSummaryImplCopyWith<$Res> {
  __$$CourseSummaryImplCopyWithImpl(
    _$CourseSummaryImpl _value,
    $Res Function(_$CourseSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? coverImageUrl = freezed,
  }) {
    return _then(
      _$CourseSummaryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        coverImageUrl: freezed == coverImageUrl
            ? _value.coverImageUrl
            : coverImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CourseSummaryImpl implements _CourseSummary {
  const _$CourseSummaryImpl({
    required this.id,
    required this.title,
    this.coverImageUrl,
  });

  factory _$CourseSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseSummaryImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String? coverImageUrl;

  @override
  String toString() {
    return 'CourseSummary(id: $id, title: $title, coverImageUrl: $coverImageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, coverImageUrl);

  /// Create a copy of CourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseSummaryImplCopyWith<_$CourseSummaryImpl> get copyWith =>
      __$$CourseSummaryImplCopyWithImpl<_$CourseSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseSummaryImplToJson(this);
  }
}

abstract class _CourseSummary implements CourseSummary {
  const factory _CourseSummary({
    required final String id,
    required final String title,
    final String? coverImageUrl,
  }) = _$CourseSummaryImpl;

  factory _CourseSummary.fromJson(Map<String, dynamic> json) =
      _$CourseSummaryImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String? get coverImageUrl;

  /// Create a copy of CourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseSummaryImplCopyWith<_$CourseSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CoursePage _$CoursePageFromJson(Map<String, dynamic> json) {
  return _CoursePage.fromJson(json);
}

/// @nodoc
mixin _$CoursePage {
  List<Course> get items => throw _privateConstructorUsedError;
  String? get nextCursor => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;

  /// Serializes this CoursePage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CoursePage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CoursePageCopyWith<CoursePage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CoursePageCopyWith<$Res> {
  factory $CoursePageCopyWith(
    CoursePage value,
    $Res Function(CoursePage) then,
  ) = _$CoursePageCopyWithImpl<$Res, CoursePage>;
  @useResult
  $Res call({List<Course> items, String? nextCursor, bool hasMore});
}

/// @nodoc
class _$CoursePageCopyWithImpl<$Res, $Val extends CoursePage>
    implements $CoursePageCopyWith<$Res> {
  _$CoursePageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CoursePage
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
                      as List<Course>,
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
abstract class _$$CoursePageImplCopyWith<$Res>
    implements $CoursePageCopyWith<$Res> {
  factory _$$CoursePageImplCopyWith(
    _$CoursePageImpl value,
    $Res Function(_$CoursePageImpl) then,
  ) = __$$CoursePageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Course> items, String? nextCursor, bool hasMore});
}

/// @nodoc
class __$$CoursePageImplCopyWithImpl<$Res>
    extends _$CoursePageCopyWithImpl<$Res, _$CoursePageImpl>
    implements _$$CoursePageImplCopyWith<$Res> {
  __$$CoursePageImplCopyWithImpl(
    _$CoursePageImpl _value,
    $Res Function(_$CoursePageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CoursePage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? nextCursor = freezed,
    Object? hasMore = null,
  }) {
    return _then(
      _$CoursePageImpl(
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<Course>,
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
class _$CoursePageImpl implements _CoursePage {
  const _$CoursePageImpl({
    required final List<Course> items,
    this.nextCursor,
    required this.hasMore,
  }) : _items = items;

  factory _$CoursePageImpl.fromJson(Map<String, dynamic> json) =>
      _$$CoursePageImplFromJson(json);

  final List<Course> _items;
  @override
  List<Course> get items {
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
    return 'CoursePage(items: $items, nextCursor: $nextCursor, hasMore: $hasMore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CoursePageImpl &&
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

  /// Create a copy of CoursePage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CoursePageImplCopyWith<_$CoursePageImpl> get copyWith =>
      __$$CoursePageImplCopyWithImpl<_$CoursePageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CoursePageImplToJson(this);
  }
}

abstract class _CoursePage implements CoursePage {
  const factory _CoursePage({
    required final List<Course> items,
    final String? nextCursor,
    required final bool hasMore,
  }) = _$CoursePageImpl;

  factory _CoursePage.fromJson(Map<String, dynamic> json) =
      _$CoursePageImpl.fromJson;

  @override
  List<Course> get items;
  @override
  String? get nextCursor;
  @override
  bool get hasMore;

  /// Create a copy of CoursePage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CoursePageImplCopyWith<_$CoursePageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
