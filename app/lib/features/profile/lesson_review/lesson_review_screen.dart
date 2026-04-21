import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/models/progress.dart';
import '../../../data/repositories/progress_repository.dart';
import 'cue_outcome_tile.dart';

/// Slice P2 — lesson review screen at
/// `/courses/:courseId/lessons/:videoId/review`.
///
/// Shows the learner's score on a single lesson, a per-cue breakdown,
/// and a "Retry lesson" entry point that deep-links back to the player
/// at t=0. The server-side invariant (no `correctAnswerSummary` for
/// unattempted cues) is mirrored in `CueOutcomeTile`.
class LessonReviewScreen extends StatefulWidget {
  const LessonReviewScreen({
    required this.videoId,
    required this.progressRepo,
    super.key,
  });

  final String videoId;
  final ProgressRepository progressRepo;

  @override
  State<LessonReviewScreen> createState() => _LessonReviewScreenState();
}

class _LessonReviewScreenState extends State<LessonReviewScreen> {
  LessonReview? _review;
  ApiException? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final review = await widget.progressRepo.fetchLesson(widget.videoId);
      if (!mounted) return;
      setState(() {
        _review = review;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final err = _error;
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson review')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(err.message),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final review = _review!;
    return Scaffold(
      appBar: AppBar(
        key: const Key('review.appBar'),
        title: Text(review.video.title),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(review: review)),
          SliverList.separated(
            itemCount: review.cues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) => CueOutcomeTile(
              outcome: review.cues[i],
              videoId: review.video.id,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.review});
  final LessonReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = review.score;
    final pct = s.accuracy != null
        ? '${(s.accuracy! * 100).round()}%'
        : null;
    final scoreLine = s.cuesAttempted == 0
        ? 'No attempts yet'
        : '${s.cuesCorrect}/${s.cuesAttempted} correct'
            '${s.grade != null ? ' · ${s.grade!.label} · $pct' : ''}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        key: const Key('review.header'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                review.course.title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lesson ${review.video.orderIndex + 1}',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                scoreLine,
                key: const Key('review.header.score'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    key: const Key('review.retry'),
                    onPressed: () => context.push(
                      '/videos/${review.video.id}/watch?t=0',
                    ),
                    icon: const Icon(Icons.replay),
                    label: const Text('Retry lesson'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
