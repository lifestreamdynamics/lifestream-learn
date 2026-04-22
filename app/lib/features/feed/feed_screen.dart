import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_sinks.dart';
import '../../core/art/brand_empty_state.dart';
import '../../data/models/feed_entry.dart';
import '../../data/repositories/enrollment_repository.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../player/learn_video_player.dart';
import 'feed_bloc.dart';
import 'feed_event.dart';
import 'feed_state.dart';
import 'video_controller_cache.dart';

/// Signature for the factory that renders one feed page. The FeedScreen
/// delegates to this so widget tests can substitute a stub that doesn't
/// need the platform video plugin.
typedef FeedItemBuilder =
    Widget Function(BuildContext context, FeedEntry entry);

/// Top-level feed screen. Expects a `FeedBloc` to be provided upstream
/// (from `HomeShell`); constructs its own `PageController` +
/// `VideoControllerCache` that live for the lifetime of the screen.
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    required this.videoRepo,
    required this.enrollmentRepo,
    this.feedRepo,
    this.itemBuilder,
    this.controllerCache,
    this.videoAnalyticsSink = const NoopVideoAnalyticsSink(),
    super.key,
  });

  /// Optional — if provided, the screen wraps its own `BlocProvider`
  /// instead of assuming one was supplied. Convenient when the feed is
  /// hosted inside an IndexedStack shell.
  final FeedRepository? feedRepo;

  final VideoRepository videoRepo;
  final EnrollmentRepository enrollmentRepo;

  /// Swap-in for widget tests — the default builder constructs a real
  /// `LearnVideoPlayer`, which needs the platform plugin to actually
  /// render. Tests pass a stub that returns a simple widget.
  final FeedItemBuilder? itemBuilder;

  /// Injectable so tests can observe cache behaviour directly.
  final VideoControllerCache? controllerCache;

  /// Telemetry sink for video_view / video_complete. Default Noop so
  /// existing widget tests don't need to supply a fake.
  final VideoAnalyticsSink videoAnalyticsSink;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final PageController _pageController;
  late final VideoControllerCache _cache;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cache = widget.controllerCache ?? VideoControllerCache();
    // Kick the initial load. If the bloc is already Loaded (tab switch
    // back to feed), this is a no-op because Bloc dedupes identical
    // emitted states.
    final bloc = context.read<FeedBloc>();
    if (bloc.state is FeedInitial) {
      bloc.add(const FeedLoadRequested());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Only dispose the cache if we created it — a caller-provided cache
    // is assumed to be externally owned.
    if (widget.controllerCache == null) {
      _cache.evictAll();
    }
    super.dispose();
  }

  void _onPageChanged(int index, FeedLoaded loaded) {
    if (loaded.hasMore &&
        !loaded.isLoadingMore &&
        index >= loaded.items.length - 2) {
      context.read<FeedBloc>().add(const FeedLoadMoreRequested());
    }
  }

  Widget _defaultItemBuilder(BuildContext context, FeedEntry entry) {
    return LearnVideoPlayer(
      key: ValueKey('feed.video.${entry.video.id}'),
      video: entry.video,
      courseId: entry.course.id,
      videoRepo: widget.videoRepo,
      enrollmentRepo: widget.enrollmentRepo,
      controllerCache: _cache,
      analyticsSink: widget.videoAnalyticsSink,
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemBuilder = widget.itemBuilder ?? _defaultItemBuilder;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Feed'),
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('feed.appbar.courses'),
            tooltip: 'Courses',
            icon: const Icon(Icons.school_outlined),
            onPressed: () => GoRouter.of(context).push('/courses'),
          ),
        ],
      ),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state is FeedInitial || state is FeedLoading) {
            return const ColoredBox(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is FeedError) {
            return Center(
              child: Column(
                key: const Key('feed.error'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.error.message),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<FeedBloc>().add(const FeedLoadRequested()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is FeedLoaded) {
            if (state.items.isEmpty) {
              return BrandEmptyState(
                key: const Key('feed.empty'),
                painter: EmptyFeedPainter(
                  scheme: Theme.of(context).colorScheme,
                ),
                title: 'Nothing in your feed yet',
                subtitle: "Enroll in a course to start watching.",
                action: ElevatedButton(
                  key: const Key('feed.empty.browse'),
                  onPressed: () => GoRouter.of(context).go('/courses'),
                  child: const Text('Browse courses'),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                final bloc = context.read<FeedBloc>();
                bloc.add(const FeedRefreshRequested());
                // Await one state emission so the indicator disappears when
                // the refresh actually completes.
                await bloc.stream.firstWhere(
                  (s) => s is FeedLoaded && !s.isLoadingMore || s is FeedError,
                );
              },
              child: Stack(
                children: [
                  PageView.builder(
                    key: const Key('feed.pageview'),
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: state.items.length,
                    onPageChanged: (i) => _onPageChanged(i, state),
                    itemBuilder: (context, i) =>
                        itemBuilder(context, state.items[i]),
                  ),
                  if (state.loadMoreError != null)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      right: 16,
                      child: Material(
                        color: Colors.redAccent.shade200,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.loadMoreError!.message,
                                  key: const Key('feed.loadMoreError'),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () => context.read<FeedBloc>().add(
                                  const FeedErrorClearRequested(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (state.isLoadingMore)
                    const Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
