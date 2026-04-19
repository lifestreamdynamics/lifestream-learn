// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'enrollment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Enrollment _$EnrollmentFromJson(Map<String, dynamic> json) {
  return _Enrollment.fromJson(json);
}

/// @nodoc
mixin _$Enrollment {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get courseId => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  String? get lastVideoId => throw _privateConstructorUsedError;
  int? get lastPosMs => throw _privateConstructorUsedError;

  /// Serializes this Enrollment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EnrollmentCopyWith<Enrollment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EnrollmentCopyWith<$Res> {
  factory $EnrollmentCopyWith(
    Enrollment value,
    $Res Function(Enrollment) then,
  ) = _$EnrollmentCopyWithImpl<$Res, Enrollment>;
  @useResult
  $Res call({
    String id,
    String userId,
    String courseId,
    DateTime startedAt,
    String? lastVideoId,
    int? lastPosMs,
  });
}

/// @nodoc
class _$EnrollmentCopyWithImpl<$Res, $Val extends Enrollment>
    implements $EnrollmentCopyWith<$Res> {
  _$EnrollmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? courseId = null,
    Object? startedAt = null,
    Object? lastVideoId = freezed,
    Object? lastPosMs = freezed,
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
            courseId: null == courseId
                ? _value.courseId
                : courseId // ignore: cast_nullable_to_non_nullable
                      as String,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            lastVideoId: freezed == lastVideoId
                ? _value.lastVideoId
                : lastVideoId // ignore: cast_nullable_to_non_nullable
                      as String?,
            lastPosMs: freezed == lastPosMs
                ? _value.lastPosMs
                : lastPosMs // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EnrollmentImplCopyWith<$Res>
    implements $EnrollmentCopyWith<$Res> {
  factory _$$EnrollmentImplCopyWith(
    _$EnrollmentImpl value,
    $Res Function(_$EnrollmentImpl) then,
  ) = __$$EnrollmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String courseId,
    DateTime startedAt,
    String? lastVideoId,
    int? lastPosMs,
  });
}

/// @nodoc
class __$$EnrollmentImplCopyWithImpl<$Res>
    extends _$EnrollmentCopyWithImpl<$Res, _$EnrollmentImpl>
    implements _$$EnrollmentImplCopyWith<$Res> {
  __$$EnrollmentImplCopyWithImpl(
    _$EnrollmentImpl _value,
    $Res Function(_$EnrollmentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? courseId = null,
    Object? startedAt = null,
    Object? lastVideoId = freezed,
    Object? lastPosMs = freezed,
  }) {
    return _then(
      _$EnrollmentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        courseId: null == courseId
            ? _value.courseId
            : courseId // ignore: cast_nullable_to_non_nullable
                  as String,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        lastVideoId: freezed == lastVideoId
            ? _value.lastVideoId
            : lastVideoId // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastPosMs: freezed == lastPosMs
            ? _value.lastPosMs
            : lastPosMs // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EnrollmentImpl implements _Enrollment {
  const _$EnrollmentImpl({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.startedAt,
    this.lastVideoId,
    this.lastPosMs,
  });

  factory _$EnrollmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$EnrollmentImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String courseId;
  @override
  final DateTime startedAt;
  @override
  final String? lastVideoId;
  @override
  final int? lastPosMs;

  @override
  String toString() {
    return 'Enrollment(id: $id, userId: $userId, courseId: $courseId, startedAt: $startedAt, lastVideoId: $lastVideoId, lastPosMs: $lastPosMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EnrollmentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.courseId, courseId) ||
                other.courseId == courseId) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.lastVideoId, lastVideoId) ||
                other.lastVideoId == lastVideoId) &&
            (identical(other.lastPosMs, lastPosMs) ||
                other.lastPosMs == lastPosMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    courseId,
    startedAt,
    lastVideoId,
    lastPosMs,
  );

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EnrollmentImplCopyWith<_$EnrollmentImpl> get copyWith =>
      __$$EnrollmentImplCopyWithImpl<_$EnrollmentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EnrollmentImplToJson(this);
  }
}

abstract class _Enrollment implements Enrollment {
  const factory _Enrollment({
    required final String id,
    required final String userId,
    required final String courseId,
    required final DateTime startedAt,
    final String? lastVideoId,
    final int? lastPosMs,
  }) = _$EnrollmentImpl;

  factory _Enrollment.fromJson(Map<String, dynamic> json) =
      _$EnrollmentImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get courseId;
  @override
  DateTime get startedAt;
  @override
  String? get lastVideoId;
  @override
  int? get lastPosMs;

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EnrollmentImplCopyWith<_$EnrollmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EnrolledCourseSummary _$EnrolledCourseSummaryFromJson(
  Map<String, dynamic> json,
) {
  return _EnrolledCourseSummary.fromJson(json);
}

/// @nodoc
mixin _$EnrolledCourseSummary {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  String? get coverImageUrl => throw _privateConstructorUsedError;

  /// Serializes this EnrolledCourseSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EnrolledCourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EnrolledCourseSummaryCopyWith<EnrolledCourseSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EnrolledCourseSummaryCopyWith<$Res> {
  factory $EnrolledCourseSummaryCopyWith(
    EnrolledCourseSummary value,
    $Res Function(EnrolledCourseSummary) then,
  ) = _$EnrolledCourseSummaryCopyWithImpl<$Res, EnrolledCourseSummary>;
  @useResult
  $Res call({String id, String title, String slug, String? coverImageUrl});
}

/// @nodoc
class _$EnrolledCourseSummaryCopyWithImpl<
  $Res,
  $Val extends EnrolledCourseSummary
>
    implements $EnrolledCourseSummaryCopyWith<$Res> {
  _$EnrolledCourseSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EnrolledCourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? slug = null,
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
            slug: null == slug
                ? _value.slug
                : slug // ignore: cast_nullable_to_non_nullable
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
abstract class _$$EnrolledCourseSummaryImplCopyWith<$Res>
    implements $EnrolledCourseSummaryCopyWith<$Res> {
  factory _$$EnrolledCourseSummaryImplCopyWith(
    _$EnrolledCourseSummaryImpl value,
    $Res Function(_$EnrolledCourseSummaryImpl) then,
  ) = __$$EnrolledCourseSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, String slug, String? coverImageUrl});
}

/// @nodoc
class __$$EnrolledCourseSummaryImplCopyWithImpl<$Res>
    extends
        _$EnrolledCourseSummaryCopyWithImpl<$Res, _$EnrolledCourseSummaryImpl>
    implements _$$EnrolledCourseSummaryImplCopyWith<$Res> {
  __$$EnrolledCourseSummaryImplCopyWithImpl(
    _$EnrolledCourseSummaryImpl _value,
    $Res Function(_$EnrolledCourseSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EnrolledCourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? slug = null,
    Object? coverImageUrl = freezed,
  }) {
    return _then(
      _$EnrolledCourseSummaryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        slug: null == slug
            ? _value.slug
            : slug // ignore: cast_nullable_to_non_nullable
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
class _$EnrolledCourseSummaryImpl implements _EnrolledCourseSummary {
  const _$EnrolledCourseSummaryImpl({
    required this.id,
    required this.title,
    required this.slug,
    this.coverImageUrl,
  });

  factory _$EnrolledCourseSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$EnrolledCourseSummaryImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String slug;
  @override
  final String? coverImageUrl;

  @override
  String toString() {
    return 'EnrolledCourseSummary(id: $id, title: $title, slug: $slug, coverImageUrl: $coverImageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EnrolledCourseSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, slug, coverImageUrl);

  /// Create a copy of EnrolledCourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EnrolledCourseSummaryImplCopyWith<_$EnrolledCourseSummaryImpl>
  get copyWith =>
      __$$EnrolledCourseSummaryImplCopyWithImpl<_$EnrolledCourseSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EnrolledCourseSummaryImplToJson(this);
  }
}

abstract class _EnrolledCourseSummary implements EnrolledCourseSummary {
  const factory _EnrolledCourseSummary({
    required final String id,
    required final String title,
    required final String slug,
    final String? coverImageUrl,
  }) = _$EnrolledCourseSummaryImpl;

  factory _EnrolledCourseSummary.fromJson(Map<String, dynamic> json) =
      _$EnrolledCourseSummaryImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get slug;
  @override
  String? get coverImageUrl;

  /// Create a copy of EnrolledCourseSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EnrolledCourseSummaryImplCopyWith<_$EnrolledCourseSummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

EnrollmentWithCourse _$EnrollmentWithCourseFromJson(Map<String, dynamic> json) {
  return _EnrollmentWithCourse.fromJson(json);
}

/// @nodoc
mixin _$EnrollmentWithCourse {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get courseId => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  String? get lastVideoId => throw _privateConstructorUsedError;
  int? get lastPosMs => throw _privateConstructorUsedError;
  EnrolledCourseSummary get course => throw _privateConstructorUsedError;

  /// Serializes this EnrollmentWithCourse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EnrollmentWithCourse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EnrollmentWithCourseCopyWith<EnrollmentWithCourse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EnrollmentWithCourseCopyWith<$Res> {
  factory $EnrollmentWithCourseCopyWith(
    EnrollmentWithCourse value,
    $Res Function(EnrollmentWithCourse) then,
  ) = _$EnrollmentWithCourseCopyWithImpl<$Res, EnrollmentWithCourse>;
  @useResult
  $Res call({
    String id,
    String userId,
    String courseId,
    DateTime startedAt,
    String? lastVideoId,
    int? lastPosMs,
    EnrolledCourseSummary course,
  });

  $EnrolledCourseSummaryCopyWith<$Res> get course;
}

/// @nodoc
class _$EnrollmentWithCourseCopyWithImpl<
  $Res,
  $Val extends EnrollmentWithCourse
>
    implements $EnrollmentWithCourseCopyWith<$Res> {
  _$EnrollmentWithCourseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EnrollmentWithCourse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? courseId = null,
    Object? startedAt = null,
    Object? lastVideoId = freezed,
    Object? lastPosMs = freezed,
    Object? course = null,
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
            courseId: null == courseId
                ? _value.courseId
                : courseId // ignore: cast_nullable_to_non_nullable
                      as String,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            lastVideoId: freezed == lastVideoId
                ? _value.lastVideoId
                : lastVideoId // ignore: cast_nullable_to_non_nullable
                      as String?,
            lastPosMs: freezed == lastPosMs
                ? _value.lastPosMs
                : lastPosMs // ignore: cast_nullable_to_non_nullable
                      as int?,
            course: null == course
                ? _value.course
                : course // ignore: cast_nullable_to_non_nullable
                      as EnrolledCourseSummary,
          )
          as $Val,
    );
  }

  /// Create a copy of EnrollmentWithCourse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EnrolledCourseSummaryCopyWith<$Res> get course {
    return $EnrolledCourseSummaryCopyWith<$Res>(_value.course, (value) {
      return _then(_value.copyWith(course: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$EnrollmentWithCourseImplCopyWith<$Res>
    implements $EnrollmentWithCourseCopyWith<$Res> {
  factory _$$EnrollmentWithCourseImplCopyWith(
    _$EnrollmentWithCourseImpl value,
    $Res Function(_$EnrollmentWithCourseImpl) then,
  ) = __$$EnrollmentWithCourseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String courseId,
    DateTime startedAt,
    String? lastVideoId,
    int? lastPosMs,
    EnrolledCourseSummary course,
  });

  @override
  $EnrolledCourseSummaryCopyWith<$Res> get course;
}

/// @nodoc
class __$$EnrollmentWithCourseImplCopyWithImpl<$Res>
    extends _$EnrollmentWithCourseCopyWithImpl<$Res, _$EnrollmentWithCourseImpl>
    implements _$$EnrollmentWithCourseImplCopyWith<$Res> {
  __$$EnrollmentWithCourseImplCopyWithImpl(
    _$EnrollmentWithCourseImpl _value,
    $Res Function(_$EnrollmentWithCourseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EnrollmentWithCourse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? courseId = null,
    Object? startedAt = null,
    Object? lastVideoId = freezed,
    Object? lastPosMs = freezed,
    Object? course = null,
  }) {
    return _then(
      _$EnrollmentWithCourseImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        courseId: null == courseId
            ? _value.courseId
            : courseId // ignore: cast_nullable_to_non_nullable
                  as String,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        lastVideoId: freezed == lastVideoId
            ? _value.lastVideoId
            : lastVideoId // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastPosMs: freezed == lastPosMs
            ? _value.lastPosMs
            : lastPosMs // ignore: cast_nullable_to_non_nullable
                  as int?,
        course: null == course
            ? _value.course
            : course // ignore: cast_nullable_to_non_nullable
                  as EnrolledCourseSummary,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EnrollmentWithCourseImpl implements _EnrollmentWithCourse {
  const _$EnrollmentWithCourseImpl({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.startedAt,
    this.lastVideoId,
    this.lastPosMs,
    required this.course,
  });

  factory _$EnrollmentWithCourseImpl.fromJson(Map<String, dynamic> json) =>
      _$$EnrollmentWithCourseImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String courseId;
  @override
  final DateTime startedAt;
  @override
  final String? lastVideoId;
  @override
  final int? lastPosMs;
  @override
  final EnrolledCourseSummary course;

  @override
  String toString() {
    return 'EnrollmentWithCourse(id: $id, userId: $userId, courseId: $courseId, startedAt: $startedAt, lastVideoId: $lastVideoId, lastPosMs: $lastPosMs, course: $course)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EnrollmentWithCourseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.courseId, courseId) ||
                other.courseId == courseId) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.lastVideoId, lastVideoId) ||
                other.lastVideoId == lastVideoId) &&
            (identical(other.lastPosMs, lastPosMs) ||
                other.lastPosMs == lastPosMs) &&
            (identical(other.course, course) || other.course == course));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    courseId,
    startedAt,
    lastVideoId,
    lastPosMs,
    course,
  );

  /// Create a copy of EnrollmentWithCourse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EnrollmentWithCourseImplCopyWith<_$EnrollmentWithCourseImpl>
  get copyWith =>
      __$$EnrollmentWithCourseImplCopyWithImpl<_$EnrollmentWithCourseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EnrollmentWithCourseImplToJson(this);
  }
}

abstract class _EnrollmentWithCourse implements EnrollmentWithCourse {
  const factory _EnrollmentWithCourse({
    required final String id,
    required final String userId,
    required final String courseId,
    required final DateTime startedAt,
    final String? lastVideoId,
    final int? lastPosMs,
    required final EnrolledCourseSummary course,
  }) = _$EnrollmentWithCourseImpl;

  factory _EnrollmentWithCourse.fromJson(Map<String, dynamic> json) =
      _$EnrollmentWithCourseImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get courseId;
  @override
  DateTime get startedAt;
  @override
  String? get lastVideoId;
  @override
  int? get lastPosMs;
  @override
  EnrolledCourseSummary get course;

  /// Create a copy of EnrollmentWithCourse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EnrollmentWithCourseImplCopyWith<_$EnrollmentWithCourseImpl>
  get copyWith => throw _privateConstructorUsedError;
}
