// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProgressSummaryImpl _$$ProgressSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$ProgressSummaryImpl(
  coursesEnrolled: (json['coursesEnrolled'] as num).toInt(),
  lessonsCompleted: (json['lessonsCompleted'] as num).toInt(),
  totalCuesAttempted: (json['totalCuesAttempted'] as num).toInt(),
  totalCuesCorrect: (json['totalCuesCorrect'] as num).toInt(),
  overallAccuracy: (json['overallAccuracy'] as num?)?.toDouble(),
  overallGrade: $enumDecodeNullable(_$GradeEnumMap, json['overallGrade']),
  totalWatchTimeMs: (json['totalWatchTimeMs'] as num).toInt(),
  currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
  longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$ProgressSummaryImplToJson(
  _$ProgressSummaryImpl instance,
) => <String, dynamic>{
  'coursesEnrolled': instance.coursesEnrolled,
  'lessonsCompleted': instance.lessonsCompleted,
  'totalCuesAttempted': instance.totalCuesAttempted,
  'totalCuesCorrect': instance.totalCuesCorrect,
  'overallAccuracy': instance.overallAccuracy,
  'overallGrade': _$GradeEnumMap[instance.overallGrade],
  'totalWatchTimeMs': instance.totalWatchTimeMs,
  'currentStreak': instance.currentStreak,
  'longestStreak': instance.longestStreak,
};

const _$GradeEnumMap = {
  Grade.a: 'A',
  Grade.b: 'B',
  Grade.c: 'C',
  Grade.d: 'D',
  Grade.f: 'F',
};

_$CourseProgressSummaryImpl _$$CourseProgressSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$CourseProgressSummaryImpl(
  course: CourseTile.fromJson(json['course'] as Map<String, dynamic>),
  videosTotal: (json['videosTotal'] as num).toInt(),
  videosCompleted: (json['videosCompleted'] as num).toInt(),
  completionPct: (json['completionPct'] as num).toDouble(),
  cuesAttempted: (json['cuesAttempted'] as num).toInt(),
  cuesCorrect: (json['cuesCorrect'] as num).toInt(),
  accuracy: (json['accuracy'] as num?)?.toDouble(),
  grade: $enumDecodeNullable(_$GradeEnumMap, json['grade']),
  lastVideoId: json['lastVideoId'] as String?,
  lastPosMs: (json['lastPosMs'] as num?)?.toInt(),
);

Map<String, dynamic> _$$CourseProgressSummaryImplToJson(
  _$CourseProgressSummaryImpl instance,
) => <String, dynamic>{
  'course': instance.course,
  'videosTotal': instance.videosTotal,
  'videosCompleted': instance.videosCompleted,
  'completionPct': instance.completionPct,
  'cuesAttempted': instance.cuesAttempted,
  'cuesCorrect': instance.cuesCorrect,
  'accuracy': instance.accuracy,
  'grade': _$GradeEnumMap[instance.grade],
  'lastVideoId': instance.lastVideoId,
  'lastPosMs': instance.lastPosMs,
};

_$CourseTileImpl _$$CourseTileImplFromJson(Map<String, dynamic> json) =>
    _$CourseTileImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      coverImageUrl: json['coverImageUrl'] as String?,
    );

Map<String, dynamic> _$$CourseTileImplToJson(_$CourseTileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'slug': instance.slug,
      'coverImageUrl': instance.coverImageUrl,
    };

_$LessonProgressSummaryImpl _$$LessonProgressSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$LessonProgressSummaryImpl(
  videoId: json['videoId'] as String,
  title: json['title'] as String,
  orderIndex: (json['orderIndex'] as num).toInt(),
  durationMs: (json['durationMs'] as num?)?.toInt(),
  cueCount: (json['cueCount'] as num).toInt(),
  cuesAttempted: (json['cuesAttempted'] as num).toInt(),
  cuesCorrect: (json['cuesCorrect'] as num).toInt(),
  accuracy: (json['accuracy'] as num?)?.toDouble(),
  grade: $enumDecodeNullable(_$GradeEnumMap, json['grade']),
  completed: json['completed'] as bool,
);

Map<String, dynamic> _$$LessonProgressSummaryImplToJson(
  _$LessonProgressSummaryImpl instance,
) => <String, dynamic>{
  'videoId': instance.videoId,
  'title': instance.title,
  'orderIndex': instance.orderIndex,
  'durationMs': instance.durationMs,
  'cueCount': instance.cueCount,
  'cuesAttempted': instance.cuesAttempted,
  'cuesCorrect': instance.cuesCorrect,
  'accuracy': instance.accuracy,
  'grade': _$GradeEnumMap[instance.grade],
  'completed': instance.completed,
};

_$CourseProgressDetailImpl _$$CourseProgressDetailImplFromJson(
  Map<String, dynamic> json,
) => _$CourseProgressDetailImpl(
  course: CourseTile.fromJson(json['course'] as Map<String, dynamic>),
  videosTotal: (json['videosTotal'] as num).toInt(),
  videosCompleted: (json['videosCompleted'] as num).toInt(),
  completionPct: (json['completionPct'] as num).toDouble(),
  cuesAttempted: (json['cuesAttempted'] as num).toInt(),
  cuesCorrect: (json['cuesCorrect'] as num).toInt(),
  accuracy: (json['accuracy'] as num?)?.toDouble(),
  grade: $enumDecodeNullable(_$GradeEnumMap, json['grade']),
  lastVideoId: json['lastVideoId'] as String?,
  lastPosMs: (json['lastPosMs'] as num?)?.toInt(),
  lessons: (json['lessons'] as List<dynamic>)
      .map((e) => LessonProgressSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$$CourseProgressDetailImplToJson(
  _$CourseProgressDetailImpl instance,
) => <String, dynamic>{
  'course': instance.course,
  'videosTotal': instance.videosTotal,
  'videosCompleted': instance.videosCompleted,
  'completionPct': instance.completionPct,
  'cuesAttempted': instance.cuesAttempted,
  'cuesCorrect': instance.cuesCorrect,
  'accuracy': instance.accuracy,
  'grade': _$GradeEnumMap[instance.grade],
  'lastVideoId': instance.lastVideoId,
  'lastPosMs': instance.lastPosMs,
  'lessons': instance.lessons,
};

_$OverallProgressImpl _$$OverallProgressImplFromJson(
  Map<String, dynamic> json,
) => _$OverallProgressImpl(
  summary: ProgressSummary.fromJson(json['summary'] as Map<String, dynamic>),
  perCourse: (json['perCourse'] as List<dynamic>)
      .map((e) => CourseProgressSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
  recentlyUnlocked:
      (json['recentlyUnlocked'] as List<dynamic>?)
          ?.map((e) => AchievementSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AchievementSummary>[],
);

Map<String, dynamic> _$$OverallProgressImplToJson(
  _$OverallProgressImpl instance,
) => <String, dynamic>{
  'summary': instance.summary,
  'perCourse': instance.perCourse,
  'recentlyUnlocked': instance.recentlyUnlocked,
};

_$LessonVideoRefImpl _$$LessonVideoRefImplFromJson(Map<String, dynamic> json) =>
    _$LessonVideoRefImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      orderIndex: (json['orderIndex'] as num).toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      courseId: json['courseId'] as String,
    );

Map<String, dynamic> _$$LessonVideoRefImplToJson(
  _$LessonVideoRefImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'orderIndex': instance.orderIndex,
  'durationMs': instance.durationMs,
  'courseId': instance.courseId,
};

_$LessonScoreImpl _$$LessonScoreImplFromJson(Map<String, dynamic> json) =>
    _$LessonScoreImpl(
      cuesAttempted: (json['cuesAttempted'] as num).toInt(),
      cuesCorrect: (json['cuesCorrect'] as num).toInt(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      grade: $enumDecodeNullable(_$GradeEnumMap, json['grade']),
    );

Map<String, dynamic> _$$LessonScoreImplToJson(_$LessonScoreImpl instance) =>
    <String, dynamic>{
      'cuesAttempted': instance.cuesAttempted,
      'cuesCorrect': instance.cuesCorrect,
      'accuracy': instance.accuracy,
      'grade': _$GradeEnumMap[instance.grade],
    };

_$CueOutcomeImpl _$$CueOutcomeImplFromJson(Map<String, dynamic> json) =>
    _$CueOutcomeImpl(
      cueId: json['cueId'] as String,
      atMs: (json['atMs'] as num).toInt(),
      type: $enumDecode(_$CueTypeEnumMap, json['type']),
      prompt: json['prompt'] as String,
      attempted: json['attempted'] as bool,
      correct: json['correct'] as bool?,
      scoreJson: json['scoreJson'] as Map<String, dynamic>?,
      submittedAt: json['submittedAt'] == null
          ? null
          : DateTime.parse(json['submittedAt'] as String),
      explanation: json['explanation'] as String?,
      yourAnswerSummary: json['yourAnswerSummary'] as String?,
      correctAnswerSummary: json['correctAnswerSummary'] as String?,
    );

Map<String, dynamic> _$$CueOutcomeImplToJson(_$CueOutcomeImpl instance) =>
    <String, dynamic>{
      'cueId': instance.cueId,
      'atMs': instance.atMs,
      'type': _$CueTypeEnumMap[instance.type]!,
      'prompt': instance.prompt,
      'attempted': instance.attempted,
      'correct': instance.correct,
      'scoreJson': instance.scoreJson,
      'submittedAt': instance.submittedAt?.toIso8601String(),
      'explanation': instance.explanation,
      'yourAnswerSummary': instance.yourAnswerSummary,
      'correctAnswerSummary': instance.correctAnswerSummary,
    };

const _$CueTypeEnumMap = {
  CueType.mcq: 'MCQ',
  CueType.blanks: 'BLANKS',
  CueType.matching: 'MATCHING',
  CueType.voice: 'VOICE',
};

_$LessonReviewImpl _$$LessonReviewImplFromJson(Map<String, dynamic> json) =>
    _$LessonReviewImpl(
      video: LessonVideoRef.fromJson(json['video'] as Map<String, dynamic>),
      course: CourseTile.fromJson(json['course'] as Map<String, dynamic>),
      score: LessonScore.fromJson(json['score'] as Map<String, dynamic>),
      cues: (json['cues'] as List<dynamic>)
          .map((e) => CueOutcome.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$LessonReviewImplToJson(_$LessonReviewImpl instance) =>
    <String, dynamic>{
      'video': instance.video,
      'course': instance.course,
      'score': instance.score,
      'cues': instance.cues,
    };
