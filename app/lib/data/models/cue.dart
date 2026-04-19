import 'package:freezed_annotation/freezed_annotation.dart';

part 'cue.freezed.dart';
part 'cue.g.dart';

/// Cue type enum — mirrors the backend's `CueType` Prisma enum.
///
/// `VOICE` is reserved in the enum so we can decode a VOICE cue if one
/// ever lands in the DB, but the UI must never expose VOICE in a picker:
/// the backend rejects VOICE writes with 501 (ADR 0004) and VOICE attempts
/// with 501 as well. See Slice E spec + CLAUDE.md.
enum CueType {
  @JsonValue('MCQ')
  mcq,
  @JsonValue('BLANKS')
  blanks,
  @JsonValue('MATCHING')
  matching,
  @JsonValue('VOICE')
  voice,
}

/// A single cue row as returned by `GET /api/videos/:id/cues` and
/// `POST /api/videos/:id/cues`. The backend keyed fields:
/// - `atMs`: where on the video timeline the cue fires.
/// - `pause`: if true, the player should pause when the cue is shown.
/// - `type`: discriminator for the `payload` shape.
/// - `payload`: Json — per-type fields; we keep it as `Map<String, dynamic>`
///   on the client because the three shapes each have their own form UI
///   and validator. Higher-level code destructures based on [type].
@freezed
class Cue with _$Cue {
  const factory Cue({
    required String id,
    required String videoId,
    required int atMs,
    required bool pause,
    required CueType type,
    required Map<String, dynamic> payload,
    required int orderIndex,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Cue;

  factory Cue.fromJson(Map<String, dynamic> json) => _$CueFromJson(json);
}

/// An attempt row persisted server-side. Grading is authoritative on the
/// server; `correct` is populated there.
@freezed
class Attempt with _$Attempt {
  const factory Attempt({
    required String id,
    required String userId,
    required String videoId,
    required String cueId,
    required bool correct,
    Map<String, dynamic>? scoreJson,
    required DateTime submittedAt,
  }) = _Attempt;

  factory Attempt.fromJson(Map<String, dynamic> json) =>
      _$AttemptFromJson(json);
}

/// The response to `POST /api/attempts`.
///
/// - [correct] — whether the learner got it right.
/// - [scoreJson] — per-type structured detail (e.g. `{perBlank: [true, false]}`
///   for BLANKS, `{selected: 2}` for MCQ, `{correctPairs: 3, totalPairs: 4}`
///   for MATCHING). Never contains the correct answer.
/// - [explanation] — optional designer-authored narrative surfaced after
///   grading. For MCQ the grader passes through `payload.explanation` so
///   the learner gets the "teaching moment" even on a wrong answer.
@freezed
class AttemptResult with _$AttemptResult {
  const factory AttemptResult({
    required Attempt attempt,
    required bool correct,
    Map<String, dynamic>? scoreJson,
    String? explanation,
  }) = _AttemptResult;

  factory AttemptResult.fromJson(Map<String, dynamic> json) =>
      _$AttemptResultFromJson(json);
}
