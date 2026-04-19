import 'package:flutter/foundation.dart';

@immutable
abstract class FeedEvent {
  const FeedEvent();
}

/// Initial load. Replaces any existing items.
class FeedLoadRequested extends FeedEvent {
  const FeedLoadRequested();

  @override
  bool operator ==(Object other) => other is FeedLoadRequested;

  @override
  int get hashCode => 0;
}

/// Pull-to-refresh. Replaces items (does not append).
class FeedRefreshRequested extends FeedEvent {
  const FeedRefreshRequested();

  @override
  bool operator ==(Object other) => other is FeedRefreshRequested;

  @override
  int get hashCode => 1;
}

/// Next page. No-op if `hasMore` is false or if already loading-more.
class FeedLoadMoreRequested extends FeedEvent {
  const FeedLoadMoreRequested();

  @override
  bool operator ==(Object other) => other is FeedLoadMoreRequested;

  @override
  int get hashCode => 2;
}

/// Dismiss a transient load-more error while keeping the existing items.
class FeedErrorClearRequested extends FeedEvent {
  const FeedErrorClearRequested();

  @override
  bool operator ==(Object other) => other is FeedErrorClearRequested;

  @override
  int get hashCode => 3;
}
