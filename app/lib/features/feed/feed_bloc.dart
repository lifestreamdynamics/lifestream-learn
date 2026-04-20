import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/app_constants.dart';
import '../../core/http/error_envelope.dart';
import '../../data/repositories/feed_repository.dart';
import 'feed_event.dart';
import 'feed_state.dart';

/// BLoC for the feed screen. Owns pagination cursor + a tri-state model:
/// `FeedInitial | FeedLoading | FeedLoaded | FeedError`.
///
/// Transitions:
/// - `FeedLoadRequested`  → `FeedLoading` → `FeedLoaded | FeedError`
///   (replaces items).
/// - `FeedRefreshRequested` → re-fetch page(null) → replaces items. Does
///   NOT emit `FeedLoading` if we already have a `FeedLoaded` state, so
///   the pull-to-refresh doesn't flash-empty the screen.
/// - `FeedLoadMoreRequested` → no-op if `!hasMore`; otherwise flags
///   `isLoadingMore`, fetches next page, appends. On error we KEEP the
///   existing items and attach `loadMoreError` so the UI can render an
///   inline banner.
/// - `FeedErrorClearRequested` → clears `loadMoreError`.
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({required this.feedRepo, this.pageSize = AppConstants.feedPageSize})
      : super(const FeedInitial()) {
    on<FeedLoadRequested>(_onLoad);
    on<FeedRefreshRequested>(_onRefresh);
    on<FeedLoadMoreRequested>(_onLoadMore);
    on<FeedErrorClearRequested>(_onClearError);
  }

  final FeedRepository feedRepo;
  final int pageSize;

  Future<void> _onLoad(
    FeedLoadRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(const FeedLoading());
    try {
      final page = await feedRepo.page(limit: pageSize);
      emit(FeedLoaded(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ));
    } on ApiException catch (e) {
      emit(FeedError(e));
    }
  }

  Future<void> _onRefresh(
    FeedRefreshRequested event,
    Emitter<FeedState> emit,
  ) async {
    // Keep existing items visible during a pull-to-refresh; only flash the
    // loading spinner if we have nothing to show.
    if (state is! FeedLoaded) {
      emit(const FeedLoading());
    }
    try {
      final page = await feedRepo.page(limit: pageSize);
      emit(FeedLoaded(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ));
    } on ApiException catch (e) {
      final current = state;
      if (current is FeedLoaded) {
        // Preserve what we had; surface the error on the banner.
        emit(current.copyWith(loadMoreError: e));
      } else {
        emit(FeedError(e));
      }
    }
  }

  Future<void> _onLoadMore(
    FeedLoadMoreRequested event,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    if (current is! FeedLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true, clearLoadMoreError: true));
    try {
      final page = await feedRepo.page(
        cursor: current.nextCursor,
        limit: pageSize,
      );
      emit(FeedLoaded(
        items: [...current.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ));
    } on ApiException catch (e) {
      // Keep what we had; surface the error for inline retry.
      emit(current.copyWith(isLoadingMore: false, loadMoreError: e));
    }
  }

  void _onClearError(
    FeedErrorClearRequested event,
    Emitter<FeedState> emit,
  ) {
    final current = state;
    if (current is FeedLoaded && current.loadMoreError != null) {
      emit(current.copyWith(clearLoadMoreError: true));
    }
  }
}
