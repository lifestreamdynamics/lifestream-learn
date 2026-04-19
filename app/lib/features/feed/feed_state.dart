import 'package:flutter/foundation.dart';

import '../../core/http/error_envelope.dart';
import '../../data/models/feed_entry.dart';

/// Feed state machine. The "loaded-with-error" variant (a loaded list AND
/// an error side-band) is important: a transient pagination failure must
/// NOT blow the list away — the user is mid-watch on page N and reporting
/// "you have no videos" because the `loadMore` request 500'd would be a
/// terrible UX.
@immutable
abstract class FeedState {
  const FeedState();
}

class FeedInitial extends FeedState {
  const FeedInitial();

  @override
  bool operator ==(Object other) => other is FeedInitial;

  @override
  int get hashCode => 0;
}

class FeedLoading extends FeedState {
  const FeedLoading();

  @override
  bool operator ==(Object other) => other is FeedLoading;

  @override
  int get hashCode => 1;
}

class FeedLoaded extends FeedState {
  const FeedLoaded({
    required this.items,
    this.nextCursor,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<FeedEntry> items;
  final String? nextCursor;
  final bool hasMore;

  /// True while a load-more request is in flight. Lets the feed view
  /// render a tiny spinner at the bottom without tearing down the list.
  final bool isLoadingMore;

  /// Non-null when the most recent load-more failed. The UI should render
  /// an inline banner with a "retry" affordance; dismissing emits
  /// `FeedErrorClearRequested`.
  final ApiException? loadMoreError;

  FeedLoaded copyWith({
    List<FeedEntry>? items,
    String? nextCursor,
    bool setNextCursorNull = false,
    bool? hasMore,
    bool? isLoadingMore,
    ApiException? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return FeedLoaded(
      items: items ?? this.items,
      nextCursor:
          setNextCursorNull ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! FeedLoaded) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return other.nextCursor == nextCursor &&
        other.hasMore == hasMore &&
        other.isLoadingMore == isLoadingMore &&
        other.loadMoreError == loadMoreError;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(items),
        nextCursor,
        hasMore,
        isLoadingMore,
        loadMoreError,
      );
}

/// Full-screen error — only emitted when we have no items to fall back to
/// (initial load failed or a refresh emptied the list and then failed).
class FeedError extends FeedState {
  const FeedError(this.error);
  final ApiException error;

  @override
  bool operator ==(Object other) => other is FeedError && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
