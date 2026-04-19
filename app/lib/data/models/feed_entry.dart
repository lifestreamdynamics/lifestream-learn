import 'package:freezed_annotation/freezed_annotation.dart';

import 'course.dart';
import 'video.dart';

part 'feed_entry.freezed.dart';
part 'feed_entry.g.dart';

/// One item in the personalised feed. Composed of a `VideoSummary`, the
/// parent `CourseSummary`, a cue count (so the UI can preview "12 cues")
/// and a flag for whether the learner has already attempted any cue on
/// this video.
@freezed
class FeedEntry with _$FeedEntry {
  const factory FeedEntry({
    required VideoSummary video,
    required CourseSummary course,
    required int cueCount,
    required bool hasAttempted,
  }) = _FeedEntry;

  factory FeedEntry.fromJson(Map<String, dynamic> json) =>
      _$FeedEntryFromJson(json);
}

/// Paginated feed result from `GET /api/feed`.
@freezed
class FeedPage with _$FeedPage {
  const factory FeedPage({
    required List<FeedEntry> items,
    String? nextCursor,
    required bool hasMore,
  }) = _FeedPage;

  factory FeedPage.fromJson(Map<String, dynamic> json) =>
      _$FeedPageFromJson(json);
}
