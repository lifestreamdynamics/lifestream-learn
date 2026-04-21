import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/http/error_envelope.dart';
import '../../data/models/progress.dart';
import '../../data/repositories/progress_repository.dart';

/// Slice P2 — BLoC backing the profile-screen progress sections.
/// Loads `GET /api/me/progress` on open; pull-to-refresh is supported
/// without flashing the spinner (FeedBloc pattern). A failed load
/// surfaces an ApiException the UI can render alongside a retry.

@immutable
abstract class ProfileEvent {
  const ProfileEvent();
}

class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

class ProfileRefreshRequested extends ProfileEvent {
  const ProfileRefreshRequested();
}

@immutable
abstract class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded({required this.overall});
  final OverallProgress overall;
}

class ProfileError extends ProfileState {
  const ProfileError(this.error);
  final ApiException error;
}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required this.progressRepo}) : super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onLoad);
    on<ProfileRefreshRequested>(_onRefresh);
  }

  final ProgressRepository progressRepo;

  Future<void> _onLoad(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final overall = await progressRepo.fetchOverall();
      emit(ProfileLoaded(overall: overall));
    } on ApiException catch (e) {
      emit(ProfileError(e));
    }
  }

  Future<void> _onRefresh(
    ProfileRefreshRequested event,
    Emitter<ProfileState> emit,
  ) async {
    // Keep current data on screen while refetching, so a pull-to-refresh
    // doesn't flash an empty skeleton.
    if (state is! ProfileLoaded) {
      emit(const ProfileLoading());
    }
    try {
      final overall = await progressRepo.fetchOverall();
      emit(ProfileLoaded(overall: overall));
    } on ApiException catch (e) {
      if (state is! ProfileLoaded) emit(ProfileError(e));
    }
  }
}
