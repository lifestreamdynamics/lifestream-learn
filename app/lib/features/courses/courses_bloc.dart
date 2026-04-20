import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/app_constants.dart';
import '../../core/http/error_envelope.dart';
import '../../data/models/course.dart';
import '../../data/repositories/course_repository.dart';

@immutable
abstract class CoursesEvent {
  const CoursesEvent();
}

class CoursesLoadRequested extends CoursesEvent {
  const CoursesLoadRequested();
}

class CoursesRefreshRequested extends CoursesEvent {
  const CoursesRefreshRequested();
}

class CoursesLoadMoreRequested extends CoursesEvent {
  const CoursesLoadMoreRequested();
}

@immutable
abstract class CoursesState {
  const CoursesState();
}

class CoursesInitial extends CoursesState {
  const CoursesInitial();
}

class CoursesLoading extends CoursesState {
  const CoursesLoading();
}

class CoursesLoaded extends CoursesState {
  const CoursesLoaded({
    required this.items,
    this.nextCursor,
    required this.hasMore,
    this.isLoadingMore = false,
  });
  final List<Course> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  CoursesLoaded copyWith({
    List<Course>? items,
    String? nextCursor,
    bool setCursorNull = false,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CoursesLoaded(
      items: items ?? this.items,
      nextCursor: setCursorNull ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class CoursesError extends CoursesState {
  const CoursesError(this.error);
  final ApiException error;
}

/// Paginated browse-courses BLoC. Mirrors `FeedBloc` but for published
/// courses (the browse-anyone-can-see view).
class CoursesBloc extends Bloc<CoursesEvent, CoursesState> {
  CoursesBloc({required this.repo, this.pageSize = AppConstants.feedPageSize})
      : super(const CoursesInitial()) {
    on<CoursesLoadRequested>(_onLoad);
    on<CoursesRefreshRequested>(_onRefresh);
    on<CoursesLoadMoreRequested>(_onLoadMore);
  }

  final CourseRepository repo;
  final int pageSize;

  Future<void> _onLoad(
      CoursesLoadRequested event, Emitter<CoursesState> emit) async {
    emit(const CoursesLoading());
    try {
      final page = await repo.published(limit: pageSize);
      emit(CoursesLoaded(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ));
    } on ApiException catch (e) {
      emit(CoursesError(e));
    }
  }

  Future<void> _onRefresh(
      CoursesRefreshRequested event, Emitter<CoursesState> emit) async {
    if (state is! CoursesLoaded) emit(const CoursesLoading());
    try {
      final page = await repo.published(limit: pageSize);
      emit(CoursesLoaded(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ));
    } on ApiException catch (e) {
      if (state is! CoursesLoaded) emit(CoursesError(e));
    }
  }

  Future<void> _onLoadMore(
      CoursesLoadMoreRequested event, Emitter<CoursesState> emit) async {
    final current = state;
    if (current is! CoursesLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;
    emit(current.copyWith(isLoadingMore: true));
    try {
      final page =
          await repo.published(cursor: current.nextCursor, limit: pageSize);
      emit(CoursesLoaded(
        items: [...current.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ));
    } on ApiException catch (_) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }
}
