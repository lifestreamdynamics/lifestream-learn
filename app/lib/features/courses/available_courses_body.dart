import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../data/repositories/course_repository.dart';
import 'courses_bloc.dart';

/// Body of the "Available" tab inside `CoursesScreen`. Renders the
/// published-course catalog as a grid of cards; tapping a tile pushes
/// `/courses/:id` → `CourseDetailScreen`.
///
/// Owns its own `CoursesBloc` — the bloc manages cursor-paginated fetch
/// state, so scoping it to this widget keeps pagination state local to
/// the Available tab across tab switches inside the shell branch.
class AvailableCoursesBody extends StatelessWidget {
  const AvailableCoursesBody({required this.courseRepo, super.key});

  final CourseRepository courseRepo;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CoursesBloc>(
      create: (_) =>
          CoursesBloc(repo: courseRepo)..add(const CoursesLoadRequested()),
      child: const _AvailableGrid(),
    );
  }
}

class _AvailableGrid extends StatelessWidget {
  const _AvailableGrid();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoursesBloc, CoursesState>(
      builder: (context, state) {
        if (state is CoursesInitial || state is CoursesLoading) {
          return const _AvailableCoursesLoadingPlaceholder();
        }
        if (state is CoursesError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error.message),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context
                      .read<CoursesBloc>()
                      .add(const CoursesLoadRequested()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is CoursesLoaded) {
          if (state.items.isEmpty) {
            return const Center(
              child: Text(
                'No published courses yet.',
                key: Key('courses.empty'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<CoursesBloc>();
              bloc.add(const CoursesRefreshRequested());
              await bloc.stream.firstWhere(
                (s) =>
                    s is CoursesLoaded && !s.isLoadingMore ||
                    s is CoursesError,
              );
            },
            child: GridView.builder(
              key: const Key('courses.grid'),
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: state.items.length,
              itemBuilder: (context, i) {
                final course = state.items[i];
                return Semantics(
                  button: true,
                  label: 'Course: ${course.title}. Tap to view.',
                  child: InkWell(
                    key: Key('courses.tile.${course.id}'),
                    onTap: () =>
                        GoRouter.of(context).go('/courses/${course.id}'),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: course.coverImageUrl != null
                                ? Image.network(
                                    course.coverImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: const Icon(Icons.image_rounded),
                                    ),
                                  )
                                : Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: const Icon(
                                      Icons.school_rounded,
                                      size: 36,
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              course.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Skeleton placeholder for the available-courses grid while the first fetch
/// is in progress. Renders six ghost cards shimmed by Skeletonizer
/// (configured theme-wide in AppTheme).
class _AvailableCoursesLoadingPlaceholder extends StatelessWidget {
  const _AvailableCoursesLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(color: Colors.white),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Course title placeholder'),
                    SizedBox(height: 4),
                    Text('subtitle'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
