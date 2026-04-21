// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProgressSummary _$ProgressSummaryFromJson(Map<String, dynamic> json) {
  return _ProgressSummary.fromJson(json);
}

/// @nodoc
mixin _$ProgressSummary {
  int get coursesEnrolled => throw _privateConstructorUsedError;
  int get lessonsCompleted => throw _privateConstructorUsedError;
  int get totalCuesAttempted => throw _privateConstructorUsedError;
  int get totalCuesCorrect => throw _privateConstructorUsedError;
  double? get overallAccuracy => throw _privateConstructorUsedError;
  Grade? get overallGrade => throw _privateConstructorUsedError;
  int get totalWatchTimeMs =>
      throw _privateConstructorUsedError; // Slice P3 — streak counts in the learner's local timezone. Defaults
  // accommodate older cached payloads / older API builds that don't
  // yet emit these fields (rolling-deploy safety).
  int get currentStreak => throw _privateConstructorUsedError;
  int get longestStreak => throw _privateConstructorUsedError;

  /// Serializes this ProgressSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProgressSummaryCopyWith<ProgressSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProgressSummaryCopyWith<$Res> {
  factory $ProgressSummaryCopyWith(
    ProgressSummary value,
    $Res Function(ProgressSummary) then,
  ) = _$ProgressSummaryCopyWithImpl<$Res, ProgressSummary>;
  @useResult
  $Res call({
    int coursesEnrolled,
    int lessonsCompleted,
    int totalCuesAttempted,
    int totalCuesCorrect,
    double? overallAccuracy,
    Grade? overallGrade,
    int totalWatchTimeMs,
    int currentStreak,
    int longestStreak,
  });
}

/// @nodoc
class _$ProgressSummaryCopyWithImpl<$Res, $Val extends ProgressSummary>
    implements $ProgressSummaryCopyWith<$Res> {
  _$ProgressSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? coursesEnrolled = null,
    Object? lessonsCompleted = null,
    Object? totalCuesAttempted = null,
    Object? totalCuesCorrect = null,
    Object? overallAccuracy = freezed,
    Object? overallGrade = freezed,
    Object? totalWatchTimeMs = null,
    Object? currentStreak = null,
    Object? longestStreak = null,
  }) {
    return _then(
      _value.copyWith(
            coursesEnrolled: null == coursesEnrolled
                ? _value.coursesEnrolled
                : coursesEnrolled // ignore: cast_nullable_to_non_nullable
                      as int,
            lessonsCompleted: null == lessonsCompleted
                ? _value.lessonsCompleted
                : lessonsCompleted // ignore: cast_nullable_to_non_nullable
                      as int,
            totalCuesAttempted: null == totalCuesAttempted
                ? _value.totalCuesAttempted
                : totalCuesAttempted // ignore: cast_nullable_to_non_nullable
                      as int,
            totalCuesCorrect: null == totalCuesCorrect
                ? _value.totalCuesCorrect
                : totalCuesCorrect // ignore: cast_nullable_to_non_nullable
                      as int,
            overallAccuracy: freezed == overallAccuracy
                ? _value.overallAccuracy
                : overallAccuracy // ignore: cast_nullable_to_non_nullable
                      as double?,
            overallGrade: freezed == overallGrade
                ? _value.overallGrade
                : overallGrade // ignore: cast_nullable_to_non_nullable
                      as Grade?,
            totalWatchTimeMs: null == totalWatchTimeMs
                ? _value.totalWatchTimeMs
                : totalWatchTimeMs // ignore: cast_nullable_to_non_nullable
                      as int,
            currentStreak: null == currentStreak
                ? _value.currentStreak
                : currentStreak // ignore: cast_nullable_to_non_nullable
                      as int,
            longestStreak: null == longestStreak
                ? _value.longestStreak
                : longestStreak // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProgressSummaryImplCopyWith<$Res>
    implements $ProgressSummaryCopyWith<$Res> {
  factory _$$ProgressSummaryImplCopyWith(
    _$ProgressSummaryImpl value,
    $Res Function(_$ProgressSummaryImpl) then,
  ) = __$$ProgressSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int coursesEnrolled,
    int lessonsCompleted,
    int totalCuesAttempted,
    int totalCuesCorrect,
    double? overallAccuracy,
    Grade? overallGrade,
    int totalWatchTimeMs,
    int currentStreak,
    int longestStreak,
  });
}

/// @nodoc
class __$$ProgressSummaryImplCopyWithImpl<$Res>
    extends _$ProgressSummaryCopyWithImpl<$Res, _$ProgressSummaryImpl>
    implements _$$ProgressSummaryImplCopyWith<$Res> {
  __$$ProgressSummaryImplCopyWithImpl(
    _$ProgressSummaryImpl _value,
    $Res Function(_$ProgressSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? coursesEnrolled = null,
    Object? lessonsCompleted = null,
    Object? totalCuesAttempted = null,
    Object? totalCuesCorrect = null,
    Object? overallAccuracy = freezed,
    Object? overallGrade = freezed,
    Object? totalWatchTimeMs = null,
    Object? currentStreak = null,
    Object? longestStreak = null,
  }) {
    return _then(
      _$ProgressSummaryImpl(
        coursesEnrolled: null == coursesEnrolled
            ? _value.coursesEnrolled
            : coursesEnrolled // ignore: cast_nullable_to_non_nullable
                  as int,
        lessonsCompleted: null == lessonsCompleted
            ? _value.lessonsCompleted
            : lessonsCompleted // ignore: cast_nullable_to_non_nullable
                  as int,
        totalCuesAttempted: null == totalCuesAttempted
            ? _value.totalCuesAttempted
            : totalCuesAttempted // ignore: cast_nullable_to_non_nullable
                  as int,
        totalCuesCorrect: null == totalCuesCorrect
            ? _value.totalCuesCorrect
            : totalCuesCorrect // ignore: cast_nullable_to_non_nullable
                  as int,
        overallAccuracy: freezed == overallAccuracy
            ? _value.overallAccuracy
            : overallAccuracy // ignore: cast_nullable_to_non_nullable
                  as double?,
        overallGrade: freezed == overallGrade
            ? _value.overallGrade
            : overallGrade // ignore: cast_nullable_to_non_nullable
                  as Grade?,
        totalWatchTimeMs: null == totalWatchTimeMs
            ? _value.totalWatchTimeMs
            : totalWatchTimeMs // ignore: cast_nullable_to_non_nullable
                  as int,
        currentStreak: null == currentStreak
            ? _value.currentStreak
            : currentStreak // ignore: cast_nullable_to_non_nullable
                  as int,
        longestStreak: null == longestStreak
            ? _value.longestStreak
            : longestStreak // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProgressSummaryImpl implements _ProgressSummary {
  const _$ProgressSummaryImpl({
    required this.coursesEnrolled,
    required this.lessonsCompleted,
    required this.totalCuesAttempted,
    required this.totalCuesCorrect,
    this.overallAccuracy,
    this.overallGrade,
    required this.totalWatchTimeMs,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  factory _$ProgressSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProgressSummaryImplFromJson(json);

  @override
  final int coursesEnrolled;
  @override
  final int lessonsCompleted;
  @override
  final int totalCuesAttempted;
  @override
  final int totalCuesCorrect;
  @override
  final double? overallAccuracy;
  @override
  final Grade? overallGrade;
  @override
  final int totalWatchTimeMs;
  // Slice P3 — streak counts in the learner's local timezone. Defaults
  // accommodate older cached payloads / older API builds that don't
  // yet emit these fields (rolling-deploy safety).
  @override
  @JsonKey()
  final int currentStreak;
  @override
  @JsonKey()
  final int longestStreak;

  @override
  String toString() {
    return 'ProgressSummary(coursesEnrolled: $coursesEnrolled, lessonsCompleted: $lessonsCompleted, totalCuesAttempted: $totalCuesAttempted, totalCuesCorrect: $totalCuesCorrect, overallAccuracy: $overallAccuracy, overallGrade: $overallGrade, totalWatchTimeMs: $totalWatchTimeMs, currentStreak: $currentStreak, longestStreak: $longestStreak)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProgressSummaryImpl &&
            (identical(other.coursesEnrolled, coursesEnrolled) ||
                other.coursesEnrolled == coursesEnrolled) &&
            (identical(other.lessonsCompleted, lessonsCompleted) ||
                other.lessonsCompleted == lessonsCompleted) &&
            (identical(other.totalCuesAttempted, totalCuesAttempted) ||
                other.totalCuesAttempted == totalCuesAttempted) &&
            (identical(other.totalCuesCorrect, totalCuesCorrect) ||
                other.totalCuesCorrect == totalCuesCorrect) &&
            (identical(other.overallAccuracy, overallAccuracy) ||
                other.overallAccuracy == overallAccuracy) &&
            (identical(other.overallGrade, overallGrade) ||
                other.overallGrade == overallGrade) &&
            (identical(other.totalWatchTimeMs, totalWatchTimeMs) ||
                other.totalWatchTimeMs == totalWatchTimeMs) &&
            (identical(other.currentStreak, currentStreak) ||
                other.currentStreak == currentStreak) &&
            (identical(other.longestStreak, longestStreak) ||
                other.longestStreak == longestStreak));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    coursesEnrolled,
    lessonsCompleted,
    totalCuesAttempted,
    totalCuesCorrect,
    overallAccuracy,
    overallGrade,
    totalWatchTimeMs,
    currentStreak,
    longestStreak,
  );

  /// Create a copy of ProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProgressSummaryImplCopyWith<_$ProgressSummaryImpl> get copyWith =>
      __$$ProgressSummaryImplCopyWithImpl<_$ProgressSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ProgressSummaryImplToJson(this);
  }
}

abstract class _ProgressSummary implements ProgressSummary {
  const factory _ProgressSummary({
    required final int coursesEnrolled,
    required final int lessonsCompleted,
    required final int totalCuesAttempted,
    required final int totalCuesCorrect,
    final double? overallAccuracy,
    final Grade? overallGrade,
    required final int totalWatchTimeMs,
    final int currentStreak,
    final int longestStreak,
  }) = _$ProgressSummaryImpl;

  factory _ProgressSummary.fromJson(Map<String, dynamic> json) =
      _$ProgressSummaryImpl.fromJson;

  @override
  int get coursesEnrolled;
  @override
  int get lessonsCompleted;
  @override
  int get totalCuesAttempted;
  @override
  int get totalCuesCorrect;
  @override
  double? get overallAccuracy;
  @override
  Grade? get overallGrade;
  @override
  int get totalWatchTimeMs; // Slice P3 — streak counts in the learner's local timezone. Defaults
  // accommodate older cached payloads / older API builds that don't
  // yet emit these fields (rolling-deploy safety).
  @override
  int get currentStreak;
  @override
  int get longestStreak;

  /// Create a copy of ProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProgressSummaryImplCopyWith<_$ProgressSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CourseProgressSummary _$CourseProgressSummaryFromJson(
  Map<String, dynamic> json,
) {
  return _CourseProgressSummary.fromJson(json);
}

/// @nodoc
mixin _$CourseProgressSummary {
  CourseTile get course => throw _privateConstructorUsedError;
  int get videosTotal => throw _privateConstructorUsedError;
  int get videosCompleted => throw _privateConstructorUsedError;
  double get completionPct => throw _privateConstructorUsedError;
  int get cuesAttempted => throw _privateConstructorUsedError;
  int get cuesCorrect => throw _privateConstructorUsedError;
  double? get accuracy => throw _privateConstructorUsedError;
  Grade? get grade => throw _privateConstructorUsedError;
  String? get lastVideoId => throw _privateConstructorUsedError;
  int? get lastPosMs => throw _privateConstructorUsedError;

  /// Serializes this CourseProgressSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CourseProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseProgressSummaryCopyWith<CourseProgressSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseProgressSummaryCopyWith<$Res> {
  factory $CourseProgressSummaryCopyWith(
    CourseProgressSummary value,
    $Res Function(CourseProgressSummary) then,
  ) = _$CourseProgressSummaryCopyWithImpl<$Res, CourseProgressSummary>;
  @useResult
  $Res call({
    CourseTile course,
    int videosTotal,
    int videosCompleted,
    double completionPct,
    int cuesAttempted,
    int cuesCorrect,
    double? accuracy,
    Grade? grade,
    String? lastVideoId,
    int? lastPosMs,
  });

  $CourseTileCopyWith<$Res> get course;
}

/// @nodoc
class _$CourseProgressSummaryCopyWithImpl<
  $Res,
  $Val extends CourseProgressSummary
>
    implements $CourseProgressSummaryCopyWith<$Res> {
  _$CourseProgressSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourseProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? course = null,
    Object? videosTotal = null,
    Object? videosCompleted = null,
    Object? completionPct = null,
    Object? cuesAttempted = null,
    Object? cuesCorrect = null,
    Object? accuracy = freezed,
    Object? grade = freezed,
    Object? lastVideoId = freezed,
    Object? lastPosMs = freezed,
  }) {
    return _then(
      _value.copyWith(
            course: null == course
                ? _value.course
                : course // ignore: cast_nullable_to_non_nullable
                      as CourseTile,
            videosTotal: null == videosTotal
                ? _value.videosTotal
                : videosTotal // ignore: cast_nullable_to_non_nullable
                      as int,
            videosCompleted: null == videosCompleted
                ? _value.videosCompleted
                : videosCompleted // ignore: cast_nullable_to_non_nullable
                      as int,
            completionPct: null == completionPct
                ? _value.completionPct
                : completionPct // ignore: cast_nullable_to_non_nullable
                      as double,
            cuesAttempted: null == cuesAttempted
                ? _value.cuesAttempted
                : cuesAttempted // ignore: cast_nullable_to_non_nullable
                      as int,
            cuesCorrect: null == cuesCorrect
                ? _value.cuesCorrect
                : cuesCorrect // ignore: cast_nullable_to_non_nullable
                      as int,
            accuracy: freezed == accuracy
                ? _value.accuracy
                : accuracy // ignore: cast_nullable_to_non_nullable
                      as double?,
            grade: freezed == grade
                ? _value.grade
                : grade // ignore: cast_nullable_to_non_nullable
                      as Grade?,
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

  /// Create a copy of CourseProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CourseTileCopyWith<$Res> get course {
    return $CourseTileCopyWith<$Res>(_value.course, (value) {
      return _then(_value.copyWith(course: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CourseProgressSummaryImplCopyWith<$Res>
    implements $CourseProgressSummaryCopyWith<$Res> {
  factory _$$CourseProgressSummaryImplCopyWith(
    _$CourseProgressSummaryImpl value,
    $Res Function(_$CourseProgressSummaryImpl) then,
  ) = __$$CourseProgressSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    CourseTile course,
    int videosTotal,
    int videosCompleted,
    double completionPct,
    int cuesAttempted,
    int cuesCorrect,
    double? accuracy,
    Grade? grade,
    String? lastVideoId,
    int? lastPosMs,
  });

  @override
  $CourseTileCopyWith<$Res> get course;
}

/// @nodoc
class __$$CourseProgressSummaryImplCopyWithImpl<$Res>
    extends
        _$CourseProgressSummaryCopyWithImpl<$Res, _$CourseProgressSummaryImpl>
    implements _$$CourseProgressSummaryImplCopyWith<$Res> {
  __$$CourseProgressSummaryImplCopyWithImpl(
    _$CourseProgressSummaryImpl _value,
    $Res Function(_$CourseProgressSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourseProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? course = null,
    Object? videosTotal = null,
    Object? videosCompleted = null,
    Object? completionPct = null,
    Object? cuesAttempted = null,
    Object? cuesCorrect = null,
    Object? accuracy = freezed,
    Object? grade = freezed,
    Object? lastVideoId = freezed,
    Object? lastPosMs = freezed,
  }) {
    return _then(
      _$CourseProgressSummaryImpl(
        course: null == course
            ? _value.course
            : course // ignore: cast_nullable_to_non_nullable
                  as CourseTile,
        videosTotal: null == videosTotal
            ? _value.videosTotal
            : videosTotal // ignore: cast_nullable_to_non_nullable
                  as int,
        videosCompleted: null == videosCompleted
            ? _value.videosCompleted
            : videosCompleted // ignore: cast_nullable_to_non_nullable
                  as int,
        completionPct: null == completionPct
            ? _value.completionPct
            : completionPct // ignore: cast_nullable_to_non_nullable
                  as double,
        cuesAttempted: null == cuesAttempted
            ? _value.cuesAttempted
            : cuesAttempted // ignore: cast_nullable_to_non_nullable
                  as int,
        cuesCorrect: null == cuesCorrect
            ? _value.cuesCorrect
            : cuesCorrect // ignore: cast_nullable_to_non_nullable
                  as int,
        accuracy: freezed == accuracy
            ? _value.accuracy
            : accuracy // ignore: cast_nullable_to_non_nullable
                  as double?,
        grade: freezed == grade
            ? _value.grade
            : grade // ignore: cast_nullable_to_non_nullable
                  as Grade?,
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
class _$CourseProgressSummaryImpl implements _CourseProgressSummary {
  const _$CourseProgressSummaryImpl({
    required this.course,
    required this.videosTotal,
    required this.videosCompleted,
    required this.completionPct,
    required this.cuesAttempted,
    required this.cuesCorrect,
    this.accuracy,
    this.grade,
    this.lastVideoId,
    this.lastPosMs,
  });

  factory _$CourseProgressSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseProgressSummaryImplFromJson(json);

  @override
  final CourseTile course;
  @override
  final int videosTotal;
  @override
  final int videosCompleted;
  @override
  final double completionPct;
  @override
  final int cuesAttempted;
  @override
  final int cuesCorrect;
  @override
  final double? accuracy;
  @override
  final Grade? grade;
  @override
  final String? lastVideoId;
  @override
  final int? lastPosMs;

  @override
  String toString() {
    return 'CourseProgressSummary(course: $course, videosTotal: $videosTotal, videosCompleted: $videosCompleted, completionPct: $completionPct, cuesAttempted: $cuesAttempted, cuesCorrect: $cuesCorrect, accuracy: $accuracy, grade: $grade, lastVideoId: $lastVideoId, lastPosMs: $lastPosMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseProgressSummaryImpl &&
            (identical(other.course, course) || other.course == course) &&
            (identical(other.videosTotal, videosTotal) ||
                other.videosTotal == videosTotal) &&
            (identical(other.videosCompleted, videosCompleted) ||
                other.videosCompleted == videosCompleted) &&
            (identical(other.completionPct, completionPct) ||
                other.completionPct == completionPct) &&
            (identical(other.cuesAttempted, cuesAttempted) ||
                other.cuesAttempted == cuesAttempted) &&
            (identical(other.cuesCorrect, cuesCorrect) ||
                other.cuesCorrect == cuesCorrect) &&
            (identical(other.accuracy, accuracy) ||
                other.accuracy == accuracy) &&
            (identical(other.grade, grade) || other.grade == grade) &&
            (identical(other.lastVideoId, lastVideoId) ||
                other.lastVideoId == lastVideoId) &&
            (identical(other.lastPosMs, lastPosMs) ||
                other.lastPosMs == lastPosMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    course,
    videosTotal,
    videosCompleted,
    completionPct,
    cuesAttempted,
    cuesCorrect,
    accuracy,
    grade,
    lastVideoId,
    lastPosMs,
  );

  /// Create a copy of CourseProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseProgressSummaryImplCopyWith<_$CourseProgressSummaryImpl>
  get copyWith =>
      __$$CourseProgressSummaryImplCopyWithImpl<_$CourseProgressSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseProgressSummaryImplToJson(this);
  }
}

abstract class _CourseProgressSummary implements CourseProgressSummary {
  const factory _CourseProgressSummary({
    required final CourseTile course,
    required final int videosTotal,
    required final int videosCompleted,
    required final double completionPct,
    required final int cuesAttempted,
    required final int cuesCorrect,
    final double? accuracy,
    final Grade? grade,
    final String? lastVideoId,
    final int? lastPosMs,
  }) = _$CourseProgressSummaryImpl;

  factory _CourseProgressSummary.fromJson(Map<String, dynamic> json) =
      _$CourseProgressSummaryImpl.fromJson;

  @override
  CourseTile get course;
  @override
  int get videosTotal;
  @override
  int get videosCompleted;
  @override
  double get completionPct;
  @override
  int get cuesAttempted;
  @override
  int get cuesCorrect;
  @override
  double? get accuracy;
  @override
  Grade? get grade;
  @override
  String? get lastVideoId;
  @override
  int? get lastPosMs;

  /// Create a copy of CourseProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseProgressSummaryImplCopyWith<_$CourseProgressSummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

CourseTile _$CourseTileFromJson(Map<String, dynamic> json) {
  return _CourseTile.fromJson(json);
}

/// @nodoc
mixin _$CourseTile {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  String? get coverImageUrl => throw _privateConstructorUsedError;

  /// Serializes this CourseTile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CourseTile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseTileCopyWith<CourseTile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseTileCopyWith<$Res> {
  factory $CourseTileCopyWith(
    CourseTile value,
    $Res Function(CourseTile) then,
  ) = _$CourseTileCopyWithImpl<$Res, CourseTile>;
  @useResult
  $Res call({String id, String title, String slug, String? coverImageUrl});
}

/// @nodoc
class _$CourseTileCopyWithImpl<$Res, $Val extends CourseTile>
    implements $CourseTileCopyWith<$Res> {
  _$CourseTileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourseTile
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
abstract class _$$CourseTileImplCopyWith<$Res>
    implements $CourseTileCopyWith<$Res> {
  factory _$$CourseTileImplCopyWith(
    _$CourseTileImpl value,
    $Res Function(_$CourseTileImpl) then,
  ) = __$$CourseTileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, String slug, String? coverImageUrl});
}

/// @nodoc
class __$$CourseTileImplCopyWithImpl<$Res>
    extends _$CourseTileCopyWithImpl<$Res, _$CourseTileImpl>
    implements _$$CourseTileImplCopyWith<$Res> {
  __$$CourseTileImplCopyWithImpl(
    _$CourseTileImpl _value,
    $Res Function(_$CourseTileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourseTile
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
      _$CourseTileImpl(
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
class _$CourseTileImpl implements _CourseTile {
  const _$CourseTileImpl({
    required this.id,
    required this.title,
    required this.slug,
    this.coverImageUrl,
  });

  factory _$CourseTileImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseTileImplFromJson(json);

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
    return 'CourseTile(id: $id, title: $title, slug: $slug, coverImageUrl: $coverImageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseTileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, slug, coverImageUrl);

  /// Create a copy of CourseTile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseTileImplCopyWith<_$CourseTileImpl> get copyWith =>
      __$$CourseTileImplCopyWithImpl<_$CourseTileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseTileImplToJson(this);
  }
}

abstract class _CourseTile implements CourseTile {
  const factory _CourseTile({
    required final String id,
    required final String title,
    required final String slug,
    final String? coverImageUrl,
  }) = _$CourseTileImpl;

  factory _CourseTile.fromJson(Map<String, dynamic> json) =
      _$CourseTileImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get slug;
  @override
  String? get coverImageUrl;

  /// Create a copy of CourseTile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseTileImplCopyWith<_$CourseTileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LessonProgressSummary _$LessonProgressSummaryFromJson(
  Map<String, dynamic> json,
) {
  return _LessonProgressSummary.fromJson(json);
}

/// @nodoc
mixin _$LessonProgressSummary {
  String get videoId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  int get orderIndex => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;
  int get cueCount => throw _privateConstructorUsedError;
  int get cuesAttempted => throw _privateConstructorUsedError;
  int get cuesCorrect => throw _privateConstructorUsedError;
  double? get accuracy => throw _privateConstructorUsedError;
  Grade? get grade => throw _privateConstructorUsedError;
  bool get completed => throw _privateConstructorUsedError;

  /// Serializes this LessonProgressSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LessonProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LessonProgressSummaryCopyWith<LessonProgressSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LessonProgressSummaryCopyWith<$Res> {
  factory $LessonProgressSummaryCopyWith(
    LessonProgressSummary value,
    $Res Function(LessonProgressSummary) then,
  ) = _$LessonProgressSummaryCopyWithImpl<$Res, LessonProgressSummary>;
  @useResult
  $Res call({
    String videoId,
    String title,
    int orderIndex,
    int? durationMs,
    int cueCount,
    int cuesAttempted,
    int cuesCorrect,
    double? accuracy,
    Grade? grade,
    bool completed,
  });
}

/// @nodoc
class _$LessonProgressSummaryCopyWithImpl<
  $Res,
  $Val extends LessonProgressSummary
>
    implements $LessonProgressSummaryCopyWith<$Res> {
  _$LessonProgressSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LessonProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? title = null,
    Object? orderIndex = null,
    Object? durationMs = freezed,
    Object? cueCount = null,
    Object? cuesAttempted = null,
    Object? cuesCorrect = null,
    Object? accuracy = freezed,
    Object? grade = freezed,
    Object? completed = null,
  }) {
    return _then(
      _value.copyWith(
            videoId: null == videoId
                ? _value.videoId
                : videoId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            orderIndex: null == orderIndex
                ? _value.orderIndex
                : orderIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            durationMs: freezed == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int?,
            cueCount: null == cueCount
                ? _value.cueCount
                : cueCount // ignore: cast_nullable_to_non_nullable
                      as int,
            cuesAttempted: null == cuesAttempted
                ? _value.cuesAttempted
                : cuesAttempted // ignore: cast_nullable_to_non_nullable
                      as int,
            cuesCorrect: null == cuesCorrect
                ? _value.cuesCorrect
                : cuesCorrect // ignore: cast_nullable_to_non_nullable
                      as int,
            accuracy: freezed == accuracy
                ? _value.accuracy
                : accuracy // ignore: cast_nullable_to_non_nullable
                      as double?,
            grade: freezed == grade
                ? _value.grade
                : grade // ignore: cast_nullable_to_non_nullable
                      as Grade?,
            completed: null == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LessonProgressSummaryImplCopyWith<$Res>
    implements $LessonProgressSummaryCopyWith<$Res> {
  factory _$$LessonProgressSummaryImplCopyWith(
    _$LessonProgressSummaryImpl value,
    $Res Function(_$LessonProgressSummaryImpl) then,
  ) = __$$LessonProgressSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String videoId,
    String title,
    int orderIndex,
    int? durationMs,
    int cueCount,
    int cuesAttempted,
    int cuesCorrect,
    double? accuracy,
    Grade? grade,
    bool completed,
  });
}

/// @nodoc
class __$$LessonProgressSummaryImplCopyWithImpl<$Res>
    extends
        _$LessonProgressSummaryCopyWithImpl<$Res, _$LessonProgressSummaryImpl>
    implements _$$LessonProgressSummaryImplCopyWith<$Res> {
  __$$LessonProgressSummaryImplCopyWithImpl(
    _$LessonProgressSummaryImpl _value,
    $Res Function(_$LessonProgressSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LessonProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? title = null,
    Object? orderIndex = null,
    Object? durationMs = freezed,
    Object? cueCount = null,
    Object? cuesAttempted = null,
    Object? cuesCorrect = null,
    Object? accuracy = freezed,
    Object? grade = freezed,
    Object? completed = null,
  }) {
    return _then(
      _$LessonProgressSummaryImpl(
        videoId: null == videoId
            ? _value.videoId
            : videoId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        orderIndex: null == orderIndex
            ? _value.orderIndex
            : orderIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        durationMs: freezed == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int?,
        cueCount: null == cueCount
            ? _value.cueCount
            : cueCount // ignore: cast_nullable_to_non_nullable
                  as int,
        cuesAttempted: null == cuesAttempted
            ? _value.cuesAttempted
            : cuesAttempted // ignore: cast_nullable_to_non_nullable
                  as int,
        cuesCorrect: null == cuesCorrect
            ? _value.cuesCorrect
            : cuesCorrect // ignore: cast_nullable_to_non_nullable
                  as int,
        accuracy: freezed == accuracy
            ? _value.accuracy
            : accuracy // ignore: cast_nullable_to_non_nullable
                  as double?,
        grade: freezed == grade
            ? _value.grade
            : grade // ignore: cast_nullable_to_non_nullable
                  as Grade?,
        completed: null == completed
            ? _value.completed
            : completed // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LessonProgressSummaryImpl implements _LessonProgressSummary {
  const _$LessonProgressSummaryImpl({
    required this.videoId,
    required this.title,
    required this.orderIndex,
    this.durationMs,
    required this.cueCount,
    required this.cuesAttempted,
    required this.cuesCorrect,
    this.accuracy,
    this.grade,
    required this.completed,
  });

  factory _$LessonProgressSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$LessonProgressSummaryImplFromJson(json);

  @override
  final String videoId;
  @override
  final String title;
  @override
  final int orderIndex;
  @override
  final int? durationMs;
  @override
  final int cueCount;
  @override
  final int cuesAttempted;
  @override
  final int cuesCorrect;
  @override
  final double? accuracy;
  @override
  final Grade? grade;
  @override
  final bool completed;

  @override
  String toString() {
    return 'LessonProgressSummary(videoId: $videoId, title: $title, orderIndex: $orderIndex, durationMs: $durationMs, cueCount: $cueCount, cuesAttempted: $cuesAttempted, cuesCorrect: $cuesCorrect, accuracy: $accuracy, grade: $grade, completed: $completed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LessonProgressSummaryImpl &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.cueCount, cueCount) ||
                other.cueCount == cueCount) &&
            (identical(other.cuesAttempted, cuesAttempted) ||
                other.cuesAttempted == cuesAttempted) &&
            (identical(other.cuesCorrect, cuesCorrect) ||
                other.cuesCorrect == cuesCorrect) &&
            (identical(other.accuracy, accuracy) ||
                other.accuracy == accuracy) &&
            (identical(other.grade, grade) || other.grade == grade) &&
            (identical(other.completed, completed) ||
                other.completed == completed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    videoId,
    title,
    orderIndex,
    durationMs,
    cueCount,
    cuesAttempted,
    cuesCorrect,
    accuracy,
    grade,
    completed,
  );

  /// Create a copy of LessonProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LessonProgressSummaryImplCopyWith<_$LessonProgressSummaryImpl>
  get copyWith =>
      __$$LessonProgressSummaryImplCopyWithImpl<_$LessonProgressSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LessonProgressSummaryImplToJson(this);
  }
}

abstract class _LessonProgressSummary implements LessonProgressSummary {
  const factory _LessonProgressSummary({
    required final String videoId,
    required final String title,
    required final int orderIndex,
    final int? durationMs,
    required final int cueCount,
    required final int cuesAttempted,
    required final int cuesCorrect,
    final double? accuracy,
    final Grade? grade,
    required final bool completed,
  }) = _$LessonProgressSummaryImpl;

  factory _LessonProgressSummary.fromJson(Map<String, dynamic> json) =
      _$LessonProgressSummaryImpl.fromJson;

  @override
  String get videoId;
  @override
  String get title;
  @override
  int get orderIndex;
  @override
  int? get durationMs;
  @override
  int get cueCount;
  @override
  int get cuesAttempted;
  @override
  int get cuesCorrect;
  @override
  double? get accuracy;
  @override
  Grade? get grade;
  @override
  bool get completed;

  /// Create a copy of LessonProgressSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LessonProgressSummaryImplCopyWith<_$LessonProgressSummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

CourseProgressDetail _$CourseProgressDetailFromJson(Map<String, dynamic> json) {
  return _CourseProgressDetail.fromJson(json);
}

/// @nodoc
mixin _$CourseProgressDetail {
  CourseTile get course => throw _privateConstructorUsedError;
  int get videosTotal => throw _privateConstructorUsedError;
  int get videosCompleted => throw _privateConstructorUsedError;
  double get completionPct => throw _privateConstructorUsedError;
  int get cuesAttempted => throw _privateConstructorUsedError;
  int get cuesCorrect => throw _privateConstructorUsedError;
  double? get accuracy => throw _privateConstructorUsedError;
  Grade? get grade => throw _privateConstructorUsedError;
  String? get lastVideoId => throw _privateConstructorUsedError;
  int? get lastPosMs => throw _privateConstructorUsedError;
  List<LessonProgressSummary> get lessons => throw _privateConstructorUsedError;

  /// Serializes this CourseProgressDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CourseProgressDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseProgressDetailCopyWith<CourseProgressDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseProgressDetailCopyWith<$Res> {
  factory $CourseProgressDetailCopyWith(
    CourseProgressDetail value,
    $Res Function(CourseProgressDetail) then,
  ) = _$CourseProgressDetailCopyWithImpl<$Res, CourseProgressDetail>;
  @useResult
  $Res call({
    CourseTile course,
    int videosTotal,
    int videosCompleted,
    double completionPct,
    int cuesAttempted,
    int cuesCorrect,
    double? accuracy,
    Grade? grade,
    String? lastVideoId,
    int? lastPosMs,
    List<LessonProgressSummary> lessons,
  });

  $CourseTileCopyWith<$Res> get course;
}

/// @nodoc
class _$CourseProgressDetailCopyWithImpl<
  $Res,
  $Val extends CourseProgressDetail
>
    implements $CourseProgressDetailCopyWith<$Res> {
  _$CourseProgressDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourseProgressDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? course = null,
    Object? videosTotal = null,
    Object? videosCompleted = null,
    Object? completionPct = null,
    Object? cuesAttempted = null,
    Object? cuesCorrect = null,
    Object? accuracy = freezed,
    Object? grade = freezed,
    Object? lastVideoId = freezed,
    Object? lastPosMs = freezed,
    Object? lessons = null,
  }) {
    return _then(
      _value.copyWith(
            course: null == course
                ? _value.course
                : course // ignore: cast_nullable_to_non_nullable
                      as CourseTile,
            videosTotal: null == videosTotal
                ? _value.videosTotal
                : videosTotal // ignore: cast_nullable_to_non_nullable
                      as int,
            videosCompleted: null == videosCompleted
                ? _value.videosCompleted
                : videosCompleted // ignore: cast_nullable_to_non_nullable
                      as int,
            completionPct: null == completionPct
                ? _value.completionPct
                : completionPct // ignore: cast_nullable_to_non_nullable
                      as double,
            cuesAttempted: null == cuesAttempted
                ? _value.cuesAttempted
                : cuesAttempted // ignore: cast_nullable_to_non_nullable
                      as int,
            cuesCorrect: null == cuesCorrect
                ? _value.cuesCorrect
                : cuesCorrect // ignore: cast_nullable_to_non_nullable
                      as int,
            accuracy: freezed == accuracy
                ? _value.accuracy
                : accuracy // ignore: cast_nullable_to_non_nullable
                      as double?,
            grade: freezed == grade
                ? _value.grade
                : grade // ignore: cast_nullable_to_non_nullable
                      as Grade?,
            lastVideoId: freezed == lastVideoId
                ? _value.lastVideoId
                : lastVideoId // ignore: cast_nullable_to_non_nullable
                      as String?,
            lastPosMs: freezed == lastPosMs
                ? _value.lastPosMs
                : lastPosMs // ignore: cast_nullable_to_non_nullable
                      as int?,
            lessons: null == lessons
                ? _value.lessons
                : lessons // ignore: cast_nullable_to_non_nullable
                      as List<LessonProgressSummary>,
          )
          as $Val,
    );
  }

  /// Create a copy of CourseProgressDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CourseTileCopyWith<$Res> get course {
    return $CourseTileCopyWith<$Res>(_value.course, (value) {
      return _then(_value.copyWith(course: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CourseProgressDetailImplCopyWith<$Res>
    implements $CourseProgressDetailCopyWith<$Res> {
  factory _$$CourseProgressDetailImplCopyWith(
    _$CourseProgressDetailImpl value,
    $Res Function(_$CourseProgressDetailImpl) then,
  ) = __$$CourseProgressDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    CourseTile course,
    int videosTotal,
    int videosCompleted,
    double completionPct,
    int cuesAttempted,
    int cuesCorrect,
    double? accuracy,
    Grade? grade,
    String? lastVideoId,
    int? lastPosMs,
    List<LessonProgressSummary> lessons,
  });

  @override
  $CourseTileCopyWith<$Res> get course;
}

/// @nodoc
class __$$CourseProgressDetailImplCopyWithImpl<$Res>
    extends _$CourseProgressDetailCopyWithImpl<$Res, _$CourseProgressDetailImpl>
    implements _$$CourseProgressDetailImplCopyWith<$Res> {
  __$$CourseProgressDetailImplCopyWithImpl(
    _$CourseProgressDetailImpl _value,
    $Res Function(_$CourseProgressDetailImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourseProgressDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? course = null,
    Object? videosTotal = null,
    Object? videosCompleted = null,
    Object? completionPct = null,
    Object? cuesAttempted = null,
    Object? cuesCorrect = null,
    Object? accuracy = freezed,
    Object? grade = freezed,
    Object? lastVideoId = freezed,
    Object? lastPosMs = freezed,
    Object? lessons = null,
  }) {
    return _then(
      _$CourseProgressDetailImpl(
        course: null == course
            ? _value.course
            : course // ignore: cast_nullable_to_non_nullable
                  as CourseTile,
        videosTotal: null == videosTotal
            ? _value.videosTotal
            : videosTotal // ignore: cast_nullable_to_non_nullable
                  as int,
        videosCompleted: null == videosCompleted
            ? _value.videosCompleted
            : videosCompleted // ignore: cast_nullable_to_non_nullable
                  as int,
        completionPct: null == completionPct
            ? _value.completionPct
            : completionPct // ignore: cast_nullable_to_non_nullable
                  as double,
        cuesAttempted: null == cuesAttempted
            ? _value.cuesAttempted
            : cuesAttempted // ignore: cast_nullable_to_non_nullable
                  as int,
        cuesCorrect: null == cuesCorrect
            ? _value.cuesCorrect
            : cuesCorrect // ignore: cast_nullable_to_non_nullable
                  as int,
        accuracy: freezed == accuracy
            ? _value.accuracy
            : accuracy // ignore: cast_nullable_to_non_nullable
                  as double?,
        grade: freezed == grade
            ? _value.grade
            : grade // ignore: cast_nullable_to_non_nullable
                  as Grade?,
        lastVideoId: freezed == lastVideoId
            ? _value.lastVideoId
            : lastVideoId // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastPosMs: freezed == lastPosMs
            ? _value.lastPosMs
            : lastPosMs // ignore: cast_nullable_to_non_nullable
                  as int?,
        lessons: null == lessons
            ? _value._lessons
            : lessons // ignore: cast_nullable_to_non_nullable
                  as List<LessonProgressSummary>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CourseProgressDetailImpl implements _CourseProgressDetail {
  const _$CourseProgressDetailImpl({
    required this.course,
    required this.videosTotal,
    required this.videosCompleted,
    required this.completionPct,
    required this.cuesAttempted,
    required this.cuesCorrect,
    this.accuracy,
    this.grade,
    this.lastVideoId,
    this.lastPosMs,
    required final List<LessonProgressSummary> lessons,
  }) : _lessons = lessons;

  factory _$CourseProgressDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseProgressDetailImplFromJson(json);

  @override
  final CourseTile course;
  @override
  final int videosTotal;
  @override
  final int videosCompleted;
  @override
  final double completionPct;
  @override
  final int cuesAttempted;
  @override
  final int cuesCorrect;
  @override
  final double? accuracy;
  @override
  final Grade? grade;
  @override
  final String? lastVideoId;
  @override
  final int? lastPosMs;
  final List<LessonProgressSummary> _lessons;
  @override
  List<LessonProgressSummary> get lessons {
    if (_lessons is EqualUnmodifiableListView) return _lessons;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_lessons);
  }

  @override
  String toString() {
    return 'CourseProgressDetail(course: $course, videosTotal: $videosTotal, videosCompleted: $videosCompleted, completionPct: $completionPct, cuesAttempted: $cuesAttempted, cuesCorrect: $cuesCorrect, accuracy: $accuracy, grade: $grade, lastVideoId: $lastVideoId, lastPosMs: $lastPosMs, lessons: $lessons)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseProgressDetailImpl &&
            (identical(other.course, course) || other.course == course) &&
            (identical(other.videosTotal, videosTotal) ||
                other.videosTotal == videosTotal) &&
            (identical(other.videosCompleted, videosCompleted) ||
                other.videosCompleted == videosCompleted) &&
            (identical(other.completionPct, completionPct) ||
                other.completionPct == completionPct) &&
            (identical(other.cuesAttempted, cuesAttempted) ||
                other.cuesAttempted == cuesAttempted) &&
            (identical(other.cuesCorrect, cuesCorrect) ||
                other.cuesCorrect == cuesCorrect) &&
            (identical(other.accuracy, accuracy) ||
                other.accuracy == accuracy) &&
            (identical(other.grade, grade) || other.grade == grade) &&
            (identical(other.lastVideoId, lastVideoId) ||
                other.lastVideoId == lastVideoId) &&
            (identical(other.lastPosMs, lastPosMs) ||
                other.lastPosMs == lastPosMs) &&
            const DeepCollectionEquality().equals(other._lessons, _lessons));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    course,
    videosTotal,
    videosCompleted,
    completionPct,
    cuesAttempted,
    cuesCorrect,
    accuracy,
    grade,
    lastVideoId,
    lastPosMs,
    const DeepCollectionEquality().hash(_lessons),
  );

  /// Create a copy of CourseProgressDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseProgressDetailImplCopyWith<_$CourseProgressDetailImpl>
  get copyWith =>
      __$$CourseProgressDetailImplCopyWithImpl<_$CourseProgressDetailImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseProgressDetailImplToJson(this);
  }
}

abstract class _CourseProgressDetail implements CourseProgressDetail {
  const factory _CourseProgressDetail({
    required final CourseTile course,
    required final int videosTotal,
    required final int videosCompleted,
    required final double completionPct,
    required final int cuesAttempted,
    required final int cuesCorrect,
    final double? accuracy,
    final Grade? grade,
    final String? lastVideoId,
    final int? lastPosMs,
    required final List<LessonProgressSummary> lessons,
  }) = _$CourseProgressDetailImpl;

  factory _CourseProgressDetail.fromJson(Map<String, dynamic> json) =
      _$CourseProgressDetailImpl.fromJson;

  @override
  CourseTile get course;
  @override
  int get videosTotal;
  @override
  int get videosCompleted;
  @override
  double get completionPct;
  @override
  int get cuesAttempted;
  @override
  int get cuesCorrect;
  @override
  double? get accuracy;
  @override
  Grade? get grade;
  @override
  String? get lastVideoId;
  @override
  int? get lastPosMs;
  @override
  List<LessonProgressSummary> get lessons;

  /// Create a copy of CourseProgressDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseProgressDetailImplCopyWith<_$CourseProgressDetailImpl>
  get copyWith => throw _privateConstructorUsedError;
}

OverallProgress _$OverallProgressFromJson(Map<String, dynamic> json) {
  return _OverallProgress.fromJson(json);
}

/// @nodoc
mixin _$OverallProgress {
  ProgressSummary get summary => throw _privateConstructorUsedError;
  List<CourseProgressSummary> get perCourse =>
      throw _privateConstructorUsedError; // Slice P3 — achievements that newly unlocked on THIS response. The
  // client pops a SnackBar per entry then drops the field; it is not
  // a persistent list. Defaulted so older API builds that don't yet
  // emit the field don't crash the decoder.
  List<AchievementSummary> get recentlyUnlocked =>
      throw _privateConstructorUsedError;

  /// Serializes this OverallProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OverallProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OverallProgressCopyWith<OverallProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OverallProgressCopyWith<$Res> {
  factory $OverallProgressCopyWith(
    OverallProgress value,
    $Res Function(OverallProgress) then,
  ) = _$OverallProgressCopyWithImpl<$Res, OverallProgress>;
  @useResult
  $Res call({
    ProgressSummary summary,
    List<CourseProgressSummary> perCourse,
    List<AchievementSummary> recentlyUnlocked,
  });

  $ProgressSummaryCopyWith<$Res> get summary;
}

/// @nodoc
class _$OverallProgressCopyWithImpl<$Res, $Val extends OverallProgress>
    implements $OverallProgressCopyWith<$Res> {
  _$OverallProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OverallProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? summary = null,
    Object? perCourse = null,
    Object? recentlyUnlocked = null,
  }) {
    return _then(
      _value.copyWith(
            summary: null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as ProgressSummary,
            perCourse: null == perCourse
                ? _value.perCourse
                : perCourse // ignore: cast_nullable_to_non_nullable
                      as List<CourseProgressSummary>,
            recentlyUnlocked: null == recentlyUnlocked
                ? _value.recentlyUnlocked
                : recentlyUnlocked // ignore: cast_nullable_to_non_nullable
                      as List<AchievementSummary>,
          )
          as $Val,
    );
  }

  /// Create a copy of OverallProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProgressSummaryCopyWith<$Res> get summary {
    return $ProgressSummaryCopyWith<$Res>(_value.summary, (value) {
      return _then(_value.copyWith(summary: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OverallProgressImplCopyWith<$Res>
    implements $OverallProgressCopyWith<$Res> {
  factory _$$OverallProgressImplCopyWith(
    _$OverallProgressImpl value,
    $Res Function(_$OverallProgressImpl) then,
  ) = __$$OverallProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    ProgressSummary summary,
    List<CourseProgressSummary> perCourse,
    List<AchievementSummary> recentlyUnlocked,
  });

  @override
  $ProgressSummaryCopyWith<$Res> get summary;
}

/// @nodoc
class __$$OverallProgressImplCopyWithImpl<$Res>
    extends _$OverallProgressCopyWithImpl<$Res, _$OverallProgressImpl>
    implements _$$OverallProgressImplCopyWith<$Res> {
  __$$OverallProgressImplCopyWithImpl(
    _$OverallProgressImpl _value,
    $Res Function(_$OverallProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OverallProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? summary = null,
    Object? perCourse = null,
    Object? recentlyUnlocked = null,
  }) {
    return _then(
      _$OverallProgressImpl(
        summary: null == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as ProgressSummary,
        perCourse: null == perCourse
            ? _value._perCourse
            : perCourse // ignore: cast_nullable_to_non_nullable
                  as List<CourseProgressSummary>,
        recentlyUnlocked: null == recentlyUnlocked
            ? _value._recentlyUnlocked
            : recentlyUnlocked // ignore: cast_nullable_to_non_nullable
                  as List<AchievementSummary>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OverallProgressImpl implements _OverallProgress {
  const _$OverallProgressImpl({
    required this.summary,
    required final List<CourseProgressSummary> perCourse,
    final List<AchievementSummary> recentlyUnlocked =
        const <AchievementSummary>[],
  }) : _perCourse = perCourse,
       _recentlyUnlocked = recentlyUnlocked;

  factory _$OverallProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$OverallProgressImplFromJson(json);

  @override
  final ProgressSummary summary;
  final List<CourseProgressSummary> _perCourse;
  @override
  List<CourseProgressSummary> get perCourse {
    if (_perCourse is EqualUnmodifiableListView) return _perCourse;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_perCourse);
  }

  // Slice P3 — achievements that newly unlocked on THIS response. The
  // client pops a SnackBar per entry then drops the field; it is not
  // a persistent list. Defaulted so older API builds that don't yet
  // emit the field don't crash the decoder.
  final List<AchievementSummary> _recentlyUnlocked;
  // Slice P3 — achievements that newly unlocked on THIS response. The
  // client pops a SnackBar per entry then drops the field; it is not
  // a persistent list. Defaulted so older API builds that don't yet
  // emit the field don't crash the decoder.
  @override
  @JsonKey()
  List<AchievementSummary> get recentlyUnlocked {
    if (_recentlyUnlocked is EqualUnmodifiableListView)
      return _recentlyUnlocked;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentlyUnlocked);
  }

  @override
  String toString() {
    return 'OverallProgress(summary: $summary, perCourse: $perCourse, recentlyUnlocked: $recentlyUnlocked)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OverallProgressImpl &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality().equals(
              other._perCourse,
              _perCourse,
            ) &&
            const DeepCollectionEquality().equals(
              other._recentlyUnlocked,
              _recentlyUnlocked,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    summary,
    const DeepCollectionEquality().hash(_perCourse),
    const DeepCollectionEquality().hash(_recentlyUnlocked),
  );

  /// Create a copy of OverallProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OverallProgressImplCopyWith<_$OverallProgressImpl> get copyWith =>
      __$$OverallProgressImplCopyWithImpl<_$OverallProgressImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$OverallProgressImplToJson(this);
  }
}

abstract class _OverallProgress implements OverallProgress {
  const factory _OverallProgress({
    required final ProgressSummary summary,
    required final List<CourseProgressSummary> perCourse,
    final List<AchievementSummary> recentlyUnlocked,
  }) = _$OverallProgressImpl;

  factory _OverallProgress.fromJson(Map<String, dynamic> json) =
      _$OverallProgressImpl.fromJson;

  @override
  ProgressSummary get summary;
  @override
  List<CourseProgressSummary> get perCourse; // Slice P3 — achievements that newly unlocked on THIS response. The
  // client pops a SnackBar per entry then drops the field; it is not
  // a persistent list. Defaulted so older API builds that don't yet
  // emit the field don't crash the decoder.
  @override
  List<AchievementSummary> get recentlyUnlocked;

  /// Create a copy of OverallProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OverallProgressImplCopyWith<_$OverallProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LessonVideoRef _$LessonVideoRefFromJson(Map<String, dynamic> json) {
  return _LessonVideoRef.fromJson(json);
}

/// @nodoc
mixin _$LessonVideoRef {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  int get orderIndex => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;
  String get courseId => throw _privateConstructorUsedError;

  /// Serializes this LessonVideoRef to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LessonVideoRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LessonVideoRefCopyWith<LessonVideoRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LessonVideoRefCopyWith<$Res> {
  factory $LessonVideoRefCopyWith(
    LessonVideoRef value,
    $Res Function(LessonVideoRef) then,
  ) = _$LessonVideoRefCopyWithImpl<$Res, LessonVideoRef>;
  @useResult
  $Res call({
    String id,
    String title,
    int orderIndex,
    int? durationMs,
    String courseId,
  });
}

/// @nodoc
class _$LessonVideoRefCopyWithImpl<$Res, $Val extends LessonVideoRef>
    implements $LessonVideoRefCopyWith<$Res> {
  _$LessonVideoRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LessonVideoRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? orderIndex = null,
    Object? durationMs = freezed,
    Object? courseId = null,
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
            durationMs: freezed == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int?,
            courseId: null == courseId
                ? _value.courseId
                : courseId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LessonVideoRefImplCopyWith<$Res>
    implements $LessonVideoRefCopyWith<$Res> {
  factory _$$LessonVideoRefImplCopyWith(
    _$LessonVideoRefImpl value,
    $Res Function(_$LessonVideoRefImpl) then,
  ) = __$$LessonVideoRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    int orderIndex,
    int? durationMs,
    String courseId,
  });
}

/// @nodoc
class __$$LessonVideoRefImplCopyWithImpl<$Res>
    extends _$LessonVideoRefCopyWithImpl<$Res, _$LessonVideoRefImpl>
    implements _$$LessonVideoRefImplCopyWith<$Res> {
  __$$LessonVideoRefImplCopyWithImpl(
    _$LessonVideoRefImpl _value,
    $Res Function(_$LessonVideoRefImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LessonVideoRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? orderIndex = null,
    Object? durationMs = freezed,
    Object? courseId = null,
  }) {
    return _then(
      _$LessonVideoRefImpl(
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
        durationMs: freezed == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int?,
        courseId: null == courseId
            ? _value.courseId
            : courseId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LessonVideoRefImpl implements _LessonVideoRef {
  const _$LessonVideoRefImpl({
    required this.id,
    required this.title,
    required this.orderIndex,
    this.durationMs,
    required this.courseId,
  });

  factory _$LessonVideoRefImpl.fromJson(Map<String, dynamic> json) =>
      _$$LessonVideoRefImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final int orderIndex;
  @override
  final int? durationMs;
  @override
  final String courseId;

  @override
  String toString() {
    return 'LessonVideoRef(id: $id, title: $title, orderIndex: $orderIndex, durationMs: $durationMs, courseId: $courseId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LessonVideoRefImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.courseId, courseId) ||
                other.courseId == courseId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, orderIndex, durationMs, courseId);

  /// Create a copy of LessonVideoRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LessonVideoRefImplCopyWith<_$LessonVideoRefImpl> get copyWith =>
      __$$LessonVideoRefImplCopyWithImpl<_$LessonVideoRefImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LessonVideoRefImplToJson(this);
  }
}

abstract class _LessonVideoRef implements LessonVideoRef {
  const factory _LessonVideoRef({
    required final String id,
    required final String title,
    required final int orderIndex,
    final int? durationMs,
    required final String courseId,
  }) = _$LessonVideoRefImpl;

  factory _LessonVideoRef.fromJson(Map<String, dynamic> json) =
      _$LessonVideoRefImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  int get orderIndex;
  @override
  int? get durationMs;
  @override
  String get courseId;

  /// Create a copy of LessonVideoRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LessonVideoRefImplCopyWith<_$LessonVideoRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LessonScore _$LessonScoreFromJson(Map<String, dynamic> json) {
  return _LessonScore.fromJson(json);
}

/// @nodoc
mixin _$LessonScore {
  int get cuesAttempted => throw _privateConstructorUsedError;
  int get cuesCorrect => throw _privateConstructorUsedError;
  double? get accuracy => throw _privateConstructorUsedError;
  Grade? get grade => throw _privateConstructorUsedError;

  /// Serializes this LessonScore to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LessonScore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LessonScoreCopyWith<LessonScore> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LessonScoreCopyWith<$Res> {
  factory $LessonScoreCopyWith(
    LessonScore value,
    $Res Function(LessonScore) then,
  ) = _$LessonScoreCopyWithImpl<$Res, LessonScore>;
  @useResult
  $Res call({
    int cuesAttempted,
    int cuesCorrect,
    double? accuracy,
    Grade? grade,
  });
}

/// @nodoc
class _$LessonScoreCopyWithImpl<$Res, $Val extends LessonScore>
    implements $LessonScoreCopyWith<$Res> {
  _$LessonScoreCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LessonScore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cuesAttempted = null,
    Object? cuesCorrect = null,
    Object? accuracy = freezed,
    Object? grade = freezed,
  }) {
    return _then(
      _value.copyWith(
            cuesAttempted: null == cuesAttempted
                ? _value.cuesAttempted
                : cuesAttempted // ignore: cast_nullable_to_non_nullable
                      as int,
            cuesCorrect: null == cuesCorrect
                ? _value.cuesCorrect
                : cuesCorrect // ignore: cast_nullable_to_non_nullable
                      as int,
            accuracy: freezed == accuracy
                ? _value.accuracy
                : accuracy // ignore: cast_nullable_to_non_nullable
                      as double?,
            grade: freezed == grade
                ? _value.grade
                : grade // ignore: cast_nullable_to_non_nullable
                      as Grade?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LessonScoreImplCopyWith<$Res>
    implements $LessonScoreCopyWith<$Res> {
  factory _$$LessonScoreImplCopyWith(
    _$LessonScoreImpl value,
    $Res Function(_$LessonScoreImpl) then,
  ) = __$$LessonScoreImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int cuesAttempted,
    int cuesCorrect,
    double? accuracy,
    Grade? grade,
  });
}

/// @nodoc
class __$$LessonScoreImplCopyWithImpl<$Res>
    extends _$LessonScoreCopyWithImpl<$Res, _$LessonScoreImpl>
    implements _$$LessonScoreImplCopyWith<$Res> {
  __$$LessonScoreImplCopyWithImpl(
    _$LessonScoreImpl _value,
    $Res Function(_$LessonScoreImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LessonScore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cuesAttempted = null,
    Object? cuesCorrect = null,
    Object? accuracy = freezed,
    Object? grade = freezed,
  }) {
    return _then(
      _$LessonScoreImpl(
        cuesAttempted: null == cuesAttempted
            ? _value.cuesAttempted
            : cuesAttempted // ignore: cast_nullable_to_non_nullable
                  as int,
        cuesCorrect: null == cuesCorrect
            ? _value.cuesCorrect
            : cuesCorrect // ignore: cast_nullable_to_non_nullable
                  as int,
        accuracy: freezed == accuracy
            ? _value.accuracy
            : accuracy // ignore: cast_nullable_to_non_nullable
                  as double?,
        grade: freezed == grade
            ? _value.grade
            : grade // ignore: cast_nullable_to_non_nullable
                  as Grade?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LessonScoreImpl implements _LessonScore {
  const _$LessonScoreImpl({
    required this.cuesAttempted,
    required this.cuesCorrect,
    this.accuracy,
    this.grade,
  });

  factory _$LessonScoreImpl.fromJson(Map<String, dynamic> json) =>
      _$$LessonScoreImplFromJson(json);

  @override
  final int cuesAttempted;
  @override
  final int cuesCorrect;
  @override
  final double? accuracy;
  @override
  final Grade? grade;

  @override
  String toString() {
    return 'LessonScore(cuesAttempted: $cuesAttempted, cuesCorrect: $cuesCorrect, accuracy: $accuracy, grade: $grade)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LessonScoreImpl &&
            (identical(other.cuesAttempted, cuesAttempted) ||
                other.cuesAttempted == cuesAttempted) &&
            (identical(other.cuesCorrect, cuesCorrect) ||
                other.cuesCorrect == cuesCorrect) &&
            (identical(other.accuracy, accuracy) ||
                other.accuracy == accuracy) &&
            (identical(other.grade, grade) || other.grade == grade));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, cuesAttempted, cuesCorrect, accuracy, grade);

  /// Create a copy of LessonScore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LessonScoreImplCopyWith<_$LessonScoreImpl> get copyWith =>
      __$$LessonScoreImplCopyWithImpl<_$LessonScoreImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LessonScoreImplToJson(this);
  }
}

abstract class _LessonScore implements LessonScore {
  const factory _LessonScore({
    required final int cuesAttempted,
    required final int cuesCorrect,
    final double? accuracy,
    final Grade? grade,
  }) = _$LessonScoreImpl;

  factory _LessonScore.fromJson(Map<String, dynamic> json) =
      _$LessonScoreImpl.fromJson;

  @override
  int get cuesAttempted;
  @override
  int get cuesCorrect;
  @override
  double? get accuracy;
  @override
  Grade? get grade;

  /// Create a copy of LessonScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LessonScoreImplCopyWith<_$LessonScoreImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CueOutcome _$CueOutcomeFromJson(Map<String, dynamic> json) {
  return _CueOutcome.fromJson(json);
}

/// @nodoc
mixin _$CueOutcome {
  String get cueId => throw _privateConstructorUsedError;
  int get atMs => throw _privateConstructorUsedError;
  CueType get type => throw _privateConstructorUsedError;
  String get prompt => throw _privateConstructorUsedError;
  bool get attempted => throw _privateConstructorUsedError;
  bool? get correct => throw _privateConstructorUsedError;
  Map<String, dynamic>? get scoreJson => throw _privateConstructorUsedError;
  DateTime? get submittedAt => throw _privateConstructorUsedError;
  String? get explanation => throw _privateConstructorUsedError;
  String? get yourAnswerSummary => throw _privateConstructorUsedError;
  String? get correctAnswerSummary => throw _privateConstructorUsedError;

  /// Serializes this CueOutcome to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CueOutcome
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CueOutcomeCopyWith<CueOutcome> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CueOutcomeCopyWith<$Res> {
  factory $CueOutcomeCopyWith(
    CueOutcome value,
    $Res Function(CueOutcome) then,
  ) = _$CueOutcomeCopyWithImpl<$Res, CueOutcome>;
  @useResult
  $Res call({
    String cueId,
    int atMs,
    CueType type,
    String prompt,
    bool attempted,
    bool? correct,
    Map<String, dynamic>? scoreJson,
    DateTime? submittedAt,
    String? explanation,
    String? yourAnswerSummary,
    String? correctAnswerSummary,
  });
}

/// @nodoc
class _$CueOutcomeCopyWithImpl<$Res, $Val extends CueOutcome>
    implements $CueOutcomeCopyWith<$Res> {
  _$CueOutcomeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CueOutcome
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cueId = null,
    Object? atMs = null,
    Object? type = null,
    Object? prompt = null,
    Object? attempted = null,
    Object? correct = freezed,
    Object? scoreJson = freezed,
    Object? submittedAt = freezed,
    Object? explanation = freezed,
    Object? yourAnswerSummary = freezed,
    Object? correctAnswerSummary = freezed,
  }) {
    return _then(
      _value.copyWith(
            cueId: null == cueId
                ? _value.cueId
                : cueId // ignore: cast_nullable_to_non_nullable
                      as String,
            atMs: null == atMs
                ? _value.atMs
                : atMs // ignore: cast_nullable_to_non_nullable
                      as int,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as CueType,
            prompt: null == prompt
                ? _value.prompt
                : prompt // ignore: cast_nullable_to_non_nullable
                      as String,
            attempted: null == attempted
                ? _value.attempted
                : attempted // ignore: cast_nullable_to_non_nullable
                      as bool,
            correct: freezed == correct
                ? _value.correct
                : correct // ignore: cast_nullable_to_non_nullable
                      as bool?,
            scoreJson: freezed == scoreJson
                ? _value.scoreJson
                : scoreJson // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            submittedAt: freezed == submittedAt
                ? _value.submittedAt
                : submittedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            explanation: freezed == explanation
                ? _value.explanation
                : explanation // ignore: cast_nullable_to_non_nullable
                      as String?,
            yourAnswerSummary: freezed == yourAnswerSummary
                ? _value.yourAnswerSummary
                : yourAnswerSummary // ignore: cast_nullable_to_non_nullable
                      as String?,
            correctAnswerSummary: freezed == correctAnswerSummary
                ? _value.correctAnswerSummary
                : correctAnswerSummary // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CueOutcomeImplCopyWith<$Res>
    implements $CueOutcomeCopyWith<$Res> {
  factory _$$CueOutcomeImplCopyWith(
    _$CueOutcomeImpl value,
    $Res Function(_$CueOutcomeImpl) then,
  ) = __$$CueOutcomeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String cueId,
    int atMs,
    CueType type,
    String prompt,
    bool attempted,
    bool? correct,
    Map<String, dynamic>? scoreJson,
    DateTime? submittedAt,
    String? explanation,
    String? yourAnswerSummary,
    String? correctAnswerSummary,
  });
}

/// @nodoc
class __$$CueOutcomeImplCopyWithImpl<$Res>
    extends _$CueOutcomeCopyWithImpl<$Res, _$CueOutcomeImpl>
    implements _$$CueOutcomeImplCopyWith<$Res> {
  __$$CueOutcomeImplCopyWithImpl(
    _$CueOutcomeImpl _value,
    $Res Function(_$CueOutcomeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CueOutcome
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cueId = null,
    Object? atMs = null,
    Object? type = null,
    Object? prompt = null,
    Object? attempted = null,
    Object? correct = freezed,
    Object? scoreJson = freezed,
    Object? submittedAt = freezed,
    Object? explanation = freezed,
    Object? yourAnswerSummary = freezed,
    Object? correctAnswerSummary = freezed,
  }) {
    return _then(
      _$CueOutcomeImpl(
        cueId: null == cueId
            ? _value.cueId
            : cueId // ignore: cast_nullable_to_non_nullable
                  as String,
        atMs: null == atMs
            ? _value.atMs
            : atMs // ignore: cast_nullable_to_non_nullable
                  as int,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as CueType,
        prompt: null == prompt
            ? _value.prompt
            : prompt // ignore: cast_nullable_to_non_nullable
                  as String,
        attempted: null == attempted
            ? _value.attempted
            : attempted // ignore: cast_nullable_to_non_nullable
                  as bool,
        correct: freezed == correct
            ? _value.correct
            : correct // ignore: cast_nullable_to_non_nullable
                  as bool?,
        scoreJson: freezed == scoreJson
            ? _value._scoreJson
            : scoreJson // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        submittedAt: freezed == submittedAt
            ? _value.submittedAt
            : submittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        explanation: freezed == explanation
            ? _value.explanation
            : explanation // ignore: cast_nullable_to_non_nullable
                  as String?,
        yourAnswerSummary: freezed == yourAnswerSummary
            ? _value.yourAnswerSummary
            : yourAnswerSummary // ignore: cast_nullable_to_non_nullable
                  as String?,
        correctAnswerSummary: freezed == correctAnswerSummary
            ? _value.correctAnswerSummary
            : correctAnswerSummary // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CueOutcomeImpl implements _CueOutcome {
  const _$CueOutcomeImpl({
    required this.cueId,
    required this.atMs,
    required this.type,
    required this.prompt,
    required this.attempted,
    this.correct,
    final Map<String, dynamic>? scoreJson,
    this.submittedAt,
    this.explanation,
    this.yourAnswerSummary,
    this.correctAnswerSummary,
  }) : _scoreJson = scoreJson;

  factory _$CueOutcomeImpl.fromJson(Map<String, dynamic> json) =>
      _$$CueOutcomeImplFromJson(json);

  @override
  final String cueId;
  @override
  final int atMs;
  @override
  final CueType type;
  @override
  final String prompt;
  @override
  final bool attempted;
  @override
  final bool? correct;
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
  final DateTime? submittedAt;
  @override
  final String? explanation;
  @override
  final String? yourAnswerSummary;
  @override
  final String? correctAnswerSummary;

  @override
  String toString() {
    return 'CueOutcome(cueId: $cueId, atMs: $atMs, type: $type, prompt: $prompt, attempted: $attempted, correct: $correct, scoreJson: $scoreJson, submittedAt: $submittedAt, explanation: $explanation, yourAnswerSummary: $yourAnswerSummary, correctAnswerSummary: $correctAnswerSummary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CueOutcomeImpl &&
            (identical(other.cueId, cueId) || other.cueId == cueId) &&
            (identical(other.atMs, atMs) || other.atMs == atMs) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.prompt, prompt) || other.prompt == prompt) &&
            (identical(other.attempted, attempted) ||
                other.attempted == attempted) &&
            (identical(other.correct, correct) || other.correct == correct) &&
            const DeepCollectionEquality().equals(
              other._scoreJson,
              _scoreJson,
            ) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.explanation, explanation) ||
                other.explanation == explanation) &&
            (identical(other.yourAnswerSummary, yourAnswerSummary) ||
                other.yourAnswerSummary == yourAnswerSummary) &&
            (identical(other.correctAnswerSummary, correctAnswerSummary) ||
                other.correctAnswerSummary == correctAnswerSummary));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    cueId,
    atMs,
    type,
    prompt,
    attempted,
    correct,
    const DeepCollectionEquality().hash(_scoreJson),
    submittedAt,
    explanation,
    yourAnswerSummary,
    correctAnswerSummary,
  );

  /// Create a copy of CueOutcome
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CueOutcomeImplCopyWith<_$CueOutcomeImpl> get copyWith =>
      __$$CueOutcomeImplCopyWithImpl<_$CueOutcomeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CueOutcomeImplToJson(this);
  }
}

abstract class _CueOutcome implements CueOutcome {
  const factory _CueOutcome({
    required final String cueId,
    required final int atMs,
    required final CueType type,
    required final String prompt,
    required final bool attempted,
    final bool? correct,
    final Map<String, dynamic>? scoreJson,
    final DateTime? submittedAt,
    final String? explanation,
    final String? yourAnswerSummary,
    final String? correctAnswerSummary,
  }) = _$CueOutcomeImpl;

  factory _CueOutcome.fromJson(Map<String, dynamic> json) =
      _$CueOutcomeImpl.fromJson;

  @override
  String get cueId;
  @override
  int get atMs;
  @override
  CueType get type;
  @override
  String get prompt;
  @override
  bool get attempted;
  @override
  bool? get correct;
  @override
  Map<String, dynamic>? get scoreJson;
  @override
  DateTime? get submittedAt;
  @override
  String? get explanation;
  @override
  String? get yourAnswerSummary;
  @override
  String? get correctAnswerSummary;

  /// Create a copy of CueOutcome
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CueOutcomeImplCopyWith<_$CueOutcomeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LessonReview _$LessonReviewFromJson(Map<String, dynamic> json) {
  return _LessonReview.fromJson(json);
}

/// @nodoc
mixin _$LessonReview {
  LessonVideoRef get video => throw _privateConstructorUsedError;
  CourseTile get course => throw _privateConstructorUsedError;
  LessonScore get score => throw _privateConstructorUsedError;
  List<CueOutcome> get cues => throw _privateConstructorUsedError;

  /// Serializes this LessonReview to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LessonReview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LessonReviewCopyWith<LessonReview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LessonReviewCopyWith<$Res> {
  factory $LessonReviewCopyWith(
    LessonReview value,
    $Res Function(LessonReview) then,
  ) = _$LessonReviewCopyWithImpl<$Res, LessonReview>;
  @useResult
  $Res call({
    LessonVideoRef video,
    CourseTile course,
    LessonScore score,
    List<CueOutcome> cues,
  });

  $LessonVideoRefCopyWith<$Res> get video;
  $CourseTileCopyWith<$Res> get course;
  $LessonScoreCopyWith<$Res> get score;
}

/// @nodoc
class _$LessonReviewCopyWithImpl<$Res, $Val extends LessonReview>
    implements $LessonReviewCopyWith<$Res> {
  _$LessonReviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LessonReview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? video = null,
    Object? course = null,
    Object? score = null,
    Object? cues = null,
  }) {
    return _then(
      _value.copyWith(
            video: null == video
                ? _value.video
                : video // ignore: cast_nullable_to_non_nullable
                      as LessonVideoRef,
            course: null == course
                ? _value.course
                : course // ignore: cast_nullable_to_non_nullable
                      as CourseTile,
            score: null == score
                ? _value.score
                : score // ignore: cast_nullable_to_non_nullable
                      as LessonScore,
            cues: null == cues
                ? _value.cues
                : cues // ignore: cast_nullable_to_non_nullable
                      as List<CueOutcome>,
          )
          as $Val,
    );
  }

  /// Create a copy of LessonReview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LessonVideoRefCopyWith<$Res> get video {
    return $LessonVideoRefCopyWith<$Res>(_value.video, (value) {
      return _then(_value.copyWith(video: value) as $Val);
    });
  }

  /// Create a copy of LessonReview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CourseTileCopyWith<$Res> get course {
    return $CourseTileCopyWith<$Res>(_value.course, (value) {
      return _then(_value.copyWith(course: value) as $Val);
    });
  }

  /// Create a copy of LessonReview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LessonScoreCopyWith<$Res> get score {
    return $LessonScoreCopyWith<$Res>(_value.score, (value) {
      return _then(_value.copyWith(score: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$LessonReviewImplCopyWith<$Res>
    implements $LessonReviewCopyWith<$Res> {
  factory _$$LessonReviewImplCopyWith(
    _$LessonReviewImpl value,
    $Res Function(_$LessonReviewImpl) then,
  ) = __$$LessonReviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    LessonVideoRef video,
    CourseTile course,
    LessonScore score,
    List<CueOutcome> cues,
  });

  @override
  $LessonVideoRefCopyWith<$Res> get video;
  @override
  $CourseTileCopyWith<$Res> get course;
  @override
  $LessonScoreCopyWith<$Res> get score;
}

/// @nodoc
class __$$LessonReviewImplCopyWithImpl<$Res>
    extends _$LessonReviewCopyWithImpl<$Res, _$LessonReviewImpl>
    implements _$$LessonReviewImplCopyWith<$Res> {
  __$$LessonReviewImplCopyWithImpl(
    _$LessonReviewImpl _value,
    $Res Function(_$LessonReviewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LessonReview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? video = null,
    Object? course = null,
    Object? score = null,
    Object? cues = null,
  }) {
    return _then(
      _$LessonReviewImpl(
        video: null == video
            ? _value.video
            : video // ignore: cast_nullable_to_non_nullable
                  as LessonVideoRef,
        course: null == course
            ? _value.course
            : course // ignore: cast_nullable_to_non_nullable
                  as CourseTile,
        score: null == score
            ? _value.score
            : score // ignore: cast_nullable_to_non_nullable
                  as LessonScore,
        cues: null == cues
            ? _value._cues
            : cues // ignore: cast_nullable_to_non_nullable
                  as List<CueOutcome>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LessonReviewImpl implements _LessonReview {
  const _$LessonReviewImpl({
    required this.video,
    required this.course,
    required this.score,
    required final List<CueOutcome> cues,
  }) : _cues = cues;

  factory _$LessonReviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$LessonReviewImplFromJson(json);

  @override
  final LessonVideoRef video;
  @override
  final CourseTile course;
  @override
  final LessonScore score;
  final List<CueOutcome> _cues;
  @override
  List<CueOutcome> get cues {
    if (_cues is EqualUnmodifiableListView) return _cues;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_cues);
  }

  @override
  String toString() {
    return 'LessonReview(video: $video, course: $course, score: $score, cues: $cues)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LessonReviewImpl &&
            (identical(other.video, video) || other.video == video) &&
            (identical(other.course, course) || other.course == course) &&
            (identical(other.score, score) || other.score == score) &&
            const DeepCollectionEquality().equals(other._cues, _cues));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    video,
    course,
    score,
    const DeepCollectionEquality().hash(_cues),
  );

  /// Create a copy of LessonReview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LessonReviewImplCopyWith<_$LessonReviewImpl> get copyWith =>
      __$$LessonReviewImplCopyWithImpl<_$LessonReviewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LessonReviewImplToJson(this);
  }
}

abstract class _LessonReview implements LessonReview {
  const factory _LessonReview({
    required final LessonVideoRef video,
    required final CourseTile course,
    required final LessonScore score,
    required final List<CueOutcome> cues,
  }) = _$LessonReviewImpl;

  factory _LessonReview.fromJson(Map<String, dynamic> json) =
      _$LessonReviewImpl.fromJson;

  @override
  LessonVideoRef get video;
  @override
  CourseTile get course;
  @override
  LessonScore get score;
  @override
  List<CueOutcome> get cues;

  /// Create a copy of LessonReview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LessonReviewImplCopyWith<_$LessonReviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
